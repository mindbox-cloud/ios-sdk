//
//  MBDatabaseRepositoryMemoryWarningTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 9/25/25.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import XCTest
import CoreData
import UIKit
@testable import Mindbox

final class MBDatabaseRepositoryMemoryWarningTests: XCTestCase {
    
    var eventGenerator: EventGenerator!
    var dbLoader: DatabaseLoading!
    
    override func setUp() {
        super.setUp()
        eventGenerator = EventGenerator()
        dbLoader = DI.injectOrFail(DatabaseLoading.self)
    }
    
    override func tearDown() {
        eventGenerator = nil
        dbLoader = nil
        super.tearDown()
    }

    func test_InMemory_PrunesAll_OnMemoryWarning() throws {
        let container = try dbLoader.makeInMemoryContainer()
        let databaseRepository = try MBDatabaseRepository(persistentContainer: container)

        let events = eventGenerator.generateEvents(count: 50)
        try events.forEach { try databaseRepository.create(event: $0) }
        XCTAssertEqual(try databaseRepository.countEvents(), 50, "Precondition: 50 events stored in-memory")

        let exp = expectation(description: "onObjectsDidChange fired after prune")
        databaseRepository.onObjectsDidChange = { exp.fulfill() }

        NotificationCenter.default.post(
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )

        wait(for: [exp], timeout: 2.0)

        XCTAssertEqual(try databaseRepository.countEvents(), 0, "All in-memory events must be pruned on memory warning")
    }

    func test_SQLite_IgnoresMemoryWarning() throws {
        let container = try dbLoader.loadPersistentContainer()
        let databaseRepository = try MBDatabaseRepository(persistentContainer: container)

        let events = eventGenerator.generateEvents(count: 20)
        try events.forEach { try databaseRepository.create(event: $0) }
        let before = try databaseRepository.countEvents()

        let inverted = expectation(description: "onObjectsDidChange should NOT fire for SQLite")
        inverted.isInverted = true
        databaseRepository.onObjectsDidChange = { inverted.fulfill() }
        
        NotificationCenter.default.post(
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        wait(for: [inverted], timeout: 0.5)
        
        let after = try databaseRepository.countEvents()
        XCTAssertEqual(before, after, "SQLite store must ignore memory warning pruning logic")
    }

    func test_InMemory_PruneIsIdempotent_WhenWarningsBurst() throws {
        let container = try dbLoader.makeInMemoryContainer()
        let databaseRepository = try MBDatabaseRepository(persistentContainer: container)

        let events = eventGenerator.generateEvents(count: 30)
        try events.forEach { try databaseRepository.create(event: $0) }
        XCTAssertEqual(try databaseRepository.countEvents(), 30)

        let exp = expectation(description: "prune completed once")
        exp.expectedFulfillmentCount = 1
        databaseRepository.onObjectsDidChange = { exp.fulfill() }

        for _ in 0..<5 {
            NotificationCenter.default.post(
                name: UIApplication.didReceiveMemoryWarningNotification,
                object: nil
            )
        }

        wait(for: [exp], timeout: 2.0)
        XCTAssertEqual(try databaseRepository.countEvents(), 0, "After burst of warnings, repository must end up empty")
    }
}

