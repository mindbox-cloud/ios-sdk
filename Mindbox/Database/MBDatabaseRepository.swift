//
//  MBDatabaseRepository.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 04.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import CoreData

class MBDatabaseRepository {
    
    let persistentContainer: NSPersistentContainer
    private let context: NSManagedObjectContext
    private let store: NSPersistentStore
    
    let limit = 10000
    let deprecatedLimit = 500
    
    var onObjectsDidChange: (() -> Void)?
    
    var lifeLimitDate: Date? {
        let calendar: Calendar = .current
        guard let monthLimitDate = calendar.date(byAdding: .month, value: -6, to: Date()) else {
            return nil
        }
        return monthLimitDate
    }
    
    private(set) var count: Int = 0 {
        didSet {
            Log("Count didSet with value: \(count)")
                .category(.database).level(.info).make()
            if count != oldValue {
                onObjectsDidChange?()
            }
            guard count > limit else {
                return
            }
            do {
                try cleanUp()
            } catch {
                Log("Unable to remove first element")
                    .category(.database).level(.error).make()
            }
        }
    }
    
    init(persistentContainer: NSPersistentContainer) throws {
        self.persistentContainer = persistentContainer
        if let store = persistentContainer.persistentStoreCoordinator.persistentStores.first {
            self.store = store
        } else {
            throw MBDatabaseError.persistentStoreURLNotFound
        }
        self.context = persistentContainer.newBackgroundContext()
        self.context.automaticallyMergesChangesFromParent = true
        self.context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyStoreTrumpMergePolicyType)
        _ = try countEvents()
    }
    
    enum MetadataKey: String {
        
        case install = "ApplicationInstalledVersion"
        case infoUpdate = "ApplicationInfoUpdatedVersion"
        case instanceId = "ApplicationInstanceId"
        
    }
    
    var infoUpdateVersion: Int? {
        get {
            getMetadata(forKey: .infoUpdate)
        }
        set {
            setMetadata(newValue, forKey: .infoUpdate)
        }
    }
    
    var installVersion: Int? {
        get {
            getMetadata(forKey: .install)
        }
        set {
            setMetadata(newValue, forKey: .install)
        }
    }
    
    var instanceId: String? {
        get {
            getMetadata(forKey: .instanceId)
        }
        set {
            setMetadata(newValue, forKey: .instanceId)
        }
    }
    
    // MARK: - CRUD operations
    func create(event: Event) throws {
        try context.performAndWait {
            let entity = CDEvent(context: context)
            entity.transactionId = event.transactionId
            entity.timestamp = Date().timeIntervalSince1970
            entity.type = event.type.rawValue
            entity.body = event.body
            Log("Creating event with transactionId: \(event.transactionId)")
                .category(.database).level(.info).make()
            try saveContext(context)
            count += 1
        }
    }
    
    func read(by transactionId: String) throws -> CDEvent? {
        try context.performAndWait {
            Log("Reading event with transactionId: \(transactionId)")
                .category(.database).level(.info).make()
            let request: NSFetchRequest<CDEvent> = CDEvent.fetchRequest(by: transactionId)
            guard let entity = try findOrFetch(by: request) else {
                Log("Unable to find event with transactionId: \(transactionId)")
                    .category(.database).level(.error).make()
                return nil
            }
            Log("Did read event with transactionId: \(entity.transactionId ?? "undefined")")
                .category(.database).level(.info).make()
            return entity
        }
    }
    
    func update(event: Event) throws {
        try context.performAndWait {
            Log("Updating event with transactionId: \(event.transactionId)")
                .category(.database).level(.info).make()
            let request: NSFetchRequest<CDEvent> = CDEvent.fetchRequest(by: event.transactionId)
            guard let entity = try findOrFetch(by: request) else {
                Log("Unable to find event with transactionId: \(event.transactionId)")
                    .category(.database).level(.error).make()
                return
            }
            entity.retryTimestamp = Date().timeIntervalSince1970
            try saveContext(context)
        }
    }
    
    func delete(event: Event) throws {
        try context.performAndWait {
            Log("Deleting event with transactionId: \(event.transactionId)")
                .category(.database).level(.info).make()
            let request = CDEvent.fetchRequest(by: event.transactionId)
            guard let entity = try findOrFetch(by: request) else {
                Log("Unable to find event with transactionId: \(event.transactionId)")
                    .category(.database).level(.error).make()
                return
            }
            context.delete(entity)
            try saveContext(context)
            count -= 1
        }
    }
    
    func query(fetchLimit: Int, retryDeadline: TimeInterval = 60) throws ->  [Event] {
        try context.performAndWait {
            Log("Quering events with fetchLimit: \(fetchLimit)")
                .category(.database).level(.info).make()
            let request: NSFetchRequest<CDEvent> = CDEvent.fetchRequest(lifeLimitDate: lifeLimitDate, retryDeadLine: retryDeadline)
            request.fetchLimit = fetchLimit
            let events = try context.fetch(request)
            guard !events.isEmpty else {
                Log("Unable to find events")
                    .category(.delivery).level(.info).make()
                return []
            }
            Log("Did query events count: \(events.count)")
                .category(.database).level(.info).make()
            events.forEach {
                Log("Event with transactionId: \(String(describing: $0.transactionId))")
                    .category(.database).level(.info).make()
            }
            return events.compactMap {
                Event($0)
            }
        }
    }
    
    func query(by request: NSFetchRequest<CDEvent>) throws ->  [CDEvent] {
        try context.fetch(request)
    }
    
    func removeDeprecatedEventsIfNeeded() throws {
        let request: NSFetchRequest<CDEvent> = CDEvent.deprecatedEventsFetchRequest(lifeLimitDate: lifeLimitDate)
        let context = persistentContainer.newBackgroundContext()
        try context.performAndWait {
            Log("Finding deprecated elements")
                .category(.database).level(.info).make()
            let events = try context.fetch(request)
            guard !events.isEmpty else {
                Log("Deprecated elements not found")
                    .category(.database).level(.info).make()
                return
            }
            events.forEach {
                Log("Deleting event with transactionId: \(String(describing: $0.transactionId)) and timestamp: \(Date(timeIntervalSince1970: $0.timestamp))")
                    .category(.database).level(.info).make()
                context.delete($0)
                count -= 1
            }
            try saveContext(context)
        }
    }
    
    func countDeprecatedEvents() throws -> Int {
        let context = persistentContainer.newBackgroundContext()
        let request: NSFetchRequest<CDEvent> = CDEvent.deprecatedEventsFetchRequest(lifeLimitDate: lifeLimitDate)
        return try context.performAndWait {
            Log("Counting deprecated elements")
                .category(.database).level(.info).make()
            do {
                let count = try context.count(for: request)
                Log("Deprecated Events did count: \(count)")
                    .category(.database).level(.info).make()
                return count
            } catch {
                Log("Counting events failed with error: \(error.localizedDescription)")
                    .category(.database).level(.error).make()
                throw error
            }
        }
    }
    
    func erase() throws {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "CDEvent")
        let eraseRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        infoUpdateVersion = nil
        installVersion = nil
        try context.performAndWait {
            try context.execute(eraseRequest)
            try saveContext(context)
            try countEvents()
        }
    }
    
    @discardableResult
    func countEvents() throws -> Int {
        let request: NSFetchRequest<CDEvent> = CDEvent.countEventsFetchRequest(lifeLimitDate: lifeLimitDate)
        return try context.performAndWait {
            Log("Events count limit: \(limit)")
                .category(.database).level(.info).make()
            Log("Counting events")
                .category(.database).level(.info).make()
            do {
                let count = try context.count(for: request)
                self.count = count
                Log("Events count: \(count)")
                    .category(.database).level(.info).make()
                return count
            } catch {
                Log("Counting events failed with error: \(error.localizedDescription)")
                    .category(.database).level(.error).make()
                throw error
            }
        }
    }
    
    private func cleanUp() throws {
        let request: NSFetchRequest<CDEvent> = CDEvent.fetchRequest(lifeLimitDate: lifeLimitDate)
        request.fetchLimit = 1
        
        try context.performAndWait {
            Log("Deleting first element")
                .category(.database).level(.info).make()
            guard let entity = try fetch(by: request) else {
                Log("Unable to fetch first element")
                    .category(.database).level(.error).make()
                return
            }
            Log("Deleted first element with transactionId: \(String(describing: entity.transactionId))")
                .category(.database).level(.info).make()
            context.delete(entity)
            try saveContext(context)
            count -= 1
        }
    }
    
    private func saveContext(_ context: NSManagedObjectContext) throws {
        guard context.hasChanges else {
            return
        }
        do {
            try context.save()
            Log("Context did save")
                .category(.database).level(.info).make()
        } catch {
            context.rollback()
            Log("Context did save failed with error: \(error)")
                .category(.database).level(.error).make()
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
    
    private func getMetadata<T>(forKey key: MetadataKey) -> T? {
        let value = store.metadata[key.rawValue] as? T
        Log("Fetch metadata for key: \(key.rawValue) with value: \(String(describing: value))")
            .category(.database).level(.info).make()
        return value
    }
    
    private func setMetadata<T>(_ value: T?, forKey key: MetadataKey) {
        store.metadata[key.rawValue] = value
        persistentContainer.persistentStoreCoordinator.setMetadata(store.metadata, for: store)
        do {
            try saveContext(context)
            Log("Did save metadata of \(key.rawValue) to: \(String(describing: value))")
                .category(.database).level(.info).make()
        } catch {
            Log("Did save metadata of \(key.rawValue) failed with error: \(error.localizedDescription)")
                .category(.database).level(.error).make()
        }
    }
    
}
