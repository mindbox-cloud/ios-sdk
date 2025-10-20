//
//  MBLoggerCoreDataManager.swift
//  MindboxLogger
//
//  Created by Akylbek Utekeshev on 06.02.2023.
//  Copyright © 2023 Mikhail Barilov. All rights reserved.
//

import Foundation
import CoreData
import os
import UIKit.UIApplication

public class MBLoggerCoreDataManager {
    
    public static let shared = MBLoggerCoreDataManager(
        config: .default,
        loader: LoggerDatabaseLoader(LoggerDatabaseLoaderConfig(
            modelName: Constants.model,
            applicationGroupId: MBLoggerUtilitiesFetcher().applicationGroupIdentifier,
            storeURL: nil,
            descriptions: nil
        ))
    )
    
    enum StorageState {
        case initializing
        case enabled
        case disabled
    }
    private(set) var storageState: StorageState
    
    private let osLog = OSLogWriter(
        subsystem: Bundle.main.bundleIdentifier ?? "cloud.Mindbox.UndefinedHostApplication",
        category: LogCategory.loggerDatabase.rawValue
    )
    
    private func log(_ level: LogLevel, _ msg: @autoclosure () -> String) {
        guard level >= .error else {
            return
        }
        osLog.writeMessage(msg(), logLevel: level)
    }
    
    private enum Constants {
        static let model = "CDLogMessage"
        static let backgroundTaskName = "MB-BackgroundTask-writeLogsToCoreData-whenApplicationDidEnterBackground"
        static let loggerQueueLabel = "com.Mindbox.loggerManager"
    }
    
    private let loader: LoggerDatabaseLoading
    private var config: LoggerDBConfig
    private var trimmer: LogStoreTrimming?
    
    private var logBuffer: [LogMessage]
    private let queue: DispatchQueue
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var writesImmediately = false
    
    private var writeCount = 0 {
        didSet {
            if writeCount >= self.config.writesPerTrimCheck && !writesImmediately {
                writeCount = 0
                queue.async { [weak self] in
                    self?.trimIfNeeded()
                }
            }
        }
    }
    
    // MARK: CoreData objects
    
    private var persistentContainer: MBPersistentContainer?
    private var context: NSManagedObjectContext?
    
    // MARK: Initializer
    
    private init(config: LoggerDBConfig, loader: LoggerDatabaseLoading) {
        self.config = config
        self.loader = loader
        
        self.logBuffer = []
        self.queue = DispatchQueue(label: Constants.loggerQueueLabel, qos: .utility)
        self.storageState = .initializing
        
        queue.async { [weak self] in self?.bootstrap() }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func bootstrap() {
        do {
            let loaded = try loader.loadContainer()
            self.persistentContainer = loaded.container
            self.context = loaded.context
            
            self.trimmer = LogStoreTrimmer(
                config: config,
                sizeMeasurer: SQLiteLogicalSizeMeasurer { [weak self] in
                    self?.context?.persistentStoreCoordinator?.persistentStores.first?.url
                }
            )

            self.logBuffer.reserveCapacity(config.batchSize)
            self.storageState = .enabled

            self.setupNotificationCenterObservers()
            self.checkDatabaseSizeAndDeleteIfNeededThroughInit()
        } catch {
            self.context = nil
            self.persistentContainer = nil
            self.storageState = .disabled
            log(.error, "[MBLoggerCDManager] bootstrap failed: \(error.localizedDescription)")
        }
    }
    
    private var hasPersistentStore: Bool {
        guard let psc = persistentContainer?.persistentStoreCoordinator else { return false }
        return !psc.persistentStores.isEmpty
    }
    
    private var isStoreLoaded: Bool {
        storageState == .enabled && hasPersistentStore && context != nil
    }
}

// MARK: - CRUD Operations

public extension MBLoggerCoreDataManager {
    
    // MARK: Create
    
    func create(message: String, timestamp: Date, completion: (() -> Void)? = nil) {
        queue.async { [weak self] in
            guard let self else { return }
            guard self.isStoreLoaded else { completion?(); return }
            
            let newLogMessage = LogMessage(timestamp: timestamp, message: message)
            
            if self.writesImmediately {
                self.persist([newLogMessage])
            } else {
                self.logBuffer.append(newLogMessage)
                if self.logBuffer.count >= self.config.batchSize {
                    self.writeBufferToCoreData()
                }
            }
            
            completion?()
        }
    }
    
    private func writeBufferToCoreData() {
        persist(logBuffer)
        logBuffer.removeAll(keepingCapacity: true)
    }
    
