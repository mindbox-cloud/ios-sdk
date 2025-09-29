//
//  MBDatabaseRepository.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 04.02.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation
import UIKit.UIApplication
import CoreData
import MindboxLogger

class MBDatabaseRepository: DatabaseRepository {

    enum MetadataKey: String {
        case install = "ApplicationInstalledVersion"
        case infoUpdate = "ApplicationInfoUpdatedVersion"
        case instanceId = "ApplicationInstanceId"
    }
    
    // MARK: DatabaseRepository properties - lifecycle / limits

    var limit: Int {
        return 10000
    }
    let deprecatedLimit = 500

    var onObjectsDidChange: (() -> Void)?

    var lifeLimitDate: Date? {
        let calendar: Calendar = .current
        guard let monthLimitDate = calendar.date(byAdding: .month, value: -6, to: Date()) else {
            return nil
        }
        return monthLimitDate
    }
    
    // MARK: DatabaseRepository properties - metadata

    var infoUpdateVersion: Int? {
        get { getMetadata(forKey: .infoUpdate) }
        set { setMetadata(newValue, forKey: .infoUpdate) }
    }

    var installVersion: Int? {
        get { getMetadata(forKey: .install) }
        set { setMetadata(newValue, forKey: .install) }
    }

    var instanceId: String? {
        get { getMetadata(forKey: .instanceId) }
        set { setMetadata(newValue, forKey: .instanceId) }
    }
    
    // MARK: CoreData properties
    
    let persistentContainer: NSPersistentContainer
    private let context: NSManagedObjectContext
    private let store: NSPersistentStore
    
    // MARK: Private properties
    
    private var memoryWarningToken: NSObjectProtocol?
    private var isPruningOnWarning = false
    
    // MARK: Initializer

    init(persistentContainer: NSPersistentContainer) throws {
        self.persistentContainer = persistentContainer
        if let store = persistentContainer.persistentStoreCoordinator.persistentStores.first {
            self.store = store
        } else {
            Logger.common(message: MBDatabaseError.persistentStoreURLNotFound.errorDescription, level: .error, category: .database)
            throw MBDatabaseError.persistentStoreURLNotFound
        }
        self.context = persistentContainer.newBackgroundContext()
        self.context.automaticallyMergesChangesFromParent = true
        self.context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyStoreTrumpMergePolicyType)
        
        startMemoryWarningObserverIfNeeded()
        
