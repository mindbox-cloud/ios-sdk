//
//  GuaranteedDeliveryTestCase.swift
//  MindboxTests
//
//  Created by Maksim Kazachkov on 08.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import XCTest
import CoreData
@testable import Mindbox

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
    
    var container = try! TestDependencyProvider()
    
    private var observationToken: NSKeyValueObservation?
    
    override func setUp() {
        guaranteedDeliveryManager = container.guaranteedDeliveryManager
        let configuration = try! MBConfiguration(plistName: "TestEventConfig")
        persistenceStorage.configuration = configuration
        persistenceStorage.configuration?.deviceUUID = configuration.deviceUUID
        persistenceStorage.deviceUUID = "0593B5CC-1479-4E45-A7D3-F0E8F9B40898"
        try! databaseRepository.erase()
        updateInstanceFactory(withFailureNetworkFetcher: false)
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    private func updateInstanceFactory(withFailureNetworkFetcher: Bool) {
        (container.instanceFactory as! MockInstanceFactory).isFailureNetworkFetcher = withFailureNetworkFetcher
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
    
    func testDateTimeOffset() {
        let events = eventGenerator.generateEvents(count: 100)
        events.forEach { (event) in
            let enqueueDate = Date(timeIntervalSince1970: event.enqueueTimeStamp)
            let expectation = Int64((Date().timeIntervalSince(enqueueDate) * 1000).rounded())
            let dateTimeOffset = event.dateTimeOffset
            XCTAssertTrue(expectation == dateTimeOffset)
        }
    }
    
    func testScheduleByTimer() {
        let simpleCase: [GuaranteedDeliveryManager.State] = [.delivering, .idle]
        let simpleExpectations: [XCTestExpectation] = simpleCase
            .map {
                keyValueObservingExpectation(
                    for: guaranteedDeliveryManager!,
                    keyPath: state as String,
                    expectedValue: $0.rawValue
                )
            }
        var iterator: Int = 0
        do {
            try databaseRepository.erase()
        } catch {
            XCTFail(error.localizedDescription)
        }
        let retryDeadline: TimeInterval = 2
        guaranteedDeliveryManager = GuaranteedDeliveryManager(
            persistenceStorage: container.persistenceStorage,
            databaseRepository: container.databaseRepository,
            eventRepository: container.instanceFactory.makeEventRepository(),
            retryDeadline: retryDeadline
        )
        observationToken = guaranteedDeliveryManager.observe(\.stateObserver, options: [.new]) { _, change in
            guard let newState = GuaranteedDeliveryManager.State(rawValue: String(change.newValue ?? "")),
                  simpleCase.indices.contains(iterator) else {
                XCTFail("New state is not expected type")
                return
            }
            if newState == simpleCase[iterator] {
                simpleExpectations[iterator].fulfill()
            }
            iterator += 1
        }
        // Lock update
        guaranteedDeliveryManager.canScheduleOperations = false
        // Generating new events
        let events = eventGenerator.generateEvents(count: 10)
        do {
            try events.forEach {
                // Create new event in database
                try databaseRepository.create(event: $0)
            }
        } catch {
            XCTFail(error.localizedDescription)
        }
        // Start update
        guaranteedDeliveryManager.canScheduleOperations = true
        waitForExpectations(timeout: retryDeadline)
    }
    
    func testFailureScheduleByTimer() {
        updateInstanceFactory(withFailureNetworkFetcher: true)
        let errorCase: [GuaranteedDeliveryManager.State] = [
            .delivering,
            .idle,
            .delivering,
            .waitingForRetry,
            .delivering,
            .idle
        ]
        let errorExpectations: [XCTestExpectation] = errorCase
            .map {
                keyValueObservingExpectation(
                    for: guaranteedDeliveryManager!,
                    keyPath: state as String,
                    expectedValue: $0.rawValue
                )
            }
        var iterator: Int = 0
        // Full erase database
        try! databaseRepository.erase()
        let retryDeadline: TimeInterval = 2
        guaranteedDeliveryManager = GuaranteedDeliveryManager(
            persistenceStorage: container.persistenceStorage,
            databaseRepository: container.databaseRepository,
            eventRepository: container.instanceFactory.makeEventRepository(),
            retryDeadline: retryDeadline
        )
        observationToken = guaranteedDeliveryManager.observe(\.stateObserver, options: [.new]) { _, change in
            guard let newState = GuaranteedDeliveryManager.State(rawValue: String(change.newValue ?? "")),
                  errorCase.indices.contains(iterator) else {
                XCTFail("New state is not expected type")
                return
            }
            if newState == errorCase[iterator] {
                errorExpectations[iterator].fulfill()
            }
            iterator += 1
        }
        // Lock update
        guaranteedDeliveryManager.canScheduleOperations = false
        // Generating new events
        let events = eventGenerator.generateEvents(count: 10)
        do {
            try events.forEach {
                // Create new event in database
                try databaseRepository.create(event: $0)
            }
        } catch {
            XCTFail(error.localizedDescription)
        }
        // Start update
        guaranteedDeliveryManager.canScheduleOperations = true
        waitForExpectations(timeout: retryDeadline + 1)
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