    private func persist(_ logs: [LogMessage]) {
        guard storageState == .enabled, hasPersistentStore, let context else { return }
        guard !logs.isEmpty else { return }
        
        context.executePerformAndWait {
            if #available(iOS 13.0, *) {
                let insertDataObjects = logs.map { ["message": $0.message, "timestamp": $0.timestamp] }
                let batchInsertRequest = NSBatchInsertRequest(entityName: Constants.model, objects: insertDataObjects)
                
                do {
                    try context.execute(batchInsertRequest)
                } catch {
                    log(.error, "[MBLoggerCDManager] batch insert failed: \(error.localizedDescription)")
                }
            } else {
                // iOS 12 fallback
                for log in logs {
                    let entity = CDLogMessage(context: context)
                    entity.message   = log.message
                    entity.timestamp = log.timestamp
                }
                do {
                    try saveContext(context)
                } catch {
                    log(.error, "[MBLoggerCDManager] save failed (iOS12 path): \(error.localizedDescription)")
                }
            }
            
            writeCount += 1
        }
    }
    
    // MARK: Read
    
    func getFirstLog() throws -> LogMessage? {
        try fetchSingleLog(ascending: true)
    }
    
    func getLastLog() throws -> LogMessage? {
        try fetchSingleLog(ascending: false)
    }
    
    private func fetchSingleLog(ascending: Bool) throws -> LogMessage? {
        guard storageState == .enabled, hasPersistentStore, let context else { return nil }
        
        var fetchedLogMessage: LogMessage?
        try context.executePerformAndWait {
            let fetchRequest = NSFetchRequest<CDLogMessage>(entityName: Constants.model)
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: ascending)]
            fetchRequest.fetchLimit = 1
            if let result = try context.fetch(fetchRequest).first {
                fetchedLogMessage = LogMessage(timestamp: result.timestamp, message: result.message)
            }
        }
        return fetchedLogMessage
    }
    
    func fetchPeriod(_ from: Date, _ to: Date, ascending: Bool = true) throws -> [LogMessage] {
        guard storageState == .enabled, hasPersistentStore, let context else { return [] }
        
        var fetchedLogs: [LogMessage] = []
        
        try context.executePerformAndWait {
            let fetchRequest = NSFetchRequest<NSDictionary>(entityName: Constants.model)
            fetchRequest.resultType = .dictionaryResultType
            fetchRequest.propertiesToFetch = ["timestamp", "message", "objectID"]
            fetchRequest.predicate = NSPredicate(format: "timestamp >= %@ AND timestamp <= %@",
                                                 from as NSDate, to as NSDate)
            fetchRequest.fetchBatchSize = 50 // Setting batchSize for optimal memory consumption
            
            let sortDescriptor = NSSortDescriptor(key: "timestamp", ascending: ascending)
            fetchRequest.sortDescriptors = [sortDescriptor]
            
            let results = try context.fetch(fetchRequest)
            fetchedLogs = results.compactMap { dict -> LogMessage? in
                guard let timestamp = dict["timestamp"] as? Date,
                      let message = dict["message"] as? String else { return nil }
                return LogMessage(timestamp: timestamp, message: message)
            }
        }
        
        return fetchedLogs
    }
    
    // MARK: Delete
    
    func deleteOldestLogs(fraction: Double) throws {
        guard storageState == .enabled, hasPersistentStore, let context else { return }

        try context.executePerformAndWait {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: Constants.model)
            let count = try context.count(for: fetchRequest)
            guard count > .zero else { return }

            let toDelete = min(count, max(1, Int((Double(count) * fraction).rounded(.toNearestOrAwayFromZero))))

            let idsReq = NSFetchRequest<NSFetchRequestResult>(entityName: Constants.model)
            idsReq.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
            idsReq.fetchLimit = toDelete
            idsReq.resultType = .managedObjectIDResultType

            let del = NSBatchDeleteRequest(fetchRequest: idsReq)
            del.resultType = .resultTypeObjectIDs

            if let res = try context.execute(del) as? NSBatchDeleteResult,
               let ids = res.result as? [NSManagedObjectID] {
                NSManagedObjectContext.mergeChanges(
                    fromRemoteContextSave: [NSDeletedObjectsKey: ids],
                    into: [context]
                )
            }
            
            Logger.common(message: "[MBLoggerCDManager] Out of \(count) logs, \(toDelete) were deleted", level: .info, category: .loggerDatabase)
        }
    }
}

// MARK: - Public methods

public extension MBLoggerCoreDataManager {
    
    func setImmediateWrite(_ enabled: Bool = true) {
        queue.async {
            self.writesImmediately = enabled
        }
    }
}

// MARK: - Only for debug

