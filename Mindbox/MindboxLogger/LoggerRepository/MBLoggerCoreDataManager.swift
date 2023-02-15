//
//  MBLoggerCoreDataManager.swift
//  MindboxLogger
//
//  Created by Akylbek Utekeshev on 06.02.2023.
//  Copyright © 2023 Mikhail Barilov. All rights reserved.
//

import Foundation
import CoreData

class MBLoggerCoreDataManager {
    public static let shared = MBLoggerCoreDataManager()
    
    private enum Constants {
        static let model = "CDLogMessage"
        static let dbSizeLimitKB: Int = 10000
        static let operationLimitBeforeNeedToDelete = 20
    }
    
    private var persistentStoreDescription: NSPersistentStoreDescription?
    private var writeCount = 0 {
        didSet {
            if writeCount > Constants.operationLimitBeforeNeedToDelete {
                writeCount = 0
            }
        }
    }

    lazy var persistentContainer: MBPersistentContainer = {
        let container = MBPersistentContainer(name: Constants.model)
        let storeURL = FileManager.storeURL(for: MBUtilitiesFetcher().applicationGroupIdentifier,
                                            databaseName: Constants.model)
        let storeDescription = NSPersistentStoreDescription(url: storeURL)
        storeDescription.setValue("DELETE" as NSObject, forPragmaNamed: "journal_mode") // Disabling WAL journal
        container.persistentStoreDescriptions = [storeDescription]
        container.loadPersistentStores {
            (storeDescription, error) in
        }

        return container
    }()
    
    private lazy var context: NSManagedObjectContext = {
        let context = persistentContainer.newBackgroundContext()
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyStoreTrumpMergePolicyType)
        return context
    }()
    
    // MARK: - CRUD Operations
    public func create(message: String, timestamp: Date) throws {
        try self.context.performAndWait {
            let entity = CDLogMessage(context: self.context)
            entity.message = message
            entity.timestamp = timestamp
            try self.saveEvent(withContext: self.context)
        }
        
        let isTimeToDelete = writeCount == 0
        writeCount += 1
        if isTimeToDelete && getDBFileSize() > Constants.dbSizeLimitKB {
            try delete()
        }
    }
    
    public func fetchPeriod(_ from: Date, _ to: Date) throws -> [CDLogMessage] {
        try context.performAndWait {
            let fetchRequest = NSFetchRequest<CDLogMessage>(entityName: Constants.model)
            fetchRequest.predicate = NSPredicate(format: "timestamp >= %@ AND timestamp <= %@",
                                                 from as NSDate,
                                                 to as NSDate)
            let logs = try context.fetch(fetchRequest)
            return logs
        }
    }
    
    public func delete() throws {
        try context.performAndWait {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: Constants.model)
            let count = try context.count(for: request)
            let limit: Double = (Double(count) * 0.1).rounded() // 10% percent of all records should be removed
            request.fetchLimit = Int(limit)
            request.includesPropertyValues = false
            let results = try context.fetch(request)

            for item in results {
                context.delete(item as! NSManagedObject)
            }
            
            Logger.common(message: "10%  logs has been deleted", level: .debug, category: .general)

            try saveEvent(withContext: context)
        }
    }
    
    public func deleteAll() throws {
        try context.performAndWait {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: Constants.model)
            request.includesPropertyValues = false
            let results = try context.fetch(request)
            for item in results {
                context.delete(item as! NSManagedObject)
            }
            try saveEvent(withContext: context)
        }
    }
}

private extension MBLoggerCoreDataManager {
    private func saveEvent(withContext context: NSManagedObjectContext) throws {
        guard context.hasChanges else { return }
        try saveContext(context)
    }
    
    private func saveContext(_ context: NSManagedObjectContext) throws {
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
    
    private func getDBFileSize() -> Int {
        guard let url = context.persistentStoreCoordinator?.persistentStores.first?.url else {
            return 0
        }
        let size = url.fileSize / 1024 // Bytes to Kilobytes
        return Int(size)
    }
}
