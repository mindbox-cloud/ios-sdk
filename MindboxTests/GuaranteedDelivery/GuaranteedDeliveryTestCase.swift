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

// swiftlint:disable force_try

class GuaranteedDeliveryTestCase: XCTestCase {

    var databaseRepository: DatabaseRepositoryProtocol!
    var guaranteedDeliveryManager: GuaranteedDeliveryManager!
    var persistenceStorage: PersistenceStorage!
    var eventGenerator: EventGenerator!
    var isDelivering: Bool!

    override func setUp() {
        super.setUp()
        Mindbox.logger.logLevel = .none

        databaseRepository = DI.injectOrFail(DatabaseRepositoryProtocol.self)
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
            databaseRepository: DI.injectOrFail(DatabaseRepositoryProtocol.self),
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

        XCTAssertEqual(event.serialNumber, mockEvent.serialNumber, "Serial numbers should be equal")
        XCTAssertEqual(event.body, mockEvent.body, "Bodies should be equal")
        XCTAssertEqual(event.type, mockEvent.type, "Types should be equal")
        XCTAssertEqual(event.isRetry, mockEvent.isRetry, "Flags `isRetry` should be equal")
        XCTAssertEqual(event.dateTimeOffset, mockEvent.dateTimeOffset, "Date time offsets should be equal")
        XCTAssertEqual(event.retryTimestamp, mockEvent.retryTimestamp, "Retry timestamps should be equal")
    }
    
    func testEventRetryTimestampLogic() {
        let type: Event.Operation = .installed
        let body = UUID().uuidString

        let event: EventProtocol = Event(type: type, body: body)
        let mockEvent: EventProtocol = MockEvent(type: type, body: body, retryTimestamp: Date().timeIntervalSince1970)
        
        XCTAssertFalse(event.isRetry, "If `retryTimestamp` is zero, `isRetry` must be false")
        XCTAssertTrue(mockEvent.isRetry, "if `retryTimestamp` is NOT zero, `isRetry` must be true")
    }
    
    func testDateTimeOffset_WhenNotRetry_isZero() {
        let event = Event(type: .installed, body: "foo")
        XCTAssertFalse(event.isRetry)
        XCTAssertEqual(event.dateTimeOffset, 0, "If `isRetry = false`, offset must be 0.")
    }
    
    func test_dateTimeOffset_WhenRetry_usingMockClock() {
        // 1) Set a fixed enqueueTimeStamp (for example, 1,000 seconds from the epoch)
        let fixedEnqueue: Double = 1_000
        
        // 2) Create a “dummy” current time using MockClock
        // let it be 1,000.500 seconds (i.e., +500 ms)
        let mockNow = Date(timeIntervalSince1970: 1_000.5)
        let clock = MockClock(now: mockNow)
        
        // 3) Creating an event as a retry
        let event = MockEvent(
            type: .installed,
            body: "baz",
            enqueueTimeStamp: fixedEnqueue,
            retryTimestamp: 100,
            clock: clock
        )
        
        // 4) The offset in ms will be (1,000.5 - 1,000) * 1,000 = 500 ms
        let offset = event.dateTimeOffset
        
        XCTAssertEqual(offset, 500,
                       "When enqueueTimeStamp=1000 and now=1000.5, it should be exactly 500 ms.")
    }

    func testScheduleByTimer() throws {
        let retryDeadline: TimeInterval = 2
        guaranteedDeliveryManager = GuaranteedDeliveryManager(
            persistenceStorage: DI.injectOrFail(PersistenceStorage.self),
            databaseRepository: DI.injectOrFail(DatabaseRepositoryProtocol.self),
            eventRepository: DI.injectOrFail(EventRepository.self),
            retryDeadline: retryDeadline
        )
        
        try databaseRepository.erase()
        let events = eventGenerator.generateEvents(count: 10)
        try events.forEach { try databaseRepository.create(event: $0) }
        
        let expectedStates: [GuaranteedDeliveryManager.State] = [.delivering, .idle]
        let expectations = expectedStates.map { expectation(description: "Expect state \($0.rawValue)") }
        var idx = 0
        
        var token: NSKeyValueObservation?
        token = guaranteedDeliveryManager.observe(\.stateObserver, options: [.new]) { mgr, change in
            guard
                idx < expectedStates.count,
                let raw = change.newValue as String?,
                let state = GuaranteedDeliveryManager.State(rawValue: raw),
                state == expectedStates[idx]
            else {
                XCTFail("New state is not expected type. ExpectedStates: \(expectedStates), index: \(idx). Received: \(String(describing: change.newValue))")
                return
            }
            expectations[idx].fulfill()
            idx += 1
            
            // As soon as we “catch” idle, we suppress further cycles
            if idx == expectedStates.count {
                mgr.canScheduleOperations = false
                token?.invalidate()
                token = nil
            }
        }
        
        guaranteedDeliveryManager.canScheduleOperations = true
        waitForExpectations(timeout: 30)
    }

    func testFailureAndRetryScheduleByTimer() throws {
        // 1) Setup: first delivery attempt fails, then all subsequent attempts succeed
        let fetcher = MockFailureNetworkFetcher()
        let fakeDB  = FakeDatabaseRepository()
        let eventRepo = MBEventRepository(
            fetcher: fetcher,
            persistenceStorage: DI.injectOrFail(PersistenceStorage.self)
        )
        let manager = GuaranteedDeliveryManager(
            persistenceStorage: DI.injectOrFail(PersistenceStorage.self),
            databaseRepository: fakeDB,
            eventRepository: eventRepo,
            retryDeadline: 2 // Short deadline so that the retry cycle happens within the test
        )

        // 2) Populate fakeDB with 10 events
        try fakeDB.erase()
        let events = eventGenerator.generateEvents(count: 10)
        try events.forEach { try fakeDB.create(event: $0) }

        // 3) Record state transitions without enforcing an exact order
        var seenStates = [GuaranteedDeliveryManager.State]()
        var deliveringCount = 0
        var didSeeWaitingForRetry = false

        let expectation = expectation(
            description: "Manager delivers, waits for retry, delivers again and returns to idle"
        )

        var token: NSKeyValueObservation?
        token = manager.observe(\.stateObserver, options: [.new]) { mgr, change in
            guard
                let raw = change.newValue as String?,
                let state = GuaranteedDeliveryManager.State(rawValue: raw)
            else {
                return
            }

            seenStates.append(state)

            switch state {
            case .delivering:
                deliveringCount += 1

            case .waitingForRetry:
                didSeeWaitingForRetry = true

            case .idle:
                // Success condition: at least two `.delivering` states and a `.waitingForRetry` in between
                if deliveringCount >= 2 && didSeeWaitingForRetry {
                    mgr.canScheduleOperations = false
                    token?.invalidate()
                    token = nil
                    expectation.fulfill()
                }
            }
        }

        // 4) Start scheduling and wait until our condition is met
        manager.canScheduleOperations = true
        wait(for: [expectation], timeout: 60)

        // 5) Final assertions: we only check aggregated behavior, not an exact state sequence
        XCTAssertGreaterThanOrEqual(
            deliveringCount,
            2,
            "Expected at least two `.delivering` states, but saw: \(seenStates)"
        )

        XCTAssertTrue(
            didSeeWaitingForRetry,
            "Expected to observe `.waitingForRetry` state, but saw: \(seenStates)"
        )

        XCTAssertEqual(
            seenStates.last,
            .idle,
            "Expected final state to be `.idle`, but saw: \(seenStates)"
        )
    }
}
