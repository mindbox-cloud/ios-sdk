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
    
    convenience init(inMemory: Bool) throws {
        let loader = DI.injectOrFail(DatabaseLoaderProtocol.self)
        let container: NSPersistentContainer = inMemory ? try loader.makeInMemoryContainer() : try loader.loadPersistentContainer()
        try self.init(persistentContainer: container)
    }
}

final class RetryByTimerScriptedDatabaseRepository: MBDatabaseRepository {
    
    private var queryCalls = 0
    
    convenience init() {
        let bundle = Bundle(for: CDEvent.self)
        guard let model = NSManagedObjectModel.mergedModel(from: [bundle]) else {
            fatalError("❌ Could not find Core Data model in bundle \(bundle)")
        }
        
        let container = NSPersistentContainer(name: "FakeContainer", managedObjectModel: model)
        
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
            return try super.query(fetchLimit: fetchLimit, retryDeadline: retryDeadline)
            
        case 2:
            return []
            
        case 3:
            return try super.query(fetchLimit: fetchLimit, retryDeadline: retryDeadline)
            
        default:
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
        
        _ = try countEvents()
    }
    
}