public extension MBLoggerCoreDataManager {
    func deleteAll() throws {
        guard storageState == .enabled, hasPersistentStore, let context else { return }
        
        self.logBuffer.removeAll(keepingCapacity: true)
        try context.executePerformAndWait {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: Constants.model)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            deleteRequest.resultType = .resultTypeObjectIDs
            
            let batchDeleteResult = try context.execute(deleteRequest) as? NSBatchDeleteResult
            
            if let objectIDs = batchDeleteResult?.result as? [NSManagedObjectID] {
                let changes: [AnyHashable: Any] = [NSDeletedObjectsKey: objectIDs]
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
            }
        }
    }
}

// MARK: - NotificationCenter observers setup

private extension MBLoggerCoreDataManager {
    func setupNotificationCenterObservers() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationWillEnterForeground),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationDidEnterBackground),
                                               name: UIApplication.didEnterBackgroundNotification,
                                               object: nil)
    }
    
    @objc
    func applicationWillEnterForeground() {
        queue.async { self.writesImmediately = false }
    }
    
    @objc
    func applicationDidEnterBackground() {
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(
            withName: Constants.backgroundTaskName
        ) { [weak self] in
            guard let self else { return }
            UIApplication.shared.endBackgroundTask(self.backgroundTaskID)
            self.backgroundTaskID = .invalid
        }
        
        guard backgroundTaskID != .invalid else {
            queue.async { self.writesImmediately = true }
            return
        }
        
        queue.async { [weak self] in
            guard let self else {
                UIApplication.shared.endBackgroundTask(self?.backgroundTaskID ?? .invalid)
                return
            }
            
            self.flushBufferInBackground()
            
            UIApplication.shared.endBackgroundTask(self.backgroundTaskID)
            self.backgroundTaskID = .invalid
        }
    }
    
    func flushBufferInBackground() {
        writesImmediately = true
        writeBufferToCoreData()
    }
}

// MARK: - Auxiliary private functions for iOS 12 batch saving

private extension MBLoggerCoreDataManager {
    func saveContext(_ context: NSManagedObjectContext) throws {
        guard context.hasChanges else { return }
        
        do {
            try context.save()
        } catch {
            switch error {
            case let error as NSError where error.domain == NSSQLiteErrorDomain && error.code == 13:
                fallthrough
            default:
                context.rollback()
            }
            throw error
        }
    }
}

// MARK: - Auxiliary private functions for checking the size of the database

private extension MBLoggerCoreDataManager {
    
    func checkDatabaseSizeAndDeleteIfNeededThroughInit() {
        queue.asyncAfter(deadline: .now() + .seconds(5)) { [weak self] in
            self?.trimIfNeeded()
        }
    }
    
    func trimIfNeeded(precomputedSizeKB: Int? = nil) {
        guard isStoreLoaded, let trimmer else { return }
        do {
            try trimmer.maybeTrim(precomputedSizeKB: precomputedSizeKB) { [weak self] fraction in
                guard let self else { return }
                try self.deleteOldestLogs(fraction: fraction)
            }
        } catch {
            log(.error, "[MBLoggerCDManager] trim failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Debug and tests

#if DEBUG
extension MBLoggerCoreDataManager {
    
    convenience init(debug: Bool, config: LoggerDBConfig, loader: LoggerDatabaseLoading) {
        self.init(config: config, loader: loader)
    }
    
    // MARK: Introspection
    
    var debugBatchSize: Int { config.batchSize }
    var debugLimitTheNumberOfOperationsBeforeCheckingIfDeletionIsRequired: Int { config.writesPerTrimCheck }

    var debugWritesImmediately: Bool { writesImmediately }
    var debugWriteCount: Int { writeCount }

    var debugSerialQueue: DispatchQueue { queue }
    var debugHasPersistentStore: Bool { hasPersistentStore }
    var debugIsStoreLoaded: Bool { isStoreLoaded }

    var debugLogBufferCount: Int { logBuffer.count }
    var debugLogBufferCapacity: Int { logBuffer.capacity }

    var debugContext: NSManagedObjectContext? {
        get { context }
        set { context = newValue }
    }

    var debugStorageState: StorageState {
        get { storageState }
        set { storageState = newValue }
    }

    // MARK: Actions
    
    func debugWriteBufferToCD() {
        queue.async { self.writeBufferToCoreData() }
    }

    func debugFlushBufferInBackground() {
        queue.async { self.flushBufferInBackground() }
    }

    func debugTrimIfNeeded(precomputedSizeKB: Int?) {
        self.trimIfNeeded(precomputedSizeKB: precomputedSizeKB)
    }

    func debugResetCooldown() {
        queue.async { [weak self] in self?.trimmer?.resetCooldown() }
    }

    func debugResetWriteCount() {
        queue.async { [weak self] in self?.writeCount = 0 }
    }

    func debugComputeTrimFraction(sizeKB: Int, limitKB: Int) -> Double? {
        trimmer?.computeTrimFraction(sizeKB: sizeKB, limitKB: limitKB)
    }
}
#endif
