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
        
        /// batch size | operationBatchLimitBeforeNeedToDelete
        ///       1  |  20
        ///       2  |  14
        ///       3  |  11
        ///       4  |  10
        ///     5-6   |  8
        ///     7 -8  |  7
        ///     9-11 |  6
        ///    12-16 |  5
        ///    17-25 |  4
        ///    26-44 |  3
        ///   45-100 |  2
        ///    101+  |  1
        ///
        static var operationBatchLimitBeforeNeedToDelete: Int = {
            return max(1, Int(20 / pow(Double(batchSize), 0.5)))
        }()
    }
    
    private var logBuffer: [LogMessage] = []
    private let queue = DispatchQueue(label: "com.Mindbox.loggerManager", qos: .utility)
    private var writeCount = 0 {
        didSet {
            if writeCount > Constants.operationBatchLimitBeforeNeedToDelete {
                writeCount = 0
                checkDatabaseSizeAndDeleteIfNeeded()
            }
        }
    }
    
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
        storeDescription.setValue("DELETE" as NSObject, forPragmaNamed: "journal_mode") // Disabling WAL journal
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
    
    // MARK: Initializers and deinitializer
    
    private init() {
        setupNotificationCenterObservers()
    }
    
    deinit {
        removeAllNotificationCenterObservers()
    }

    // MARK: - CRUD Operations
    
    public func create(message: String, timestamp: Date, completion: (() -> Void)? = nil) {
        queue.async {
            let newLogMessage = LogMessage(timestamp: timestamp, message: message)
            self.logBuffer.append(newLogMessage)
            
            if self.logBuffer.count >= Constants.batchSize {
                self.flushBuffer()
            }
            
            completion?()
        }
    }
    
    private func flushBuffer() {
        guard !logBuffer.isEmpty else { return }
        
        if #available(iOS 13.0, *) {
            performBatchInsert()
        } else {
            performContextInsertion()
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
    
    public func getFirstLog() throws -> LogMessage? {
        return try fetchSingleLog(ascending: true)
    }

    public func getLastLog() throws -> LogMessage? {
        return try fetchSingleLog(ascending: false)
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
    
    public func fetchPeriod(_ from: Date, _ to: Date) throws -> [LogMessage] {
        var fetchedLogs: [LogMessage] = []
        
        try context.executePerformAndWait {
            let fetchRequest = NSFetchRequest<CDLogMessage>(entityName: Constants.model)
            fetchRequest.predicate = NSPredicate(format: "timestamp >= %@ AND timestamp <= %@",
                                                 from as NSDate, to as NSDate)
            
            fetchRequest.fetchBatchSize = 50 // Setting batchSize for optimal memory consumption
            
            let logs = try context.fetch(fetchRequest)
            fetchedLogs = logs.map { LogMessage(timestamp: $0.timestamp, message: $0.message) }
        }
        
        return fetchedLogs
    }
    
    public func deleteTenPercentOfAllOldRecords() throws {
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
            
            Logger.common(message: "\(limit) logs have been deleted", level: .debug, category: .general)
        }
    }
}

// MARK: - CRUD Operations

public extension MBLoggerCoreDataManager {

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
    
    func removeAllNotificationCenterObservers() {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc
    func applicationDidEnterBackground() {
        queue.async { [weak self] in
            self?.flushBuffer()
        }
    }
    
    @objc
    func applicationWillTerminate() {
        queue.async { [weak self] in
            self?.flushBuffer()
        }
    }
}

// MARK: - Auxiliary private functions for iOS 12 batch saving

private extension MBLoggerCoreDataManager {
    func performContextInsertion() {
        do {
            try context.executePerformAndWait {
                for log in self.logBuffer {
                    let entity = CDLogMessage(context: self.context)
                    entity.message = log.message
                    entity.timestamp = log.timestamp
                }
                
                try self.saveEvent(withContext: self.context)
                logBuffer.removeAll()
                writeCount += 1
            }
        } catch {
            let errorMessage = "Failed to batch insert logs: \(error.localizedDescription)"
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
    func checkDatabaseSizeAndDeleteIfNeeded() {
        if getDBFileSize() > Constants.dbSizeLimitKB {
            do {
                try deleteTenPercentOfAllOldRecords()
            } catch { }
        }
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
#endif
