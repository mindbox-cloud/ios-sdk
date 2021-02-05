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
        let event = generateEvent()
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
        let count = 50
        let events = generateEvents(count: count)
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
        let event = generateEvent()
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
        let event = generateEvent()
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
        let event = generateEvent()
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
        NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextObjectsDidChange,
            object: databaseRepository.context,
            queue: nil) { (notification) in
            guard let context = notification.object as? NSManagedObjectContext else {
                return
            }
            XCTAssertTrue(context.insertedObjects.count > 0)
        }
        testCreateEvents()
    }
    
    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
        }
    }
    
    private func randomString(length: Int = 10) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map{ _ in letters.randomElement()! })
    }
    
    private func generateEvent() -> Event {
        Event(
            transactionId: UUID().uuidString,
            enqueueTimeStamp: Date().timeIntervalSince1970,
            type: .installed,
            body: randomString()
        )
    }
    
    private func generateEvents(count: Int) -> [Event] {
        return (0...count).map { _ in
            Event(
                transactionId: UUID().uuidString,
                enqueueTimeStamp: Date().timeIntervalSince1970,
                type: .installed,
                body: randomString()
            )
        }
    }
    
}
