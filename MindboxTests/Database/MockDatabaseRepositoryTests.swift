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
        XCTAssert(DI.injectOrFail(DatabaseRepositoryProtocol.self) is MockDatabaseRepository)
    }
    
    func testCreateReadDeleteEvent() throws {
        let event = eventGenerator.generateEvent()
        try repo.create(event: event)
        let cd = try XCTUnwrap(repo.readEvent(by: event.transactionId),
                               "Не смогли прочитать только что созданное событие")
        XCTAssertEqual(cd.transactionId, event.transactionId)
        XCTAssertEqual(cd.body, event.body)
        
        try repo.delete(event: event)
        let afterDelete = try repo.readEvent(by: event.transactionId)
        XCTAssertNil(afterDelete, "Событие должно быть удалено")
    }
    
    func testCountAndErase() throws {
        let count = 5
        let evs = eventGenerator.generateEvents(count: count)
        for e in evs { try repo.create(event: e) }
        let c = try repo.countEvents()
        XCTAssertEqual(c, count)
        
        try repo.erase()
        let c2 = try repo.countEvents()
        XCTAssertEqual(c2, 0, "После erase in-memory хранилище должно быть пустым")
    }
    
    func testLimitEnforcement() throws {
        repo.tempLimit = 3

        let evs = eventGenerator.generateEvents(count: 6)
        for e in evs { try repo.create(event: e) }

        _ = try repo.countEvents()

        let cleanedCount = try repo.countEvents()

        XCTAssertLessThanOrEqual(cleanedCount, repo.limit)
        XCTAssertEqual(cleanedCount, 3,
            "After cleanup there should only be the latest 3 events")
    }
    
    func testIsolationBetweenInstances() throws {
        let e1 = eventGenerator.generateEvent()
        try repo.create(event: e1)
        XCTAssertEqual(try repo.countEvents(), 1)
        
        let repo2 = try MockDatabaseRepository(inMemory: true)
        XCTAssertEqual(try repo2.countEvents(), 0)
    }
    
    func testMockRepositoryUsesInMemoryStore() throws {
        let mockRepo = try MockDatabaseRepository(inMemory: true)
        let container = mockRepo.persistentContainer
        
        let types = container.persistentStoreDescriptions.map(\.type)
        
        XCTAssertEqual(types.count, 1)
        XCTAssertEqual(types.first, NSInMemoryStoreType,
                       "MockDatabaseRepository(inMemory: true) should use in-memory store")
    }
    
    func testProductionRepositoryUsesSQLiteStore() throws {
        let loader = DI.injectOrFail(DatabaseLoaderProtocol.self)
        let sqlContainer = try loader.loadPersistentContainer()
        let prodRepo = try MBDatabaseRepository(persistentContainer: sqlContainer)
        
        let types = prodRepo.persistentContainer.persistentStoreDescriptions.map(\.type)
        
        XCTAssertEqual(types.count, 1)
        XCTAssertEqual(types.first, NSSQLiteStoreType,
                       "MBDatabaseRepository(persistentContainer:) should use SQLite store by default")
    }
}