        _ = try countEvents()
    }
    
    deinit {
        if let token = memoryWarningToken {
            NotificationCenter.default.removeObserver(token)
            memoryWarningToken = nil
        }
    }
    
    // MARK: Private methods
    
    private func startMemoryWarningObserverIfNeeded() {
        guard store.type == NSInMemoryStoreType, memoryWarningToken == nil else { return }
        memoryWarningToken = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
        Logger.common(message: "[MBDBRepo] Memory warning observer is active (in-memory store).", level: .info, category: .database)
    }
    
    private func handleMemoryWarning() {
        guard store.type == NSInMemoryStoreType else { return }
        if isPruningOnWarning { return }
        isPruningOnWarning = true

        let bg = persistentContainer.newBackgroundContext()
        bg.mergePolicy = NSMergePolicy(merge: .mergeByPropertyStoreTrumpMergePolicyType)

        bg.perform { [weak self] in
            guard let self = self else { return }
            do {
                let req: NSFetchRequest<CDEvent> = CDEvent.fetchRequestForDelete(lifeLimitDate: nil)
                req.includesPropertyValues = false

                let objects = try bg.fetch(req)
                objects.forEach(bg.delete)

                if bg.hasChanges { try bg.save() }
                bg.reset()

                DispatchQueue.main.async { self.onObjectsDidChange?() }

                Logger.common(
                    message: "[MBDBRepo] Aggressive prune on memory warning: removed \(objects.count) events (in-memory).",
                    level: .info,
                    category: .database
                )
            } catch {
                Logger.common(
                    message: "[MBDBRepo] Aggressive prune failed on memory warning: \(error)",
                    level: .error,
                    category: .database
                )
            }
            DispatchQueue.main.async { self.isPruningOnWarning = false }
        }
    }
    
    private func read(by transactionId: String) throws -> CDEvent? {
        try context.executePerformAndWait {
            Logger.common(message: "[MBDBRepo] Reading event with transactionId: \(transactionId)", level: .info, category: .database)
            let request: NSFetchRequest<CDEvent> = CDEvent.fetchRequest(by: transactionId)
            guard let entity = try findEvent(by: request) else {
                Logger.common(message: "[MBDBRepo] Unable to find event with transactionId: \(transactionId)", level: .error, category: .database)
                return nil
            }
            Logger.common(message: "[MBDBRepo] Did read event with transactionId: \(entity.transactionId ?? "undefined")", level: .info, category: .database)
            return entity
        }
    }
    
    private func cleanUp(count: Int) {
        let fetchLimit = count - limit
        guard fetchLimit > .zero else { return }

        let request: NSFetchRequest<CDEvent> = CDEvent.fetchRequestForDelete()
        request.fetchLimit = fetchLimit
        do {
            try delete(by: request, withContext: context)
        } catch {
            Logger.common(message: "[MBDBRepo] Unable to remove elements", level: .error, category: .database)
        }
    }

    private func delete(by request: NSFetchRequest<CDEvent>, withContext context: NSManagedObjectContext) throws {
        try context.executePerformAndWait {
            Logger.common(message: "[MBDBRepo] Finding elements to remove", level: .info, category: .database)

            let events = try context.fetch(request)
            guard !events.isEmpty else {
                Logger.common(message: "[MBDBRepo] Elements to remove not found", level: .info, category: .database)
                return
            }
            events.forEach {
                Logger.common(message: "[MBDBRepo] Remove element `\(String(describing: $0.type))` with transactionId: \(String(describing: $0.transactionId)) and timestamp: \(Date(timeIntervalSince1970: $0.timestamp))",
                              level: .info, category: .database)
                context.delete($0)
            }
            try saveEvent(withContext: context)
        }
    }

    private func findEvent(by request: NSFetchRequest<CDEvent>) throws -> CDEvent? {
        try context.registeredObjects
            .compactMap { $0 as? CDEvent }
            .first(where: { !$0.isFault && request.predicate?.evaluate(with: $0) ?? false })
        ?? context.fetch(request).first
    }

    // MARK: - DatabaseRepository: CRUD operations
    
    func create(event: Event) throws {
        try context.executePerformAndWait {
            let entity = CDEvent(context: context)
            entity.transactionId = event.transactionId
            entity.timestamp = Date().timeIntervalSince1970
            entity.type = event.type.rawValue
            entity.body = event.body
            Logger.common(message: "[MBDBRepo] Creating event `\(event.type.rawValue)` with transactionId: \(event.transactionId)", level: .info, category: .database)
            try saveEvent(withContext: context)
        }
    }
    
    func readEvent(by transactionId: String) throws -> Event? {
        guard let entity = try read(by: transactionId) else { return nil }
        return Event(entity)
    }

    func update(event: Event) throws {
        try context.executePerformAndWait {
            Logger.common(message: "[MBDBRepo] Updating event \(event.type.rawValue) with transactionId: \(event.transactionId)", level: .info, category: .database)
            let request: NSFetchRequest<CDEvent> = CDEvent.fetchRequest(by: event.transactionId)
            guard let entity = try findEvent(by: request) else {
                Logger.common(message: "[MBDBRepo] Unable to find event `\(event.type.rawValue)` with transactionId: \(event.transactionId)", level: .error, category: .database)
                return
            }
            entity.retryTimestamp = Date().timeIntervalSince1970
            try saveEvent(withContext: context)
        }
    }

    func delete(event: Event) throws {
        try context.executePerformAndWait {
            Logger.common(message: "[MBDBRepo] Deleting event `\(event.type.rawValue)` with transactionId: \(event.transactionId)", level: .info, category: .database)
            let request = CDEvent.fetchRequest(by: event.transactionId)
            guard let entity = try findEvent(by: request) else {
                Logger.common(message: "[MBDBRepo] Unable to find event `\(event.type.rawValue)` with transactionId: \(event.transactionId)", level: .error, category: .database)
                return
            }
            context.delete(entity)
            try saveEvent(withContext: context)
        }
    }
    
    // MARK: - DatabaseRepository: queries and maintenance

    func query(fetchLimit: Int, retryDeadline: TimeInterval = Constants.Database.retryDeadline) throws -> [Event] {
        try context.executePerformAndWait {
            let request: NSFetchRequest<CDEvent> = CDEvent.fetchRequestForSend(lifeLimitDate: lifeLimitDate, retryDeadLine: retryDeadline)
            request.fetchLimit = fetchLimit
            let events = try context.fetch(request)
            guard !events.isEmpty else {
                Logger.common(message: "[MBDBRepo] Unable to find events", level: .info, category: .delivery)
                return []
            }
            Logger.common(message: "[MBDBRepo] Did query events count `\(events.count)` with fetchLimit `\(fetchLimit)`", level: .info, category: .database)
            return events.compactMap {
                let event = Event($0)
                Logger.common(message: "[MBDBRepo] Event `\(String(describing: event?.type.rawValue ?? "null"))` with transactionId: \(String(describing: event?.transactionId ?? "null"))",
                              level: .info, category: .database)
                return event
            }
        }
    }

    func query(by request: NSFetchRequest<CDEvent>) throws -> [CDEvent] {
        try context.fetch(request)
    }

    func removeDeprecatedEventsIfNeeded() throws {
        let request: NSFetchRequest<CDEvent> = CDEvent.deprecatedEventsFetchRequest(lifeLimitDate: lifeLimitDate)
        let context = persistentContainer.newBackgroundContext()
        try delete(by: request, withContext: context)
    }

    func countDeprecatedEvents() throws -> Int {
        let context = persistentContainer.newBackgroundContext()
        let request: NSFetchRequest<CDEvent> = CDEvent.deprecatedEventsFetchRequest(lifeLimitDate: lifeLimitDate)
        return try context.executePerformAndWait {
            Logger.common(message: "[MBDBRepo] Counting deprecated elements", level: .info, category: .database)
            do {
                let count = try context.count(for: request)
                Logger.common(message: "[MBDBRepo] Deprecated Events did count: \(count)", level: .info, category: .database)
                return count
            } catch {
                Logger.common(message: "[MBDBRepo] Counting events failed with error: \(error.localizedDescription)", level: .error, category: .database)
                throw error
            }
        }
    }

    func erase() throws {
        
        infoUpdateVersion = nil
        installVersion    = nil

        let entityName = "CDEvent"

        if store.type == NSInMemoryStoreType {
            let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            fetch.includesPropertyValues = false

            try context.executePerformAndWait {
                let objects = try (context.fetch(fetch) as? [NSManagedObject]) ?? []
                objects.forEach(context.delete)

                if context.hasChanges {
                    try context.save()
                }
                context.reset()
            }
            return
        }

        let fetch  = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        let delete = NSBatchDeleteRequest(fetchRequest: fetch)
        delete.resultType = .resultTypeObjectIDs

        try context.executePerformAndWait {
            if let result = try context.execute(delete) as? NSBatchDeleteResult,
               let ids    = result.result as? [NSManagedObjectID],
               !ids.isEmpty {
                NSManagedObjectContext.mergeChanges(
                    fromRemoteContextSave: [NSDeletedObjectsKey: ids],
                    into: [context]
                )
            }
            context.reset()
        }
    }

    @discardableResult
    func countEvents() throws -> Int {
        let request: NSFetchRequest<CDEvent> = CDEvent.countEventsFetchRequest()
        return try context.executePerformAndWait {
            do {
                let count = try context.count(for: request)
                cleanUp(count: count)
                return count
            } catch {
                Logger.common(message: "[MBDBRepo] Counting events failed with error: \(error.localizedDescription)", level: .error, category: .database)
                throw error
            }
        }
    }
}

