//
//  MBDatabaseRepository.swift
//  MindBox
//
//  Created by Maksim Kazachkov on 04.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import CoreData

class MBDatabaseRepository {
    
    private let persistentContainer: NSPersistentContainer
    let context: NSManagedObjectContext
    
    let countLimit = 10000
    
    private(set) var count: Int = 0 {
        didSet {
            Log("Count didSet with value: \(count)")
                .inChanel(.database).withType(.debug).make()
            guard count > countLimit else {
                return
            }
            do {
                try cleanUp()
            } catch {
                Log("Unable to remove first element")
                    .inChanel(.database).withType(.error).make()
            }
        }
    }
    
    init(persistentStoreDescriptions: [NSPersistentStoreDescription]? = nil) throws {
        let bundle = Bundle(for: MBDatabaseRepository.self)
        let momdName = "MBDatabase"
        guard let modelURL = bundle.url(forResource: momdName, withExtension: "momd") else {
            throw MBDatabaseError.unableCreateDatabaseModel
        }
        guard let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL) else {
            throw MBDatabaseError.unableCreateManagedObjectModel(with: modelURL)
        }
        let persistentContainer = NSPersistentContainer(name: momdName, managedObjectModel: managedObjectModel)
        // Set descriptions if needed
        if let persistentStoreDescriptions = persistentStoreDescriptions {
            persistentContainer.persistentStoreDescriptions = persistentStoreDescriptions
        }
        var loadPersistentStoresError: Error?
        persistentContainer.loadPersistentStores { (persistentStoreDescription, error) in
            if let persistentStoreURL = persistentStoreDescription.url {
                Log("Persistent store url: \(persistentStoreURL.description)")
                    .inChanel(.database).withType(.info).make()
            } else {
                Log("Unable find persistentStoreURL")
                    .inChanel(.database).withType(.error).make()
            }
            
            loadPersistentStoresError = error
        }
        if let error = loadPersistentStoresError {
            throw MBDatabaseError.unableToLoadPeristentStore(localizedDescription: error.localizedDescription)
        }
        self.persistentContainer = persistentContainer
        self.context = persistentContainer.newBackgroundContext()
        self.context.automaticallyMergesChangesFromParent = true
        self.context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyStoreTrumpMergePolicyType)
        self.count = try countEvents()
        try self.removeDeprecatedEventsIfNeeded()
    }
    
    // MARK: - CRUD operations
    
    func create(event: Event) throws {
        try context.performAndWait {
            let entity = CDEvent(context: context)
            entity.transactionId = event.transactionId
            entity.timestamp = Date().timeIntervalSince1970
            entity.type = event.type.rawValue
            entity.body = event.body
            Log("Adding event with transactionId: \(event.transactionId)")
                .inChanel(.database).withType(.info).make()
            try saveContext()
            count += 1
        }
    }
    
    func read(by transactionId: String) throws -> CDEvent? {
        try context.performAndWait {
            Log("Reading event with transactionId: \(transactionId)")
                .inChanel(.database).withType(.info).make()
            let request: NSFetchRequest<CDEvent> = CDEvent.fetchRequest(by: transactionId)
            guard let entity = try findOrFetch(by: request) else {
                Log("Unable find event with transactionId: \(transactionId)")
                    .inChanel(.database).withType(.error).make()
                return nil
            }
            Log("Did read event with transactionId: \(entity.transactionId ?? "undefined")")
                .inChanel(.database).withType(.info).make()
            return entity
        }
    }
    
    func update(event: Event) throws {
        try context.performAndWait {
            Log("Updating event with transactionId: \(event.transactionId)")
                .inChanel(.database).withType(.info).make()
            let request: NSFetchRequest<CDEvent> = CDEvent.fetchRequest(by: event.transactionId)
            guard let entity = try findOrFetch(by: request) else {
                Log("Unable find event with transactionId: \(event.transactionId)")
                    .inChanel(.database).withType(.error).make()
                return
            }
            entity.retryTimestamp = Date().timeIntervalSince1970
            try saveContext()
        }
    }
    
    func delete(event: Event) throws {
        try context.performAndWait {
            Log("Removing event with transactionId: \(event.transactionId)")
                .inChanel(.database).withType(.info).make()
            let request = CDEvent.fetchRequest(by: event.transactionId)
            guard let entity = try findOrFetch(by: request) else {
                Log("Unable find event with transactionId: \(event.transactionId)")
                    .inChanel(.database).withType(.error).make()
                return
            }
            context.delete(entity)
            try saveContext()
            count -= 1
        }
    }
    
    func query(by request: NSFetchRequest<CDEvent>) throws ->  [CDEvent] {
        try context.fetch(request)
    }
    
    func removeDeprecatedEventsIfNeeded() throws {
        let request: NSFetchRequest<CDEvent> = CDEvent.deprecatedEventsFetchRequest()
        try context.performAndWait {
            Log("Finding deprecated elements")
                .inChanel(.database).withType(.info).make()
            let events = try context.fetch(request)
            guard !events.isEmpty else {
                Log("Deprecated elements not found")
                    .inChanel(.database).withType(.info).make()
                return
            }
            events.forEach {
                Log("Removing event with transactionId: \(String(describing: $0.transactionId)) and timestamp: \(Date(timeIntervalSince1970: $0.timestamp))")
                    .inChanel(.database).withType(.info).make()
                context.delete($0)
                count -= 1
            }
            try saveContext()
        }
    }
    
    private func countEvents() throws -> Int {
        let request: NSFetchRequest<CDEvent> = CDEvent.fetchRequest()
        return try context.performAndWait {
            Log("Events count limit: \(countLimit)")
                .inChanel(.database).withType(.info).make()
            Log("Counting events")
                .inChanel(.database).withType(.info).make()
            do {
                let count = try context.count(for: request)
                Log("Events count: \(count)")
                    .inChanel(.database).withType(.info).make()
                return count
            } catch {
                Log("Counting events failed with error: \(error.localizedDescription)")
                    .inChanel(.database).withType(.error).make()
                throw error
            }
        }
    }
    
    private func cleanUp() throws {
        let request: NSFetchRequest<CDEvent> = CDEvent.fetchRequest()
        request.fetchLimit = 1
        
        try context.performAndWait {
            Log("Removing first element")
                .inChanel(.database).withType(.info).make()
            guard let entity = try findOrFetch(by: request) else {
                Log("Unable to fetch first element")
                    .inChanel(.database).withType(.error).make()
                return
            }
            Log("Removed first element with transactionId: \(String(describing: entity.transactionId))")
                .inChanel(.database).withType(.info).make()
            context.delete(entity)
            try saveContext()
            count -= 1
        }
    }
    
    private func saveContext() throws {
        guard context.hasChanges else {
            return
        }
        do {
            try context.save()
            Log("Context did save")
                .inChanel(.database).withType(.info).make()
        } catch {
            context.rollback()
            Log("Context did save failed with error: \(error)")
                .inChanel(.database).withType(.error).make()
            throw error
        }
    }
    
    private func findOrFetch(by request: NSFetchRequest<CDEvent>) throws -> CDEvent? {
        try find(by: request) ?? fetch(by: request)
    }
    
    private func find(by request: NSFetchRequest<CDEvent>) -> CDEvent? {
        context.registeredObjects
            .compactMap { $0 as? CDEvent }
            .filter { !$0.isFault }
            .filter { request.predicate?.evaluate(with: $0) ?? false }
            .first
    }
    
    private func fetch(by request: NSFetchRequest<CDEvent>) throws -> CDEvent? {
        try context.fetch(request).first
    }
    
}
