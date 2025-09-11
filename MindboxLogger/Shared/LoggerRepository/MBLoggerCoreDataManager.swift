//
//  MBLoggerCoreDataManager.swift
//  MindboxLogger
//
//  Created by Akylbek Utekeshev on 06.02.2023.
//  Copyright © 2023 Mikhail Barilov. All rights reserved.
//

import Foundation
import CoreData
import SQLite3
import os
import UIKit.UIApplication

public class MBLoggerCoreDataManager {
    
    public static let shared = MBLoggerCoreDataManager()
    
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
        
        enum UserDefaultsKeys {
            static let previousDBSizeKey = "MBLoggerPersistenceStorage-previousDatabaseSize"
        }
        
        static let model = "CDLogMessage"
        static let dbSizeLimitKB: Int = 10_240
        static let batchSize = 15
        static let limitTheNumberOfOperationsBeforeCheckingIfDeletionIsRequired = 5
        
        static let lowWaterRatio: Double = 0.85
        static let minDeleteFraction: Double = 0.05
        static let maxDeleteFraction: Double = 0.50
        static let trimCooldownSec: TimeInterval = 10
    }
    
    private var logBuffer: [LogMessage]
    private let queue: DispatchQueue
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var writesImmediately = false
    private var trimCooldownUntil: Date?
    
    private var writeCount = 0 {
        didSet {
            if writeCount >= Constants.limitTheNumberOfOperationsBeforeCheckingIfDeletionIsRequired && !writesImmediately {
                writeCount = 0
                trimIfNeeded()
            }
        }
    }
    
    // MARK: CoreData objects
    
    private var persistentContainer: MBPersistentContainer
    private var context: NSManagedObjectContext?
    
    // MARK: Initializer
    
    private init() {
        self.logBuffer = []
        self.queue = DispatchQueue(label: "com.Mindbox.loggerManager", qos: .utility)
        self.storageState = .initializing
        
        MBPersistentContainer.applicationGroupIdentifier = MBLoggerUtilitiesFetcher().applicationGroupIdentifier
        self.persistentContainer = Self.buildContainer()
        queue.async { [weak self] in
            self?.bootstrapPersistentStore()
        }
    }
    
    private static func buildContainer() -> MBPersistentContainer {
        #if SWIFT_PACKAGE
        if let url = Bundle.module.url(forResource: Constants.model, withExtension: "momd"),
           let mom = NSManagedObjectModel(contentsOf: url) {
            return MBPersistentContainer(name: Constants.model, managedObjectModel: mom)
        } else {
            return MBPersistentContainer(name: Constants.model)
        }
        #else
        let podBundle = Bundle(for: MBLoggerCoreDataManager.self)
        if let url = podBundle.url(forResource: "MindboxLogger", withExtension: "bundle"),
           let bundle = Bundle(url: url),
           let modelURL = bundle.url(forResource: Constants.model, withExtension: "momd"),
           let mom = NSManagedObjectModel(contentsOf: modelURL) {
            return MBPersistentContainer(name: Constants.model, managedObjectModel: mom)
        } else {
            return MBPersistentContainer(name: Constants.model)
        }
        #endif
    }
    
    private func bootstrapPersistentStore() {
        log(.info, "[MBLoggerCDManager] bootstrap start (main=\(Thread.isMainThread), thread:\(Thread.current)")
        
        guard persistentContainer.managedObjectModel.entitiesByName[Constants.model] != nil else {
            storageState = .disabled
            log(.error, "[MBLoggerCDManager] model missing entity CDLogMessage → disabling storage")
            return
        }
        
        let storeURL = FileManager.storeURL(for: MBLoggerUtilitiesFetcher().applicationGroupIdentifier,
                                       databaseName: Constants.model)
        let isStoreReady = preparePersistentStore(at: storeURL)

        if isStoreReady {
            let ctx = persistentContainer.newBackgroundContext()
            ctx.automaticallyMergesChangesFromParent = true
            ctx.mergePolicy = NSMergePolicy(merge: .mergeByPropertyStoreTrumpMergePolicyType)
            context = ctx
            logBuffer.reserveCapacity(Constants.batchSize)
            storageState = .enabled
            log(.info, "[MBLoggerCDManager] bootstrap done → enabled")
            setupNotificationCenterObservers()
            checkDatabaseSizeAndDeleteIfNeededThroughInit()
        } else {
            context = nil
            storageState = .disabled
            log(.error, "[MBLoggerCDManager] bootstrap failed → disabled")
        }
    }
    
    private func preparePersistentStore(at url: URL) -> Bool {
        ensureParentDirectoryExists(for: url)
        return setupPersistentStore(at: url) || recreatePersistentStore(at: url)
    }
    
    private func setupPersistentStore(at url: URL) -> Bool {
        let desc = storeDescription(for: url)
        persistentContainer.persistentStoreDescriptions = [desc]

        var err: Error?
        log(.info, "[MBLoggerCDManager] setup store at \(url.lastPathComponent)")
        persistentContainer.loadPersistentStores { _, e in err = e }
        
        if let err {
            log(.error, "[MBLoggerCDManager] setup failed: \(err.localizedDescription) [url: \(url.lastPathComponent)]")
        } else {
            log(.info, "[MBLoggerCDManager] setup ok [url: \(url.lastPathComponent)]")
        }
        
        return err == nil && hasPersistentStore
    }
    
    private func recreatePersistentStore(at url: URL) -> Bool {
        let psc = persistentContainer.persistentStoreCoordinator
        log(.error, "[MBLoggerCDManager] recreate: will destroy store at \(url.path)")
        if let store = psc.persistentStores.first(where: { $0.url == url }) {
            try? psc.remove(store)
        }
        
        do {
            if #available(iOS 15.0, *) {
                try psc.destroyPersistentStore(at: url, type: .sqlite)
            } else {
                try psc.destroyPersistentStore(at: url, ofType: NSSQLiteStoreType)
            }
        } catch {
            log(.error, "[MBLoggerCDManager] destroy failed: \(error.localizedDescription)")
        }

        ensureParentDirectoryExists(for: url)

        let desc = storeDescription(for: url)
        persistentContainer.persistentStoreDescriptions = [desc]

        var err: Error?
        persistentContainer.loadPersistentStores { _, e in err = e }
        
        if let err {
            log(.error, "[MBLoggerCDManager] recreate failed: \(err.localizedDescription) [url: \(url.lastPathComponent)]")
        } else {
            log(.info, "[MBLoggerCDManager] recreate ok [url: \(url.lastPathComponent)]")
        }
        
        return err == nil && hasPersistentStore
    }
    
    private func storeDescription(for url: URL) -> NSPersistentStoreDescription {
        let d = NSPersistentStoreDescription(url: url)
        d.setOption(FileProtectionType.none as NSObject, forKey: NSPersistentStoreFileProtectionKey)
        d.shouldAddStoreAsynchronously = false
        return d
    }

    private func ensureParentDirectoryExists(for url: URL) {
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }
    
    private var hasPersistentStore: Bool {
        !persistentContainer.persistentStoreCoordinator.persistentStores.isEmpty
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
                if self.logBuffer.count >= Constants.batchSize {
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
            guard count > 0 else { return }

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
            withName: "MB-BackgroundTask-writeLogsToCoreData-whenApplicationDidEnterBackground"
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
        guard isStoreLoaded else { return }

        if let t = self.trimCooldownUntil, t > Date() { return }

        let sizeKB = precomputedSizeKB ?? measureLogicalDBSizeKB()
        guard let fraction = computeTrimFraction(
            sizeKB: sizeKB, limitKB: Constants.dbSizeLimitKB
        ) else { return }

        do {
            try deleteOldestLogs(fraction: fraction)
        } catch {
            log(.error, "[MBLoggerCDManager] trim failed: \(error.localizedDescription)")
            return
        }

        self.trimCooldownUntil = Date().addingTimeInterval(Constants.trimCooldownSec)
    }
    
    func computeTrimFraction(sizeKB: Int, limitKB: Int) -> Double? {
        guard sizeKB > limitKB else { return nil }
        let targetKB = Int(Double(limitKB) * Constants.lowWaterRatio)
        let raw = Double(sizeKB - targetKB) / Double(max(sizeKB, 1))
        let fraction = min(Constants.maxDeleteFraction, max(Constants.minDeleteFraction, raw))
        return fraction
    }
    
    func measureLogicalDBSizeKB() -> Int {
        guard let url = context?.persistentStoreCoordinator?.persistentStores.first?.url else { return 0 }
        
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_close(db) }

        func pragmaInt(_ name: String) -> Int64 {
            var stmt: OpaquePointer?
            defer { if stmt != nil { sqlite3_finalize(stmt) } }
            guard sqlite3_prepare_v2(db, "PRAGMA \(name);", -1, &stmt, nil) == SQLITE_OK,
                  sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
            return sqlite3_column_int64(stmt, 0)
        }

        let pageSize  = pragmaInt("page_size")
        let pageCount = pragmaInt("page_count")
        let freeList  = pragmaInt("freelist_count")
        let usedBytes = max(0, (pageCount - freeList)) * pageSize
        return Int(usedBytes / 1024)
    }
}

