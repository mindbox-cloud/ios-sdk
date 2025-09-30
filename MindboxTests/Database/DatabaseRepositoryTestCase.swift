//
//  CreateDatabaseRepositoryTestCase.swift
//  MindboxTests
//
//  Created by Maksim Kazachkov on 05.02.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import XCTest
import CoreData
@testable import Mindbox

class DatabaseRepositoryTestCase: XCTestCase {

    var databaseRepository: DatabaseRepositoryProtocol!
    var eventGenerator: EventGenerator!

    override func setUpWithError() throws {
        super.setUp()
        databaseRepository = DI.injectOrFail(DatabaseRepositoryProtocol.self)
        eventGenerator = EventGenerator()

        try databaseRepository.erase()
        updateDatabaseRepositoryWith(createsDeprecated: false)
    }

    override func tearDown() {
        databaseRepository = nil
        eventGenerator = nil
        super.tearDown()
    }

    private func updateDatabaseRepositoryWith(createsDeprecated: Bool) {
        guard let mockDatabaseRepository = databaseRepository as? MockDatabaseRepository else {
            fatalError("Failed to cast databaseRepository to MockDatabaseRepository")
        }

        mockDatabaseRepository.createsDeprecated = createsDeprecated
    }

    func testCreateEvent() throws {
        let event = eventGenerator.generateEvent()
        try databaseRepository.create(event: event)
    }

    func testReadEvent() throws {
        let event = eventGenerator.generateEvent()
        try databaseRepository.create(event: event)

        let entity = try databaseRepository.readEvent(by: event.transactionId)
        XCTAssertNotNil(entity)
    }

    func testUpdateEvent() throws {
        let event = eventGenerator.generateEvent()
        var initialRetryTimeStamp: Double?
        var updatedRetryTimeStamp: Double?
        try databaseRepository.create(event: event)

        var entity = try databaseRepository.readEvent(by: event.transactionId)
        initialRetryTimeStamp = entity?.retryTimestamp
        XCTAssertNotNil(initialRetryTimeStamp)

        try databaseRepository.update(event: event)

        entity = try databaseRepository.readEvent(by: event.transactionId)
        XCTAssertNotNil(initialRetryTimeStamp)
        updatedRetryTimeStamp = entity?.retryTimestamp

        XCTAssertNotEqual(initialRetryTimeStamp, updatedRetryTimeStamp)
    }

    func testDeleteEvent() throws {
        let event = eventGenerator.generateEvent()
        try databaseRepository.create(event: event)

        try databaseRepository.delete(event: event)
    }

    func testHasEventsAfterCreation() throws {
        databaseRepository.onObjectsDidChange = { [self] in
            do {
                let totalEvents = try self.databaseRepository.countEvents()
                XCTAssertGreaterThan(totalEvents, 0)
            } catch {
                XCTFail(error.localizedDescription)
            }
        }

        let event = eventGenerator.generateEvent()
        try databaseRepository.create(event: event)
    }

    func testCleanUpWhenTryingToCountEventsWhenExceedingTheLimit() throws {
        try databaseRepository.erase()

        let temporaryLimit = 3
        guard let mockDatabaseRepository = databaseRepository as? MockDatabaseRepository else {
            fatalError("databaseRepository is not a MockDatabaseRepository")
        }
        mockDatabaseRepository.tempLimit = temporaryLimit
        XCTAssertEqual(databaseRepository.limit, temporaryLimit)

        let doubleLimit = databaseRepository.limit * 2
        let events = eventGenerator.generateEvents(count: doubleLimit)

        try events.forEach {
            try databaseRepository.create(event: $0)
        }

        let countsEventsBeforeCleanUp = try self.databaseRepository.countEvents()
        XCTAssertEqual(countsEventsBeforeCleanUp, doubleLimit)

        let totalCountOfEventsAfterCleanUp = try self.databaseRepository.countEvents()
        XCTAssertLessThanOrEqual(totalCountOfEventsAfterCleanUp, databaseRepository.limit)
    }

