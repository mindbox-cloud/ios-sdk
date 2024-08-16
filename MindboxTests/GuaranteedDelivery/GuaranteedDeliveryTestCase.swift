//
//  GuaranteedDeliveryTestCase.swift
//  MindboxTests
//
//  Created by Maksim Kazachkov on 08.02.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import CoreData
@testable import Mindbox
import XCTest

class GuaranteedDeliveryTestCase: XCTestCase {
    
    var databaseRepository: MBDatabaseRepository!
    var guaranteedDeliveryManager: GuaranteedDeliveryManager!
    var persistenceStorage: PersistenceStorage!
    var eventGenerator: EventGenerator!
    var isDelivering: Bool!

    override func setUp() {
        super.setUp()
        Mindbox.logger.logLevel = .none
        
        databaseRepository = DI.injectOrFail(MBDatabaseRepository.self)
        guaranteedDeliveryManager = DI.injectOrFail(GuaranteedDeliveryManager.self)
        persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
        eventGenerator = EventGenerator()
        isDelivering = guaranteedDeliveryManager.state.isDelivering
        
        let configuration = try! MBConfiguration(plistName: "TestEventConfig")
        persistenceStorage.configuration = configuration
        persistenceStorage.configuration?.previousDeviceUUID = configuration.previousDeviceUUID
        persistenceStorage.deviceUUID = "0593B5CC-1479-4E45-A7D3-F0E8F9B40898"
        try! databaseRepository.erase()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        databaseRepository = nil
        guaranteedDeliveryManager = nil
        persistenceStorage = nil
        eventGenerator = nil
        isDelivering = nil
        super.tearDown()
    }

    func testDeliverMultipleEvents() {
        let retryDeadline: TimeInterval = 3
        guaranteedDeliveryManager = GuaranteedDeliveryManager(
            persistenceStorage: DI.injectOrFail(PersistenceStorage.self),
            databaseRepository: DI.injectOrFail(MBDatabaseRepository.self),
            eventRepository: DI.injectOrFail(EventRepository.self),
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
    
    func testEventEqualsMockEvent() {
        let type: Event.Operation = .installed
        let body = UUID().uuidString
        
        let event: EventProtocol = Event(type: type, body: body)
        let mockEvent: EventProtocol = MockEvent(type: type, body: body)
        
        XCTAssertEqual(!event.transactionId.isEmpty, !mockEvent.transactionId.isEmpty, "Transaction Ids should not be empty")
        XCTAssertEqual(event.enqueueTimeStamp, mockEvent.enqueueTimeStamp, accuracy: 0.001, "Enqueue timestamps should match with some accuracy")
        
        XCTAssertEqual(event.serialNumber, mockEvent.serialNumber, "Serial numbers should be equal")
        XCTAssertEqual(event.body, mockEvent.body, "Bodies should be equal")
        XCTAssertEqual(event.type, mockEvent.type, "Types should be equal")
        XCTAssertEqual(event.isRetry, mockEvent.isRetry, "Flags `isRetry` should be equal")
        XCTAssertEqual(event.dateTimeOffset, mockEvent.dateTimeOffset, "Date time offsets should be equal")
    }

    func testDateTimeOffset() {
        let events = eventGenerator.generateMockEvents(count: 100)
        events.forEach { event in
            let enqueueDate = Date(timeIntervalSince1970: event.enqueueTimeStamp)
            let expectation = Int64((Date().timeIntervalSince(enqueueDate) * 1000).rounded())
            let dateTimeOffset = event.dateTimeOffset
            XCTAssertEqual(dateTimeOffset, expectation, "dateTimeOffset should be equal")
        }
    }

    func testScheduleByTimer() {
        // Может понадобиться MockFailureNetworkFetcher (Check later)
        let retryDeadline: TimeInterval = 2
        guaranteedDeliveryManager = GuaranteedDeliveryManager(
            persistenceStorage: DI.injectOrFail(PersistenceStorage.self),
            databaseRepository: DI.injectOrFail(MBDatabaseRepository.self),
            eventRepository: DI.injectOrFail(EventRepository.self),
            retryDeadline: retryDeadline
        )
        let simpleCase: [GuaranteedDeliveryManager.State] = [.delivering, .idle]
        let simpleExpectations: [XCTestExpectation] = simpleCase.map { self.expectation(description: "Expect state is \($0.rawValue)") }

        var iterator: Int = 0
        // Full erase database
        try! databaseRepository.erase()
        // Lock update
        guaranteedDeliveryManager.canScheduleOperations = false
        var observationToken: NSKeyValueObservation? = guaranteedDeliveryManager.observe(\.stateObserver, options: [.new]) { _, change in
            guard let newState = GuaranteedDeliveryManager.State(rawValue: String(change.newValue ?? "")),
                  simpleCase.indices.contains(iterator) else {
                XCTFail("New state is not expected type. SimpleCase:\(simpleCase) Iterator:\(iterator); Received: \(String(describing: change.newValue))")
                return
            }
            if newState == simpleCase[iterator] {
                simpleExpectations[iterator].fulfill()
            }
            iterator += 1
        }
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
        waitForExpectations(timeout: 15) { _ in
            observationToken?.invalidate()
            observationToken = nil
        }
    }

    func testFailureScheduleByTimer() {
        let retryDeadline: TimeInterval = 2
        guaranteedDeliveryManager = GuaranteedDeliveryManager(
            persistenceStorage: DI.injectOrFail(PersistenceStorage.self),
            databaseRepository: DI.injectOrFail(MBDatabaseRepository.self),
            eventRepository: DI.injectOrFail(EventRepository.self),
            retryDeadline: retryDeadline
        )
        let errorCase: [GuaranteedDeliveryManager.State] = [
            .delivering,
            .idle
        ]
        let errorExpectations: [XCTestExpectation] = errorCase.map { self.expectation(description: "Expect state is \($0.rawValue)") }
        var iterator: Int = 0
        // Full erase database
        try! databaseRepository.erase()
        // Lock update
        guaranteedDeliveryManager.canScheduleOperations = false

        var observationToken: NSKeyValueObservation? = guaranteedDeliveryManager.observe(\.stateObserver, options: [.new]) { _, change in
            guard let newState = GuaranteedDeliveryManager.State(rawValue: String(change.newValue ?? "")),
                  errorCase.indices.contains(iterator) else {
                XCTFail("New state is not expected type. ErrorCase:\(errorCase) Iterator:\(iterator); Received: \(String(describing: change.newValue))")
                return
            }
            
            if newState == errorCase[iterator] {
                errorExpectations[iterator].fulfill()
            }
            iterator += 1
        }
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
        waitForExpectations(timeout: 15) { _ in
            observationToken?.invalidate()
            observationToken = nil
        }
    }
}