// MARK: - ManagedObjectContext save processing

private extension MBDatabaseRepository {

    func saveEvent(withContext context: NSManagedObjectContext) throws {
        guard context.hasChanges else { return }

        try saveContext(context)
        onObjectsDidChange?()
    }

    func saveContext(_ context: NSManagedObjectContext) throws {
        do {
            try context.save()
        } catch {
            switch error {
            case let error as NSError where error.domain == NSSQLiteErrorDomain && error.code == 13:
                Logger.common(message: "[MBDBRepo] Context did save failed with SQLite Database out of space error: \(error)", level: .error, category: .database)
                fallthrough
            default:
                context.rollback()
                Logger.common(message: "[MBDBRepo] Context did save failed with error: \(error)", level: .error, category: .database)
            }
            throw error
        }
    }
}

// MARK: - Metadata processing

private extension MBDatabaseRepository {

    func getMetadata<T>(forKey key: MetadataKey) -> T? {
        let value = store.metadata[key.rawValue] as? T
        Logger.common(message: "[MBDBRepo] Fetch metadata for key: \(key.rawValue) with value: \(String(describing: value))", level: .info, category: .database)
        return value
    }

    func setMetadata<T>(_ value: T?, forKey key: MetadataKey) {
        store.metadata[key.rawValue] = value
        persistentContainer.persistentStoreCoordinator.setMetadata(store.metadata, for: store)
        do {
            try context.executePerformAndWait {
                try saveContext(context)
                Logger.common(message: "[MBDBRepo] Did save metadata of \(key.rawValue) to: \(String(describing: value))", level: .info, category: .database)
            }
        } catch {
            Logger.common(message: "[MBDBRepo] Did save metadata of \(key.rawValue) failed with error: \(error.localizedDescription)", level: .error, category: .database)
        }
    }
}
