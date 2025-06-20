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
        XCTAssertEqual(event.enqueueTimeStamp, mockEvent.enqueueTimeStamp, accuracy: 0.02, "Enqueue timestamps should match with some accuracy")

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
            XCTAssertEqual(dateTimeOffset, expectation, accuracy: 20, "dateTimeOffset should be equal with some accuracy")
        }
    }

    func testScheduleByTimer() throws {
        let retryDeadline: TimeInterval = 2
        guaranteedDeliveryManager = GuaranteedDeliveryManager(
            persistenceStorage: DI.injectOrFail(PersistenceStorage.self),
            databaseRepository: DI.injectOrFail(MBDatabaseRepository.self),
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
        let retryDeadline: TimeInterval = 2
        
        let fakeDB = FakeDatabaseRepository()
        let fetcher = MockFailureNetworkFetcher()
        let eventRepo = MBEventRepository(fetcher: fetcher,
                                          persistenceStorage: DI.injectOrFail(PersistenceStorage.self))
        
        let manager = GuaranteedDeliveryManager(
            persistenceStorage: DI.injectOrFail(PersistenceStorage.self),
            databaseRepository: fakeDB,
            eventRepository: eventRepo,
            retryDeadline: retryDeadline
        )
        
        try fakeDB.erase()
        let events = eventGenerator.generateEvents(count: 10)
        try events.forEach { try fakeDB.create(event: $0) }
        
        var seenStates = [GuaranteedDeliveryManager.State]()
        
        let token = manager.observe(\.stateObserver, options: [.new]) { _, change in
            if let raw = change.newValue as String?,
               let state = GuaranteedDeliveryManager.State(rawValue: raw) {
                seenStates.append(state)
            }
        }
        
        // Wait until it falls into .idle and FakeDB becomes empty
        let done = XCTNSPredicateExpectation(
            predicate: NSPredicate { eval, _ in
                guard let m = eval as? GuaranteedDeliveryManager else { return false }
                return m.state == .idle && (try? fakeDB.countEvents()) == 0
            },
            object: manager
        )
        
        manager.canScheduleOperations = true
        wait(for: [done], timeout: 30)
        token.invalidate()
        
        // Check full order
        // delivering → idle → delivering → waitingForRetry → delivering → idle
        func idx(of s: GuaranteedDeliveryManager.State, after i: Int = 0) -> Int? {
            return seenStates.dropFirst(i).firstIndex(of: s)
        }
        
        guard let d1 = idx(of: .delivering),
              let i1 = idx(of: .idle,            after: d1),
              let d2 = idx(of: .delivering,      after: i1),
              let w  = idx(of: .waitingForRetry, after: d2),
              let d3 = idx(of: .delivering,      after: w),
              let i2 = idx(of: .idle,            after: d3)
        else {
            return XCTFail("Expected order [delivering, idle, delivering, waitingForRetry, delivering, idle], but got  \(seenStates)")
        }
        
        XCTAssertTrue(d1 < i1 && i1 < d2 && d2 < w && w < d3 && d3 < i2,
                      "The order of states is incorrect: \(seenStates)")
    }
}
