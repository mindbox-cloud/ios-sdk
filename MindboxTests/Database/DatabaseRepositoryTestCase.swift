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
    
    var databaseRepository: MBDatabaseRepository {
        container.databaseRepository
    }
    
    let eventGenerator = EventGenerator()
        
    let container = try! TestDependencyProvider()

    override func setUp() {
        try! databaseRepository.erase()
        updateDatabaseRepositoryWith(createsDeprecated: false)
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    private func updateDatabaseRepositoryWith(createsDeprecated: Bool) {
        (databaseRepository as! MockDatabaseRepository).createsDeprecated = createsDeprecated
    }
    
    func testCreateDatabaseRepository() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        XCTAssertNotNil(databaseRepository)
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
    
    // MARK: - Not valid with ci/cd
//    func testCreateEvents() {
//        let count = 1000
//        let events = eventGenerator.generateEvents(count: count)
//        let expectation = self.expectation(description: "create \(count) events")
//        let createEventsDate = Date()
//        do {
//            try events.forEach {
//                try databaseRepository.create(event: $0)
//            }
//            let createdEventsDate = Date()
//            let delta = createdEventsDate.timeIntervalSince1970 - createEventsDate.timeIntervalSince1970
//            XCTAssertTrue(delta < 30)
//            expectation.fulfill()
//        } catch {
//            XCTFail(error.localizedDescription)
//        }
//        waitForExpectations(timeout: 1, handler: nil)
//    }
    
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
        var initailRetryTimeStamp: Double?
        var updatedRetryTimeStamp: Double?
        do {
            try databaseRepository.create(event: event)
        } catch {
            XCTFail(error.localizedDescription)
        }
        do {
            let entity = try databaseRepository.read(by: event.transactionId)
            initailRetryTimeStamp = entity?.retryTimestamp
            XCTAssertNotNil(initailRetryTimeStamp)
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
            XCTAssertNotNil(initailRetryTimeStamp)
            updatedRetryTimeStamp = entity?.retryTimestamp
        } catch {
            XCTFail(error.localizedDescription)
        }
        XCTAssertNotEqual(initailRetryTimeStamp, updatedRetryTimeStamp)
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
    
//    func testHasEventsAfterCreation() {
//        databaseRepository.onObjectsDidChange = { [self] in
//            XCTAssertTrue(databaseRepository.count > 0)
//        }
//        testCreateEvent()
//    }
//
//    func testLimitCount() {
//        try! databaseRepository.erase()
//        let events = eventGenerator.generateEvents(count: databaseRepository.limit)
//        do {
//            try events.forEach {
//                try databaseRepository.create(event: $0)
//            }
//        } catch {
//            XCTFail(error.localizedDescription)
//        }
//        XCTAssertTrue(databaseRepository.count <= databaseRepository.limit)
//    }
    
    func testLifeTimeLimit() {
        XCTAssertNotNil(databaseRepository.lifeLimitDate)
        let event = eventGenerator.generateEvent()
        guard let monthLimitDate = databaseRepository.lifeLimitDate else {
            XCTFail("monthLimitDate could not be nil")
            return
        }
        XCTAssertTrue(event.enqueueTimeStamp > monthLimitDate.timeIntervalSince1970)
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
    
//    func testDeprecatedEventsCount() {
//        updateDatabaseRepositoryWith(createsDeprecated: true)
//        let count = 5
//        let events = eventGenerator.generateEvents(count: count)
//        let depracatedExpectation = expectation(description: "Deprecated events are current count")
//        do {
//            try events.forEach {
//                try databaseRepository.create(event: $0)
//            }
//        } catch {
//            XCTFail(error.localizedDescription)
//        }
//        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//            do {
//                let deprecatedEvents = try self.databaseRepository.countDeprecatedEvents()
//                let totalEvents = try self.databaseRepository.countEvents()
//                XCTAssertFalse(deprecatedEvents == totalEvents)
//                XCTAssertTrue(deprecatedEvents == count)
//                depracatedExpectation.fulfill()
//            } catch {
//                XCTFail(error.localizedDescription)
//            }
//        }
//
//        waitForExpectations(timeout: 1)
//    }
    
    func testDeprecatedEventsDelete() {
        updateDatabaseRepositoryWith(createsDeprecated: true)
        let count = 5
        let events = eventGenerator.generateEvents(count: count)
        let depracatedExpectation = expectation(description: "Deprecated events are zero after remove")
        do {
            try events.forEach {
                try databaseRepository.create(event: $0)
            }
        } catch {
            XCTFail(error.localizedDescription)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            do {
                try self.databaseRepository.removeDeprecatedEventsIfNeeded()
                let deprecatedEvents = try self.databaseRepository.countDeprecatedEvents()
                XCTAssertTrue(deprecatedEvents == 0)
                depracatedExpectation.fulfill()
            } catch {
                XCTFail(error.localizedDescription)
            }
        }
        
        waitForExpectations(timeout: 1)
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
            XCTAssertFalse(events.isEmpty)
            XCTAssertTrue(events.count == count)
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
