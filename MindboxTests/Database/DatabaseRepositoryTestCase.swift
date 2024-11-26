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

// swiftlint:disable force_try force_cast

class DatabaseRepositoryTestCase: XCTestCase {

    var databaseRepository: MBDatabaseRepository!
    var eventGenerator: EventGenerator!

    override func setUp() {
        super.setUp()
        databaseRepository = DI.injectOrFail(MBDatabaseRepository.self)
        eventGenerator = EventGenerator()

        try! databaseRepository.erase()
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

    func testCreateEvent() {
        let event = eventGenerator.generateEvent()
        let expectation = self.expectation(description: "create event")
        do {
            try databaseRepository.create(event: event)
            expectation.fulfill()
        } catch {
            XCTFail(error.localizedDescription)
        }
        waitForExpectations(timeout: 1, handler: nil)
    }

    func testReadEvent() {
        let event = eventGenerator.generateEvent()
        let expectation = self.expectation(description: "read event")
        do {
            try databaseRepository.create(event: event)
        } catch {
            XCTFail(error.localizedDescription)
        }
        do {
            let entity = try databaseRepository.read(by: event.transactionId)
            XCTAssertNotNil(entity)
            expectation.fulfill()
        } catch {
            XCTFail(error.localizedDescription)
        }

        waitForExpectations(timeout: 4, handler: nil)
    }

    func testUpdateEvent() {
        let event = eventGenerator.generateEvent()
        var initialRetryTimeStamp: Double?
        var updatedRetryTimeStamp: Double?
        do {
            try databaseRepository.create(event: event)
        } catch {
            XCTFail(error.localizedDescription)
        }
        do {
            let entity = try databaseRepository.read(by: event.transactionId)
            initialRetryTimeStamp = entity?.retryTimestamp
            XCTAssertNotNil(initialRetryTimeStamp)
        } catch {
            XCTFail(error.localizedDescription)
        }
        do {
            try databaseRepository.update(event: event)
        } catch {
            XCTFail(error.localizedDescription)
        }
        do {
            let entity = try databaseRepository.read(by: event.transactionId)
            XCTAssertNotNil(initialRetryTimeStamp)
            updatedRetryTimeStamp = entity?.retryTimestamp
        } catch {
            XCTFail(error.localizedDescription)
        }
        XCTAssertNotEqual(initialRetryTimeStamp, updatedRetryTimeStamp)
    }

    func testDeleteEvent() {
        let event = eventGenerator.generateEvent()
        do {
            try databaseRepository.create(event: event)
        } catch {
            XCTFail(error.localizedDescription)
        }
        let expectation = self.expectation(description: "delete event")
        do {
            try databaseRepository.delete(event: event)
            expectation.fulfill()
        } catch {
            XCTFail(error.localizedDescription)
        }
        waitForExpectations(timeout: 1, handler: nil)
    }

    func testHasEventsAfterCreation() {
        databaseRepository.onObjectsDidChange = { [self] in
            do {
                let totalEvents = try self.databaseRepository.countEvents()
                XCTAssertGreaterThan(totalEvents, 0)
            } catch {
                XCTFail(error.localizedDescription)
            }
        }
        testCreateEvent()
    }

    func testCleanUpWhenTryingToCountEventsWhenExceedingTheLimit() {
        try! databaseRepository.erase()

        let temporaryLimit = 3
        (databaseRepository as! MockDatabaseRepository).tempLimit = temporaryLimit
        XCTAssertEqual(databaseRepository.limit, temporaryLimit)

        let doubleLimit = databaseRepository.limit * 2
        let events = eventGenerator.generateEvents(count: doubleLimit)

        do {
            try events.forEach {
                try databaseRepository.create(event: $0)
            }
        } catch {
            XCTFail(error.localizedDescription)
        }

        do {
            let countsEventsBeforeCleanUp = try self.databaseRepository.countEvents()
            XCTAssertEqual(countsEventsBeforeCleanUp, doubleLimit)

            let totalCountOfEventsAfterCleanUp = try self.databaseRepository.countEvents()
            XCTAssertLessThanOrEqual(totalCountOfEventsAfterCleanUp, databaseRepository.limit)
        } catch {
            XCTFail(error.localizedDescription)
        }
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

    func testRemoveDeprecatedEvents() {
        let event = eventGenerator.generateEvent()
        do {
            try databaseRepository.create(event: event)
        } catch {
            XCTFail(error.localizedDescription)
        }
        do {
            try databaseRepository.removeDeprecatedEventsIfNeeded()
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testDeprecatedEventsCount() {
        updateDatabaseRepositoryWith(createsDeprecated: true)
        let count = 5
        let events = eventGenerator.generateEvents(count: count)
        let deprecatedExpectation = expectation(description: "Deprecated events are current count")
        do {
            try events.forEach {
                try databaseRepository.create(event: $0)
            }
        } catch {
            XCTFail(error.localizedDescription)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
            do {
                let deprecatedEvents = try self.databaseRepository.countDeprecatedEvents()
                let totalEvents = try self.databaseRepository.countEvents()
                XCTAssertEqual(deprecatedEvents, totalEvents)
                XCTAssertEqual(deprecatedEvents, count)
                deprecatedExpectation.fulfill()
            } catch {
                XCTFail(error.localizedDescription)
            }
        }

        waitForExpectations(timeout: 2)
    }

    func testDeprecatedEventsDelete() {
        updateDatabaseRepositoryWith(createsDeprecated: true)
        let count = 5
        let events = eventGenerator.generateEvents(count: count)
        let deprecatedExpectation = expectation(description: "Deprecated events are zero after remove")
        do {
            try events.forEach {
                try databaseRepository.create(event: $0)
            }
        } catch {
            XCTFail(error.localizedDescription)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
            do {
                try self.databaseRepository.removeDeprecatedEventsIfNeeded()
                let deprecatedEvents = try self.databaseRepository.countDeprecatedEvents()
                XCTAssertEqual(deprecatedEvents, 0)
                deprecatedExpectation.fulfill()
            } catch {
                XCTFail(error.localizedDescription)
            }
        }

        waitForExpectations(timeout: 2)
    }

    func testFetchUnretryEvents() {
        let count = 5
        let events = eventGenerator.generateEvents(count: count)
        do {
            try events.forEach {
                try databaseRepository.create(event: $0)
            }
        } catch {
            XCTFail(error.localizedDescription)
        }
        do {
            let events = try self.databaseRepository.query(fetchLimit: count)
            XCTAssertFalse(events.isEmpty, "The events array should not be empty.")
            XCTAssertEqual(events.count, count)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testFetchRetryEvents() {
        let count = 5
        let events = eventGenerator.generateEvents(count: count)
        let retriedEvent = events[count / 2]
        let retriedEvent2 = events[(count / 2) + 1]
        let eventsToRetry = [retriedEvent, retriedEvent2]
        do {
            try events.forEach {
                try databaseRepository.create(event: $0)
            }
        } catch {
            XCTFail(error.localizedDescription)
        }
        do {
            try eventsToRetry.forEach {
                try databaseRepository.update(event: $0)
            }
        } catch {
            XCTFail(error.localizedDescription)
        }
        let retryDeadline: TimeInterval = 4
        let expectDeadline = retryDeadline + 2
        let retryExpectation = expectation(description: "RetryExpectation")
        DispatchQueue.main.asyncAfter(deadline: .now() + expectDeadline) {
            do {
                let events = try self.databaseRepository.query(fetchLimit: count, retryDeadline: retryDeadline)
                XCTAssertFalse(events.isEmpty)
                XCTAssertTrue(retriedEvent.transactionId == events[events.count - 2].transactionId)
                XCTAssertTrue(retriedEvent2.transactionId == events[events.count - 1].transactionId)
                retryExpectation.fulfill()
            } catch {
                XCTFail(error.localizedDescription)
            }
        }
        waitForExpectations(timeout: retryDeadline + 2.0)
    }
}
