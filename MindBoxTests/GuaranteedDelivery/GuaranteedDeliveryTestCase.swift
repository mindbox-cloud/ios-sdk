//
//  GuaranteedDeliveryTestCase.swift
//  MindBoxTests
//
//  Created by Maksim Kazachkov on 08.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import XCTest
import CoreData
@testable import MindBox

class GuaranteedDeliveryTestCase: XCTestCase {
    
    var databaseRepository: MBDatabaseRepository {
        container.databaseRepository
    }
    var guaranteedDeliveryManager: GuaranteedDeliveryManager!
    
    var persistenceStorage: PersistenceStorage {
        container.persistenceStorage
    }
    
    let eventGenerator = EventGenerator()
    
    var isDelivering: Bool {
        guaranteedDeliveryManager.state.isDelivering
    }
    
    var container: DependencyContainer!
    
    override func setUp() {
        container = try! TestDependencyProvider()
        guaranteedDeliveryManager = container.guaranteedDeliveryManager
        let configuration = try! MBConfiguration(plistName: "TestEventConfig")
        persistenceStorage.configuration = configuration
        persistenceStorage.configuration?.deviceUUID = configuration.deviceUUID
        persistenceStorage.deviceUUID = "0593B5CC-1479-4E45-A7D3-F0E8F9B40898"
        try! databaseRepository.erase()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    func testIsDelivering() {
        let event = eventGenerator.generateEvent()
        do {
            try databaseRepository.create(event: event)
        } catch {
            XCTFail(error.localizedDescription)
        }
        let exists = NSPredicate(format: "isDelivering == false")
        expectation(for: exists, evaluatedWith: self, handler: nil)
        waitForExpectations(timeout: 60, handler: nil)
    }
    
    func testDeliverMultipleEvents() {
        let retryDeadline: TimeInterval = 3
        guaranteedDeliveryManager = GuaranteedDeliveryManager(
            persistenceStorage: container.persistenceStorage,
            databaseRepository: container.databaseRepository,
            eventRepository: container.instanceFactory.makeEventRepository(),
            retryDeadline: retryDeadline
        )
        let events = eventGenerator.generateEvents(count: 10)
        events.forEach {
            do {
                try databaseRepository.create(event: $0)
            } catch {
                XCTFail(error.localizedDescription)
            }
        }
        let deliveringExpectation = NSPredicate(format: "%K == %@", argumentArray: [#keyPath(state), GuaranteedDeliveryManager.State.idle.rawValue])
        expectation(for: deliveringExpectation, evaluatedWith: self, handler: nil)
        waitForExpectations(timeout: 20, handler: nil)
    }
    
    var state: NSString {
        NSString(string: guaranteedDeliveryManager.state.rawValue)
    }
    
    func testScheduleByTimer() {
        let retryDeadline: TimeInterval = 3
        guaranteedDeliveryManager = GuaranteedDeliveryManager(
            persistenceStorage: container.persistenceStorage,
            databaseRepository: container.databaseRepository,
            eventRepository: container.instanceFactory.makeEventRepository(),
            retryDeadline: retryDeadline
        )
        guaranteedDeliveryManager.canScheduleOperations = false
        let count = 2
        let events = eventGenerator.generateEvents(count: count)
        do {
            try events.forEach {
                try databaseRepository.create(event: $0)
            }
        } catch {
            XCTFail(error.localizedDescription)
        }
        do {
            try events.forEach {
                try databaseRepository.update(event: $0)
            }
            guaranteedDeliveryManager.canScheduleOperations = true
        } catch {
            XCTFail(error.localizedDescription)
        }
        let expectDeadline = 2 * retryDeadline
        let retryExpectation = NSPredicate(format: "%K == %@", argumentArray: [#keyPath(state), GuaranteedDeliveryManager.State.idle.rawValue])
        expectation(for: retryExpectation, evaluatedWith: self, handler: nil)
        waitForExpectations(timeout: expectDeadline)
    }
    
    func testDateTimeOffset() {
        let events = eventGenerator.generateEvents(count: 100)
        events.forEach { (event) in
            let enqueueDate = Date(timeIntervalSince1970: event.enqueueTimeStamp)
            let expectation = Int64((Date().timeIntervalSince(enqueueDate) * 1000).rounded())
            let dateTimeOffset = event.dateTimeOffset
            XCTAssertTrue(expectation == dateTimeOffset)
        }
    }
    
    private func generateAndSaveToDatabaseEvents() {
        let event = eventGenerator.generateEvent()
        do {
            try databaseRepository.create(event: event)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
}
