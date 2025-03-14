//
//  MBLoggerCoreDataManager.swift
//  MindboxLogger
//
//  Created by Akylbek Utekeshev on 06.02.2023.
//  Copyright © 2023 Mikhail Barilov. All rights reserved.
//

import Foundation
import CoreData
import UIKit.UIApplication

public class MBLoggerCoreDataManager {
    public static let shared = MBLoggerCoreDataManager()

    private enum Constants {
        static let model = "CDLogMessage"
        static let dbSizeLimitKB: Int = 10_000
        static let batchSize = 15
        static let operationBatchLimitBeforeNeedToDelete = 5
    }

    private var logBuffer: [LogMessage]
    private let isAppExtension: Bool
    private let queue: DispatchQueue
    private var previousDBSize: Int?

    private var writeCount = 0 {
        didSet {
            if writeCount > Constants.operationBatchLimitBeforeNeedToDelete && !isAppExtension {
                writeCount = 0
                checkDatabaseSizeAndDeleteIfNeeded()
            }
        }
    }

    private lazy var bufferPersistenceStrategy: () -> Void = {
        if isAppExtension {
            return { [weak self] in
                self?.writeBufferToCoreData()
            }
        } else {
            return { [weak self] in
                guard let self = self else { return }
                if self.logBuffer.count >= Constants.batchSize {
                    self.writeBufferToCoreData()
                }
            }
        }
    }()

    // MARK: CoreData objects

    private lazy var persistentContainer: MBPersistentContainer = {
        MBPersistentContainer.applicationGroupIdentifier = MBLoggerUtilitiesFetcher().applicationGroupIdentifier

        #if SWIFT_PACKAGE
        guard let bundleURL = Bundle.module.url(forResource: Constants.model, withExtension: "momd"),
              let mom = NSManagedObjectModel(contentsOf: bundleURL) else {
            fatalError("Failed to initialize NSManagedObjectModel for \(Constants.model)")
        }
        let container = MBPersistentContainer(name: Constants.model, managedObjectModel: mom)
        #else
        let podBundle = Bundle(for: MBLoggerCoreDataManager.self)
        let container: MBPersistentContainer
        if let url = podBundle.url(forResource: "MindboxLogger", withExtension: "bundle"),
           let bundle = Bundle(url: url),
           let modelURL = bundle.url(forResource: Constants.model, withExtension: "momd"),
           let mom = NSManagedObjectModel(contentsOf: modelURL) {
            container = MBPersistentContainer(name: Constants.model, managedObjectModel: mom)
        } else {
            container = MBPersistentContainer(name: Constants.model)
        }
        #endif

        let storeURL = FileManager.storeURL(for: MBLoggerUtilitiesFetcher().applicationGroupIdentifier, databaseName: Constants.model)

        let storeDescription = NSPersistentStoreDescription(url: storeURL)
        storeDescription.setOption(FileProtectionType.none as NSObject, forKey: NSPersistentStoreFileProtectionKey)
        storeDescription.setValue(250 as NSObject, forPragmaNamed: "wal_autocheckpoint") // Write WAL to main sqlite file every 1MB - 250 * pageSize 4KB = 1000 KB 
        container.persistentStoreDescriptions = [storeDescription]
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load persistent stores: \(error)")
            }
        }

        return container
    }()

    private lazy var context: NSManagedObjectContext = {
        let context = persistentContainer.newBackgroundContext()
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyStoreTrumpMergePolicyType)
        return context
    }()

    // MARK: Initializer

    private init(isAppExtension: Bool = Bundle.main.bundlePath.hasSuffix(".appex")) {
        self.isAppExtension = isAppExtension
        self.logBuffer = []
        self.logBuffer.reserveCapacity(Constants.batchSize)
        self.queue = DispatchQueue(label: "com.Mindbox.loggerManager", qos: .utility)
        setupNotificationCenterObservers()
        setupPreviousDatabaseSize()
    }
}

// MARK: - CRUD Operations

public extension MBLoggerCoreDataManager {

    // MARK: Create

    func create(message: String, timestamp: Date, completion: (() -> Void)? = nil) {
        queue.async {
            let newLogMessage = LogMessage(timestamp: timestamp, message: message)
            self.logBuffer.append(newLogMessage)

            self.bufferPersistenceStrategy()

            completion?()
        }
    }

