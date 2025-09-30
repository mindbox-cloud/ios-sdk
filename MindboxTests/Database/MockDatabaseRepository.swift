//
//  MockDatabaseRepository.swift
//  MindboxTests
//
//  Created by Maksim Kazachkov on 29.03.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation
import CoreData
@testable import Mindbox

final class MockDatabaseRepository: MBDatabaseRepository {

    var createsDeprecated: Bool = false
    var tempLimit: Int?

    override var limit: Int {
        tempLimit ?? super.limit
    }

    override var lifeLimitDate: Date? {
        createsDeprecated ? Date() : super.lifeLimitDate
    }
    
    /// Creates a Core Data stack for in-memory tests or persistent storage.
    ///
    /// - Parameter inMemory: Pass `true` to use an in-memory store (good for unit tests).
    /// - Throws: Errors thrown while creating the underlying ``NSPersistentContainer``.
    /// - Note: Useful for unit tests to avoid writing to disk.
    /// - See also:
    ///   - [Setting up a Core Data store for unit tests (Donny Wals)](https://www.donnywals.com/setting-up-a-core-data-store-for-unit-tests/)
    convenience init(inMemory: Bool) throws {
        let loader = DI.injectOrFail(DatabaseLoaderProtocol.self)
        let container: NSPersistentContainer = inMemory ? try loader.makeInMemoryContainer() : try loader.loadPersistentContainer()
        try self.init(persistentContainer: container)
    }
}


/// MBDatabaseRepository can get events via `query(fetchLimit:retryDeadline:)`.
/// For `GuaranteedDeliveryTestCase.testFailureAndRetryScheduleByTimer`:
/// 1st call to return all events (first run),
/// 2nd — empty (waitingForRetry branch),
/// 3rd — events again (retry),
/// 4th and further — empty (after deletion).
final class FakeDatabaseRepository: MBDatabaseRepository {
    
    private var queryCalls = 0
    
    /// Convenience initializer, which does not search .xcdatamodeld by name,
    /// but loads any model from the same bundle as your CDEvent class,
    /// and sets the In-Memory store.
    convenience init() {
        let bundle = Bundle(for: CDEvent.self)
        guard let model = NSManagedObjectModel.mergedModel(from: [bundle]) else {
            fatalError("❌ Could not find Core Data model in bundle \(bundle)")
        }
        
        let container = NSPersistentContainer(name: "FakeContainer", managedObjectModel: model)
        
        // Don't install SQLite, but keep everything in memory
        let desc = NSPersistentStoreDescription()
        desc.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [desc]
        
        container.loadPersistentStores { description, error in
            if let err = error {
                fatalError("❌ In-memory store load failed: \(err)")
            }
        }
        
        try! self.init(persistentContainer: container)
    }
    
    override func query(fetchLimit: Int, retryDeadline: TimeInterval = 60) throws -> [Event] {
        queryCalls += 1
        
        switch queryCalls {
        case 1:
            // First Run: Real MBDatabaseRepository.query
            return try super.query(fetchLimit: fetchLimit, retryDeadline: retryDeadline)
            
        case 2:
            // Second run: empty → waitingForRetry
            return []
            
        case 3:
            // Third run: events for retry
            return try super.query(fetchLimit: fetchLimit, retryDeadline: retryDeadline)
            
        default:
            // Fourth and beyond: empty (after deletion)
            return []
        }
    }
    
    override func erase() throws {
        let bg = persistentContainer.newBackgroundContext()
        try bg.mindboxPerformAndWait {
            let fetch: NSFetchRequest<CDEvent> = NSFetchRequest<CDEvent>(entityName: "CDEvent")
            let all = try bg.fetch(fetch)
            for e in all {
                bg.delete(e)
            }
            try bg.save()
        }
        
        installVersion    = nil
        infoUpdateVersion = nil
        
        _ = try countEvents()
    }
    
}