// swiftlint:disable file_length

// MARK: - Debug and tests

#if DEBUG
extension MBLoggerCoreDataManager {
    
    // MARK: Properties
    
    var debugBatchSize: Int { Constants.batchSize }
    
    var debugLimitTheNumberOfOperationsBeforeCheckingIfDeletionIsRequired: Int {
        Constants.limitTheNumberOfOperationsBeforeCheckingIfDeletionIsRequired
    }
    
    var debugWritesImmediately: Bool { self.writesImmediately }
    
    var debugWriteCount: Int { self.writeCount }
    
    var debugSerialQueue: DispatchQueue { self.queue }
    
    var debugHasPersistentStore: Bool { self.hasPersistentStore }

    var debugIsStoreLoaded: Bool { isStoreLoaded }

    var debugLogBufferCount: Int { logBuffer.count }

    var debugLogBufferCapacity: Int { logBuffer.capacity }

    var debugPersistentContainer: MBPersistentContainer {
        get { self.persistentContainer }
        set { self.persistentContainer = newValue }
    }
    
    var debugContext: NSManagedObjectContext? {
        get { self.context }
        set { self.context = newValue }
    }
    
    // MARK: Initializors
    
    convenience init(debug: Bool) {
        self.init()
    }
    
    // MARK: Methods
    
    func debugWriteBufferToCD() {
        queue.async {
            self.writeBufferToCoreData()
        }
    }
    
    func debugFlushBufferInBackground() {
        queue.async {
            self.flushBufferInBackground()
        }
    }
    
    func debugRebootstrap() {
        storageState = .initializing
        context = nil

        debugSerialQueue.async { [weak self] in
            self?.bootstrapPersistentStore()
        }
    }
    
    func debugResetWriteCount() { queue.async { self.writeCount = 0 } }
    
    func debugTrimIfNeeded(precomputedSizeKB: Int?) {
        self.trimIfNeeded(precomputedSizeKB: precomputedSizeKB)
    }
    
    func debugResetCooldown() {
        queue.async { [weak self] in self?.trimCooldownUntil = nil }
    }
}
#endif