    private func writeBufferToCoreData() {
        guard !logBuffer.isEmpty else { return }
        
        context.executePerformAndWait {
            if #available(iOS 13.0, *) {
                performBatchInsert()
            } else {
                performContextInsertion()
            }
        }
    }

    @available(iOS 13.0, *)
    private func performBatchInsert() {
        let insertData = logBuffer.map { ["message": $0.message, "timestamp": $0.timestamp] }
        let insertRequest = NSBatchInsertRequest(entityName: Constants.model, objects: insertData)

        do {
            try context.execute(insertRequest)
            logBuffer.removeAll()
            writeCount += 1
        } catch {
            let errorMessage = "Failed to batch insert logs: \(error.localizedDescription)"
            let errorLogData = [["message": errorMessage, "timestamp": Date()]]
            let errorLogInsertRequest = NSBatchInsertRequest(entityName: Constants.model, objects: errorLogData)

            do {
                try context.execute(errorLogInsertRequest)
            } catch { }
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

    func deleteTenPercentOfAllOldRecords() throws {
        try context.executePerformAndWait {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: Constants.model)

            let count = try context.count(for: fetchRequest)
            let limit = Int((Double(count) * 0.1).rounded()) // 10% percent of all records should be removed

            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
            fetchRequest.fetchLimit = limit

            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            deleteRequest.resultType = .resultTypeObjectIDs

            let batchDeleteResult = try context.execute(deleteRequest) as? NSBatchDeleteResult
            if let objectIDs = batchDeleteResult?.result as? [NSManagedObjectID] {
                let changes = [NSDeletedObjectsKey: objectIDs]
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
            }

            Logger.common(message: "Out of \(count) logs, \(limit) were deleted", level: .debug, category: .general)
        }
    }
}

// MARK: - Only for debug

public extension MBLoggerCoreDataManager {
    func deleteAll() throws {
        self.logBuffer.removeAll()
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
                                               selector: #selector(applicationDidEnterBackground),
                                               name: UIApplication.didEnterBackgroundNotification,
                                               object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationWillTerminate),
                                               name: UIApplication.willTerminateNotification,
                                               object: nil)
    }

    @objc
    func applicationDidEnterBackground() {
        queue.async { [weak self] in
            self?.writeBufferToCoreData()
        }
    }

    @objc
    func applicationWillTerminate() {
        queue.async { [weak self] in
            self?.writeBufferToCoreData()
        }
    }
}

// MARK: - Auxiliary private functions for iOS 12 batch saving

private extension MBLoggerCoreDataManager {
    func performContextInsertion() {
        do {
            for log in self.logBuffer {
                let entity = CDLogMessage(context: self.context)
                entity.message = log.message
                entity.timestamp = log.timestamp
            }
            
            try self.saveEvent(withContext: self.context)
            logBuffer.removeAll()
            writeCount += 1
        } catch {
            let errorMessage = "Failed to save context with batch logs: \(error.localizedDescription)"
            let errorLogEntity = CDLogMessage(context: self.context)
            errorLogEntity.message = errorMessage
            errorLogEntity.timestamp = Date()

            do {
                try self.saveEvent(withContext: self.context)
            } catch { }
        }
    }

    func saveEvent(withContext context: NSManagedObjectContext) throws {
        guard context.hasChanges else { return }
        try saveContext(context)
    }

    func saveContext(_ context: NSManagedObjectContext) throws {
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
    func setupPreviousDatabaseSize() {
        queue.async {
            self.previousDBSize = self.getDBFileSize() 
        }
    }
    
    func checkDatabaseSizeAndDeleteIfNeeded() {
        let currentDBFileSize = getDBFileSize()
        
        if currentDBFileSize > Constants.dbSizeLimitKB && previousDBSize != currentDBFileSize {
            do {
                try deleteTenPercentOfAllOldRecords()
            } catch { }
        }
        
        previousDBSize = currentDBFileSize
    }

    func getDBFileSize() -> Int {
        guard let url = context.persistentStoreCoordinator?.persistentStores.first?.url else {
            return 0
        }
        let size = url.fileSize / 1024 // Bytes to Kilobytes
        return Int(size)
    }
}

#if DEBUG
extension MBLoggerCoreDataManager {
    var debugBatchSize: Int {
        return Constants.batchSize
    }

    func debugWriteBufferToCD() {
        queue.async {
            self.writeBufferToCoreData()
        }
    }

    convenience init(debugIsAppExtension: Bool) {
        self.init(isAppExtension: debugIsAppExtension)
    }
}
#endif