    func testLifeTimeLimit() {
        XCTAssertNotNil(databaseRepository.lifeLimitDate)
        let event = eventGenerator.generateEvent()
        guard let monthLimitDate = databaseRepository.lifeLimitDate else {
            XCTFail("monthLimitDate could not be nil")
            return
        }
        XCTAssertGreaterThan(event.enqueueTimeStamp, monthLimitDate.timeIntervalSince1970)
    }

    func testRemoveDeprecatedEvents() throws {
        let event = eventGenerator.generateEvent()
        try databaseRepository.create(event: event)
        try databaseRepository.removeDeprecatedEventsIfNeeded()
    }

    func testDeprecatedEventsCount() throws {
        updateDatabaseRepositoryWith(createsDeprecated: true)
        let count = 5
        let events = eventGenerator.generateEvents(count: count)

        try events.forEach {
            try databaseRepository.create(event: $0)
        }

        let deprecatedEvents = try self.databaseRepository.countDeprecatedEvents()
        let totalEvents = try self.databaseRepository.countEvents()
        XCTAssertEqual(deprecatedEvents, totalEvents)
        XCTAssertEqual(deprecatedEvents, count)
    }

    func testDeprecatedEventsDelete() throws {
        updateDatabaseRepositoryWith(createsDeprecated: true)
        let count = 5
        let events = eventGenerator.generateEvents(count: count)

        try events.forEach {
            try databaseRepository.create(event: $0)
        }

        try self.databaseRepository.removeDeprecatedEventsIfNeeded()
        let deprecatedEvents = try self.databaseRepository.countDeprecatedEvents()
        XCTAssertEqual(deprecatedEvents, 0)
    }

    func testFetchUnretryEvents() throws {
        let count = 5
        var events = eventGenerator.generateEvents(count: count)

        try events.forEach {
            try databaseRepository.create(event: $0)
        }

        events = try self.databaseRepository.query(fetchLimit: count)
        XCTAssertFalse(events.isEmpty, "The events array should not be empty.")
        XCTAssertEqual(events.count, count)
    }

    func testFetchRetryEvents() throws {
        let count = 5
        let events = eventGenerator.generateEvents(count: count)
        let retriedEvent = events[count / 2]
        let retriedEvent2 = events[(count / 2) + 1]
        let eventsToRetry = [retriedEvent, retriedEvent2]

        try events.forEach {
            try databaseRepository.create(event: $0)
        }

        try events.forEach {
            let fetchedEvent = try databaseRepository.readEvent(by: $0.transactionId)
            XCTAssertEqual(fetchedEvent?.retryTimestamp, 0.0)
        }

        try eventsToRetry.forEach {
            try databaseRepository.update(event: $0)
        }

        try eventsToRetry.forEach {
            let fetchedEvent = try databaseRepository.readEvent(by: $0.transactionId)
            let retryTimestamp = try XCTUnwrap(fetchedEvent?.retryTimestamp)
            XCTAssertGreaterThan(retryTimestamp, 0.0)
        }

        let retryDeadline: TimeInterval = 2
        let retryExpectation = expectation(description: "RetryExpectation")

        let expectDeadline = retryDeadline + 1
        DispatchQueue.main.asyncAfter(deadline: .now() + expectDeadline) {
            do {
                let events = try self.databaseRepository.query(fetchLimit: count, retryDeadline: retryDeadline)
                XCTAssertFalse(events.isEmpty)
                XCTAssertEqual(events.count, count)
                XCTAssertEqual(retriedEvent.transactionId, events[events.count - 2].transactionId)
                XCTAssertEqual(retriedEvent2.transactionId, events[events.count - 1].transactionId)
                retryExpectation.fulfill()
            } catch {
                XCTFail(error.localizedDescription)
            }
        }
        waitForExpectations(timeout: expectDeadline + 2.0)
    }
}
