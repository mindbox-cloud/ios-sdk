//
//  MockDatabaseRepositoryTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 6/20/25.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import XCTest
import CoreData
@testable import Mindbox

final class MockDatabaseRepositoryTests: XCTestCase {
    
    var repo: MockDatabaseRepository!
    var eventGenerator: EventGenerator!
    
    override func setUp() {
        super.setUp()
        repo = try! MockDatabaseRepository(inMemory: true)
        eventGenerator = EventGenerator()
        try! repo.erase()
    }

    override func tearDown() {
        repo = nil
        eventGenerator = nil
        super.tearDown()
    }
    
    func testRegisterMBDBRepoIsMock() {
        XCTAssert(DI.injectOrFail(DatabaseRepository.self) is MockDatabaseRepository)
    }
    
    func testCreateReadDeleteEvent() throws {
        let event = eventGenerator.generateEvent()
        // creation
        try repo.create(event: event)
        // reading
        let cd = try XCTUnwrap(repo.readEvent(by: event.transactionId),
                               "Не смогли прочитать только что созданное событие")
        XCTAssertEqual(cd.transactionId, event.transactionId)
        XCTAssertEqual(cd.body, event.body)
        
        // deletion
        try repo.delete(event: event)
        let afterDelete = try repo.readEvent(by: event.transactionId)
        XCTAssertNil(afterDelete, "Событие должно быть удалено")
    }
    
    func testCountAndErase() throws {
        // create 5
        let count = 5
        let evs = eventGenerator.generateEvents(count: count)
        for e in evs { try repo.create(event: e) }
        let c = try repo.countEvents()
        XCTAssertEqual(c, count)
        
        // erase
        try repo.erase()
        let c2 = try repo.countEvents()
        XCTAssertEqual(c2, 0, "После erase in-memory хранилище должно быть пустым")
    }
    
    func testLimitEnforcement() throws {
        // override the limit to 3
        repo.tempLimit = 3

        // insert 6 events
        let evs = eventGenerator.generateEvents(count: 6)
        for e in evs { try repo.create(event: e) }

        // first call will trigger cleanUp(count:), but still
        // return the pre-cleanup count (6), so ignore it
        _ = try repo.countEvents()

        // second call will return the post-cleanup count
        let cleanedCount = try repo.countEvents()

        XCTAssertLessThanOrEqual(cleanedCount, repo.limit)
        XCTAssertEqual(cleanedCount, 3,
            "After cleanup there should only be the latest 3 events")
    }
    
    func testIsolationBetweenInstances() throws {
        // the first instance stores the event
        let e1 = eventGenerator.generateEvent()
        try repo.create(event: e1)
        XCTAssertEqual(try repo.countEvents(), 1)
        
        // new in-memory instance - empty
        let repo2 = try MockDatabaseRepository(inMemory: true)
        XCTAssertEqual(try repo2.countEvents(), 0)
    }
    
    func testMetadataPersistenceAndErase() throws {
        // check reading/writing metadata
        repo.installVersion = 42
        repo.infoUpdateVersion = 99
        repo.instanceId = "foo"
        
        XCTAssertEqual(repo.installVersion, 42)
        XCTAssertEqual(repo.infoUpdateVersion, 99)
        XCTAssertEqual(repo.instanceId, "foo")
        
        // erase should clear metadata
        try repo.erase()
        XCTAssertNil(repo.installVersion)
        XCTAssertNil(repo.infoUpdateVersion)
        XCTAssertNotNil(repo.instanceId)
    }
    
    func testMockRepositoryUsesInMemoryStore() throws {
        // GIVEN
        let mockRepo = try MockDatabaseRepository(inMemory: true)
        let container = mockRepo.persistentContainer
        
        // WHEN
        // Save the list of store descriptions that have been configured
        let types = container.persistentStoreDescriptions.map(\.type)
        
        // THEN
        // There must be exactly one container, and it must be in-memory
        XCTAssertEqual(types.count, 1)
        XCTAssertEqual(types.first, NSInMemoryStoreType,
                       "MockDatabaseRepository(inMemory: true) should use in-memory store")
    }
    
    func testProductionRepositoryUsesSQLiteStore() throws {
        // GIVEN
        // We load the real container in the same way as in the application
        let loader = DI.injectOrFail(DatabaseLoading.self)
        let sqlContainer = try loader.loadPersistentContainer()
        let prodRepo = try MBDatabaseRepository(persistentContainer: sqlContainer)
        
        // WHEN
        let types = prodRepo.persistentContainer.persistentStoreDescriptions.map(\.type)
        
        // THEN
        XCTAssertEqual(types.count, 1)
        XCTAssertEqual(types.first, NSSQLiteStoreType,
                       "MBDatabaseRepository(persistentContainer:) should use SQLite store by default")
    }
}
