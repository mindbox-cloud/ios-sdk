//
//  DatabaseRepository_NoopContractTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 9/29/25.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

final class DatabaseRepository_NoopContractTests: XCTestCase {

    var repo: DatabaseRepositoryProtocol!

    override func setUp() {
        super.setUp()
        repo = NoopDatabaseRepository()
    }

    override func tearDown() {
        repo = nil
        super.tearDown()
    }

    func test_NoThrow_AllMutating() {
        XCTAssertNoThrow(try repo.erase())
        XCTAssertNoThrow(try repo.create(event: Event(type: .customEvent, body: "{}")))
        XCTAssertNoThrow(try repo.update(event: Event(type: .customEvent, body: "{}")))
        XCTAssertNoThrow(try repo.delete(event: Event(type: .customEvent, body: "{}")))
        XCTAssertNoThrow(try repo.removeDeprecatedEventsIfNeeded())
    }

    func test_CountAlwaysZero() throws {
        try repo.erase()
        XCTAssertEqual(try repo.countEvents(), 0)

        try repo.create(event: Event(type: .installed, body: "{}"))
        XCTAssertEqual(try repo.countEvents(), 0)

        try repo.update(event: Event(type: .installed, body: "{}"))
        XCTAssertEqual(try repo.countEvents(), 0)

        try repo.delete(event: Event(type: .installed, body: "{}"))
        XCTAssertEqual(try repo.countEvents(), 0)
    }

    func test_ReadAlwaysNil() throws {
        let e = Event(type: .customEvent, body: "{}")
        try repo.create(event: e)
        XCTAssertNil(try repo.readEvent(by: e.transactionId))
        XCTAssertNil(try repo.readEvent(by: "non-existing"))
    }

    func test_QueryAlwaysEmpty() throws {
        XCTAssertTrue(try repo.query(fetchLimit: 10).isEmpty)
        XCTAssertTrue(try repo.query(fetchLimit: 10, retryDeadline: 1).isEmpty)
    }

    func test_DeprecatedCountersAndCleanup() throws {
        XCTAssertEqual(try repo.countDeprecatedEvents(), 0)
        XCTAssertNoThrow(try repo.removeDeprecatedEventsIfNeeded())
        XCTAssertEqual(try repo.countDeprecatedEvents(), 0)
    }

    func test_MetadataIgnored() {
        repo.infoUpdateVersion = 123
        repo.installVersion = 456
        repo.instanceId = "abc"

        XCTAssertNil(repo.infoUpdateVersion)
        XCTAssertNil(repo.installVersion)
        XCTAssertNil(repo.instanceId)
    }

    func test_OnObjectsDidChange_NotFired() throws {
        var fired = false
        repo.onObjectsDidChange = { fired = true }

        try repo.create(event: Event(type: .installed, body: "{}"))
        try repo.update(event: Event(type: .installed, body: "{}"))
        try repo.delete(event: Event(type: .installed, body: "{}"))
        try repo.erase()

        XCTAssertFalse(fired, "Noop should not trigger onObjectsDidChange")
    }

    func test_ReadProperties_NoCrash() {
        _ = repo.limit
        _ = repo.deprecatedLimit
        _ = repo.lifeLimitDate
    }
}
