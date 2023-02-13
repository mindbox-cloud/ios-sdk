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
    
    let model = "CDLogMessage"
    var persistentStoreDescription: NSPersistentStoreDescription?

    lazy var persistentContainer: MBPersistentContainer = {
        let container = MBPersistentContainer(name: self.model)
        let storeURL = FileManager.storeURL(for: MBUtilitiesFetcher().applicationGroupIdentifier,
                                            databaseName: self.model)
        let storeDescription = NSPersistentStoreDescription(url: storeURL)
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
    
    public func create(message: String, timestamp: Date) throws {
        try context.performAndWait {
            let entity = CDLogMessage(context: context)
            entity.message = message
            entity.timestamp = timestamp
            try saveEvent(withContext: context)
        }
    }
    
    public func fetchPeriod(_ from: Date, _ to: Date) throws {
        try context.performAndWait {
            let fetchRequest = NSFetchRequest<CDLogMessage>(entityName: model)
            fetchRequest.predicate = NSPredicate(format: "timestamp >= %@ AND timestamp <= %@",
                                                 from as NSDate,
                                                 to as NSDate)
            let logs = try context.fetch(fetchRequest)
            for log in logs {
                print(log.message, "|", log.timestamp.toFullString())
            }
        }
    }
    
    public func fetchAll() throws {
        try context.performAndWait {
            let fetchRequest = NSFetchRequest<CDLogMessage>(entityName: model)
            let logs = try context.fetch(fetchRequest)
            for log in logs {
                print(log.message, "|", log.timestamp.toFullString())
            }
        }
    }
    
    public func delete() throws {
        try context.performAndWait {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: model)
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            try context.execute(batchDeleteRequest)
        }
    }
    
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
}

