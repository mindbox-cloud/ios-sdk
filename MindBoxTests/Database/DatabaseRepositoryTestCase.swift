//
//  CreateDatabaseRepositoryTestCase.swift
//  MindBoxTests
//
//  Created by Maksim Kazachkov on 05.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import XCTest
import CoreData
@testable import MindBox

class DatabaseRepositoryTestCase: XCTestCase {
    
    var databaseRepository: MockDatabaseRepository!
    
    let eventGenerator = EventGenerator()
    
    override func setUp() {
        DIManager.shared.dropContainer()
        DIManager.shared.registerServices()
        if databaseRepository == nil {
            databaseRepository = try! MockDatabaseRepository()
        }
        // Put setup code here. This method is called before the invocation of each test method in the class.
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
    
    func testCreateEvents() {
        let count = 100
        let events = eventGenerator.generateEvents(count: count)
        let expectation = self.expectation(description: "create \(count) events")
        do {
            try events.forEach {
                try databaseRepository.create(event: $0)
            }
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
    
    func testHasEvents() {
        databaseRepository.onObjectsDidChange = { [self] in
            XCTAssertTrue(databaseRepository.count > 0)
        }
        testCreateEvents()
    }
    
    func testLimitCount() {
        let events = eventGenerator.generateEvents(count: 2*databaseRepository.countLimit)
        do {
            try events.forEach {
                try databaseRepository.create(event: $0)
            }
        } catch {
            XCTFail(error.localizedDescription)
        }
        XCTAssertTrue(databaseRepository.count <= databaseRepository.countLimit)
    }
    
    func testMonthLimitDate() {
        XCTAssertNotNil(CDEvent.monthLimitDate)
    }
    
    func testLifeTimeLimit() {
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
    
}
