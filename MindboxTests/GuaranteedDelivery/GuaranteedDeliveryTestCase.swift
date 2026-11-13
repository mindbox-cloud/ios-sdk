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
        let fixedEnqueue: Double = 1_000
        
        let mockNow = Date(timeIntervalSince1970: 1_000.5)
        let clock = MockClock(now: mockNow)
        
        let event = MockEvent(
            type: .installed,
            body: "baz",
            enqueueTimeStamp: fixedEnqueue,
            retryTimestamp: 100,
            clock: clock
        )
        
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
        let fetcher = MockFailureNetworkFetcher()
        let fakeDB  = RetryByTimerScriptedDatabaseRepository()
        let storage = DI.injectOrFail(PersistenceStorage.self)
        let eventRepo = MBEventRepository(
            fetcher: fetcher,
            persistenceStorage: storage,
            trackingIdsResolver: TrackingIdsResolver(),
            trackingHostResolver: TrackingHostResolver(persistenceStorage: storage, declaredTrackingDomains: [])
        )
        let manager = GuaranteedDeliveryManager(
            persistenceStorage: storage,
            databaseRepository: fakeDB,
            eventRepository: eventRepo,
            retryDeadline: 2
        )

        try fakeDB.erase()
        let events = eventGenerator.generateEvents(count: 10)
        try events.forEach { try fakeDB.create(event: $0) }

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
                if deliveringCount >= 2 && didSeeWaitingForRetry {
                    mgr.canScheduleOperations = false
                    token?.invalidate()
                    token = nil
                    expectation.fulfill()
                }
            }
        }

        manager.canScheduleOperations = true
        wait(for: [expectation], timeout: 60)

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

final class DeliveryPauseTestCase: XCTestCase {

    private var now: TimeInterval = 1_000_000
    private var databaseRepository: MockDatabaseRepository!
    private var eventRepository: ScriptedEventRepository!
    private var pauseManager: DeliveryPauseManager!
    private var retryDelayManager: DeliveryRetryDelayManager!

    override func setUp() {
        super.setUp()
        Mindbox.logger.logLevel = .none
        databaseRepository = try! MockDatabaseRepository(inMemory: true)
        try! databaseRepository.erase()
        eventRepository = ScriptedEventRepository()
        pauseManager = DeliveryPauseManager(now: { [unowned self] in self.now })
        retryDelayManager = DeliveryRetryDelayManager()
    }

    override func tearDown() {
        databaseRepository = nil
        eventRepository = nil
        pauseManager = nil
        retryDelayManager = nil
        super.tearDown()
    }

    func testResponseClassification() {
        let cases: [(MindboxError, DeliveryResult)] = [
            (.protocolError(protocolError(429)), .throttled),
            (.protocolError(protocolError(400)), .discarded),
            (.protocolError(protocolError(404)), .discarded),
            (.serverError(protocolError(500)), .serverFailure),
            (.serverError(protocolError(503)), .serverFailure),
            (.validationError(ValidationError(status: .validationError, validationMessages: [])), .retryLater),
            (.connectionError, .noResponse),
            (.invalidResponse(nil), .retryLater),
            (.unknown(NSError(domain: "test", code: 0)), .retryLater),
        ]
        cases.forEach { error, expected in
            XCTAssertEqual(DeliveryResult(error: error), expected, "\(error)")
        }
    }

    func testThrottlingPausesTheOperationAndDoublesUpToOneHour() throws {
        let key = "operation"
        let first = pauseManager.register(.throttled, for: key)!

        XCTAssertEqual(first, 180)
        XCTAssertEqual(try XCTUnwrap(pauseManager.remainingPause(for: key)), first, accuracy: 0.001)
        XCTAssertEqual(pauseManager.register(.throttled, for: key), first * 2)
        let pauses = (0..<10).compactMap { _ in pauseManager.register(.throttled, for: key) }
        XCTAssertEqual(pauses.last, 3600)
        XCTAssertTrue(pauses.allSatisfy { $0 <= 3600 })
    }

    func testPauseEndsWithTimeAndDeliveryResetsTheInterval() {
        let key = "operation"
        let first = pauseManager.register(.throttled, for: key)!

        now += first + 1
        XCTAssertNil(pauseManager.remainingPause(for: key))

        pauseManager.register(.delivered, for: key)
        let afterDelivery = pauseManager.register(.throttled, for: key)!
        XCTAssertEqual(afterDelivery, 180)
    }

    func testServerErrorsKeepTheEventWithoutPausingTheOperation() throws {
        let broken1 = customEvent("Down")
        let broken2 = customEvent("Down")
        let healthy = customEvent("Down")
        try [broken1, broken2, healthy].forEach { try databaseRepository.create(event: $0) }
        eventRepository.results[broken1.transactionId] = .failure(.serverError(protocolError(500)))
        eventRepository.results[broken2.transactionId] = .failure(.serverError(protocolError(503)))

        [broken1, broken2, healthy].forEach(run)

        XCTAssertEqual(eventRepository.sentTransactionIds, [broken1, broken2, healthy].map(\.transactionId))
        XCTAssertEqual(try databaseRepository.countEvents(), 2)
        XCTAssertNil(pauseManager.remainingPause(for: healthy.deliveryOperationKey))
    }

    func testNextThrottlingAfterThePauseExpiredDoublesThePause() throws {
        let key = "operation"
        let first = try XCTUnwrap(pauseManager.register(.throttled, for: key))

        now += first + 1
        XCTAssertNil(pauseManager.remainingPause(for: key))

        XCTAssertEqual(pauseManager.register(.throttled, for: key), first * 2)
    }

    func testRetryLaterDoesNotResetTheInterval() throws {
        let key = "operation"
        let first = try XCTUnwrap(pauseManager.register(.throttled, for: key))
        now += first + 1

        pauseManager.register(.retryLater, for: key)

        XCTAssertEqual(pauseManager.register(.throttled, for: key), first * 2)
    }

    func testDiscardedEventResetsTheInterval() throws {
        let key = "operation"
        pauseManager.register(.throttled, for: key)

        pauseManager.register(.discarded, for: key)

        XCTAssertNil(pauseManager.remainingPause(for: key))
        XCTAssertEqual(pauseManager.register(.throttled, for: key), 180)
    }

    func testResetClearsEveryPause() throws {
        pauseManager.register(.throttled, for: "first")
        pauseManager.register(.throttled, for: "second")

        pauseManager.reset()

        XCTAssertNil(pauseManager.remainingPause(for: "first"))
        XCTAssertNil(pauseManager.remainingPause(for: "second"))
        XCTAssertEqual(pauseManager.register(.throttled, for: "first"), 180)
    }

    func testTooManyRequestsKeepsTheEventAndPausesOnlyItsOperation() throws {
        let throttled = customEvent("Throttled")
        let other = customEvent("Other")
        try databaseRepository.create(event: throttled)
        try databaseRepository.create(event: other)
        eventRepository.results[throttled.transactionId] = .failure(.protocolError(protocolError(429)))
        eventRepository.results[other.transactionId] = .success(())

        run(throttled)
        run(other)

        XCTAssertEqual(try databaseRepository.countEvents(), 1)
        XCTAssertNotNil(pauseManager.remainingPause(for: throttled.deliveryOperationKey))
        XCTAssertNil(pauseManager.remainingPause(for: other.deliveryOperationKey))
    }

    func testClientErrorStillDeletesTheEvent() throws {
        let event = customEvent("Rejected")
        try databaseRepository.create(event: event)
        eventRepository.results[event.transactionId] = .failure(.protocolError(protocolError(400)))

        run(event)

        XCTAssertEqual(try databaseRepository.countEvents(), 0)
        XCTAssertNil(pauseManager.remainingPause(for: event.deliveryOperationKey))
    }

    func testDeliveryThroughTheOperationReturnsThePauseOfItsOperationToTheFirstValue() throws {
        let event = customEvent("Recovering")
        try databaseRepository.create(event: event)
        eventRepository.results[event.transactionId] = .failure(.protocolError(protocolError(429)))
        run(event)
        now += 181
        eventRepository.results[event.transactionId] = .success(())

        run(try storedEvent(event))

        XCTAssertEqual(try databaseRepository.countEvents(), 0)
        XCTAssertEqual(pauseManager.register(.throttled, for: event.deliveryOperationKey), 180)
    }

    func testThrottledInstallEventStaysInTheQueueAndIsDeliveredAfterThePause() throws {
        let install = Event(type: .installed, body: "{}")
        try databaseRepository.create(event: install)
        eventRepository.results[install.transactionId] = .failure(.protocolError(protocolError(429)))

        run(install)
        XCTAssertEqual(try databaseRepository.countEvents(), 1)
        XCTAssertNotNil(pauseManager.remainingPause(for: install.deliveryOperationKey))

        now += 181
        eventRepository.results[install.transactionId] = .success(())
        run(try storedEvent(install))

        XCTAssertEqual(try databaseRepository.countEvents(), 0)
        XCTAssertEqual(eventRepository.sentTransactionIds, [install.transactionId, install.transactionId])
    }

    func testTrackingIdsEventIsDeletedAfterAnyFailureWithoutPausingItsOperation() throws {
        let errors: [MindboxError] = [
            .protocolError(protocolError(429)),
            .serverError(protocolError(503)),
            .connectionError,
            .validationError(ValidationError(status: .validationError, validationMessages: []))
        ]
        for error in errors {
            let event = Event(type: .trackingIdsUpdated, body: "{}")
            try databaseRepository.create(event: event)
            eventRepository.results[event.transactionId] = .failure(error)

            run(event)

            XCTAssertEqual(try databaseRepository.countEvents(), 0, "\(error)")
            XCTAssertNil(pauseManager.remainingPause(for: event.deliveryOperationKey), "\(error)")
            XCTAssertEqual(retryDelayManager.completeRound(), 60, "\(error)")
        }
    }

    func testEventOfPausedOperationIsPostponedWithoutSending() throws {
        let event = customEvent("Paused")
        try databaseRepository.create(event: event)
        pauseManager.register(.throttled, for: event.deliveryOperationKey)

        run(event)

        XCTAssertTrue(eventRepository.sentTransactionIds.isEmpty)
        let stored = try databaseRepository.query(fetchLimit: 10, retryDeadline: -60)
        XCTAssertEqual(stored.map(\.transactionId), [event.transactionId])
        XCTAssertTrue(stored[0].isRetry)
    }

    func testServerFailuresOnRetriesDoubleTheRetryDelayUpToOneHour() {
        let delays: [TimeInterval] = (0..<8).map { _ in
            retryDelayManager.register(.serverFailure, transactionId: "failed", isRetry: true)
            return retryDelayManager.completeRound()
        }

        XCTAssertEqual(delays, [120, 240, 480, 960, 1920, 3600, 3600, 3600])
        XCTAssertEqual(retryDelayManager.current, 3600)
    }

    func testServerFailureOnFirstAttemptKeepsTheRetryDelay() {
        retryDelayManager.register(.serverFailure, transactionId: "new", isRetry: false)

        XCTAssertEqual(retryDelayManager.completeRound(), 60)
    }

    func testSeveralServerFailuresInOneRoundDoubleTheRetryDelayOnce() {
        (0..<20).forEach { retryDelayManager.register(.serverFailure, transactionId: "\($0)", isRetry: true) }

        XCTAssertEqual(retryDelayManager.completeRound(), 120)
        XCTAssertEqual(retryDelayManager.completeRound(), 120)
    }

    func testServerFailureOfTheSameEventTwiceInOneRoundDoublesTheRetryDelayWithoutWaitingForTheRoundToEnd() {
        retryDelayManager.register(.serverFailure, transactionId: "first", isRetry: true)
        retryDelayManager.register(.serverFailure, transactionId: "second", isRetry: true)
        XCTAssertEqual(retryDelayManager.current, 60)

        retryDelayManager.register(.serverFailure, transactionId: "first", isRetry: true)
        XCTAssertEqual(retryDelayManager.current, 120)

        retryDelayManager.register(.serverFailure, transactionId: "second", isRetry: true)

        XCTAssertEqual(retryDelayManager.current, 120)
        XCTAssertEqual(retryDelayManager.completeRound(), 240)
        XCTAssertEqual(retryDelayManager.completeRound(), 240)
    }

    func testServerFailedRetryDeliveredBeforeTheRoundEndsDoesNotDoubleTheRetryDelay() {
        retryDelayManager.register(.serverFailure, transactionId: "recovered", isRetry: true)

        retryDelayManager.register(.delivered, transactionId: "recovered", isRetry: true)

        XCTAssertEqual(retryDelayManager.completeRound(), 60)
    }

    func testServerFailedRetryThatLeavesServerFailureBeforeTheRoundEndsDoesNotDoubleTheRetryDelayWhileANewEventIsServerFailed() {
        let answers: [(String, (DeliveryRetryDelayManager) -> Void)] = [
            ("delivered", { $0.register(.delivered, transactionId: "retried", isRetry: true) }),
            ("discarded", { $0.register(.discarded, transactionId: "retried", isRetry: true) }),
            ("throttled", { $0.register(.throttled, transactionId: "retried", isRetry: true) }),
            ("retryLater", { $0.register(.retryLater, transactionId: "retried", isRetry: true) }),
            ("postponed", { $0.registerPostponed(transactionId: "retried") }),
        ]
        answers.forEach { name, answer in
            let manager = DeliveryRetryDelayManager()
            manager.register(.serverFailure, transactionId: "retried", isRetry: true)
            manager.register(.serverFailure, transactionId: "new", isRetry: false)

            answer(manager)

            XCTAssertEqual(manager.completeRound(), 60, name)
            manager.register(.serverFailure, transactionId: "new", isRetry: true)
            XCTAssertEqual(manager.completeRound(), 120, name)
        }
    }

    func testServerFailedRetryDoublesTheRetryDelayWhenAnotherServerFailedRetryIsDeliveredInTheSameRound() {
        retryDelayManager.register(.serverFailure, transactionId: "recovered", isRetry: true)
        retryDelayManager.register(.serverFailure, transactionId: "failed", isRetry: true)

        retryDelayManager.register(.delivered, transactionId: "recovered", isRetry: true)

        XCTAssertEqual(retryDelayManager.completeRound(), 120)
    }

    func testThrottlingNoResponseAndOtherKeptAnswersDoNotGrowTheRetryDelay() {
        [DeliveryResult.throttled, .noResponse, .retryLater].forEach { result in
            (0..<5).forEach { _ in
                retryDelayManager.register(result, transactionId: "event", isRetry: true)
                XCTAssertEqual(retryDelayManager.completeRound(), 60, "\(result)")
            }
        }
    }

    func testResultsOfOtherEventsKeepTheRetryDelayWhileAServerFailedEventIsStored() {
        [DeliveryResult.delivered, .discarded, .throttled, .retryLater, .noResponse].forEach { result in
            let manager = retryDelayManager(grownBy: ["failed"])

            manager.register(result, transactionId: "another", isRetry: true)
            manager.registerPostponed(transactionId: "postponed")

            XCTAssertEqual(manager.current, 480, "\(result)")
            XCTAssertEqual(manager.completeRound(), 480, "\(result)")
        }
    }

    func testRetryDelayReturnsToTheFirstValueOnlyAfterTheLastServerFailedEventGetsAnotherServerAnswer() {
        [DeliveryResult.delivered, .discarded, .throttled, .retryLater].forEach { result in
            let manager = retryDelayManager(grownBy: ["first", "second"])

            manager.register(result, transactionId: "first", isRetry: true)
            XCTAssertEqual(manager.current, 480, "\(result)")

            manager.register(result, transactionId: "second", isRetry: true)
            XCTAssertEqual(manager.current, 60, "\(result)")
            XCTAssertEqual(manager.completeRound(), 60, "\(result)")
        }
    }

    func testServerFailedEventPostponedByPauseNoLongerHoldsTheRetryDelay() {
        let manager = retryDelayManager(grownBy: ["failed"])

        manager.registerPostponed(transactionId: "failed")

        XCTAssertEqual(manager.current, 60)
    }

    func testNoResponseKeepsTheServerFailedEventHoldingTheRetryDelay() {
        let manager = retryDelayManager(grownBy: ["failed"])

        manager.register(.noResponse, transactionId: "failed", isRetry: true)

        XCTAssertEqual(manager.current, 480)
        XCTAssertEqual(manager.completeRound(), 480)
    }

    func testResetReturnsTheRetryDelayToTheFirstValueAndForgetsServerFailedEvents() {
        let manager = retryDelayManager(grownBy: ["failed"])
        manager.register(.serverFailure, transactionId: "failed", isRetry: true)

        manager.reset()

        XCTAssertEqual(manager.current, 60)
        XCTAssertEqual(manager.completeRound(), 60)
        manager.register(.serverFailure, transactionId: "next", isRetry: true)
        _ = manager.completeRound()
        manager.register(.delivered, transactionId: "next", isRetry: true)
        XCTAssertEqual(manager.current, 60)
    }

    func testServerErrorOnRetriedEventDoublesTheRetryDelayAndOnNewEventKeepsIt() throws {
        let new = customEvent("Down")
        try databaseRepository.create(event: new)
        eventRepository.results[new.transactionId] = .failure(.serverError(protocolError(503)))

        run(new)
        XCTAssertEqual(retryDelayManager.completeRound(), 60)

        run(try storedEvent(new))
        XCTAssertEqual(retryDelayManager.completeRound(), 120)
    }

    func testNoResponseOnRetriedEventKeepsTheRetryDelay() throws {
        let event = try retriedEvent("Offline")
        eventRepository.results[event.transactionId] = .failure(.connectionError)

        run(event)

        XCTAssertEqual(retryDelayManager.completeRound(), 60)
    }

    func testThrottledAndPostponedRetriedEventsKeepTheRetryDelay() throws {
        let throttled = try retriedEvent("Throttled")
        let postponed = try retriedEvent("Throttled")
        eventRepository.results[throttled.transactionId] = .failure(.protocolError(protocolError(429)))

        run(throttled)
        run(postponed)

        XCTAssertEqual(eventRepository.sentTransactionIds, [throttled.transactionId])
        XCTAssertEqual(retryDelayManager.completeRound(), 60)
    }

    func testDeliveryOfTheServerFailedEventReturnsTheRetryDelayToTheFirstValue() throws {
        let event = try retriedEvent("Recovered")
        eventRepository.results[event.transactionId] = .failure(.serverError(protocolError(503)))
        run(event)
        XCTAssertEqual(retryDelayManager.completeRound(), 120)

        eventRepository.results[event.transactionId] = .success(())
        run(try storedEvent(event))

        XCTAssertEqual(try databaseRepository.countEvents(), 0)
        XCTAssertEqual(retryDelayManager.current, 60)
    }

    func testValidationErrorAfterServerFailureReturnsTheRetryDelayToTheFirstValue() throws {
        let event = try retriedEvent("Rejected")
        eventRepository.results[event.transactionId] = .failure(.serverError(protocolError(503)))
        run(event)
        XCTAssertEqual(retryDelayManager.completeRound(), 120)

        eventRepository.results[event.transactionId] = .failure(
            .validationError(ValidationError(status: .validationError, validationMessages: []))
        )
        run(try storedEvent(event))

        XCTAssertEqual(try databaseRepository.countEvents(), 1)
        XCTAssertEqual(retryDelayManager.current, 60)
    }

    func testDeliveryOfAnotherEventKeepsTheRetryDelayWhileTheServerFailedEventIsStored() throws {
        let failed = try retriedEvent("Down")
        let another = customEvent("Up")
        try databaseRepository.create(event: another)
        eventRepository.results[failed.transactionId] = .failure(.serverError(protocolError(503)))
        run(failed)
        XCTAssertEqual(retryDelayManager.completeRound(), 120)

        run(another)

        XCTAssertEqual(eventRepository.sentTransactionIds, [failed.transactionId, another.transactionId])
        XCTAssertEqual(retryDelayManager.current, 120)
        XCTAssertEqual(retryDelayManager.completeRound(), 120)
    }

    func testServerFailedEventOfPausedOperationDoesNotHoldTheRetryDelay() throws {
        let event = try retriedEvent("Down")
        eventRepository.results[event.transactionId] = .failure(.serverError(protocolError(503)))
        run(event)
        XCTAssertEqual(retryDelayManager.completeRound(), 120)
        pauseManager.register(.throttled, for: event.deliveryOperationKey)

        run(try storedEvent(event))

        XCTAssertEqual(eventRepository.sentTransactionIds, [event.transactionId])
        XCTAssertEqual(retryDelayManager.current, 60)
    }

    func testQueueRetriesServerFailedEventWithGrowingDelayAndKeepsItAfterAnotherEventIsDelivered() throws {
        let failing = customEvent("Down")
        eventRepository.results[failing.transactionId] = .failure(.serverError(protocolError(503)))
        let manager = GuaranteedDeliveryManager(
            persistenceStorage: DI.injectOrFail(PersistenceStorage.self),
            databaseRepository: databaseRepository,
            eventRepository: eventRepository,
            retryDeadline: 1,
            maxRetryDeadline: 30
        )
        manager.canScheduleOperations = true
        try databaseRepository.create(event: failing)

        let thirdAttempt = expectation(description: "third attempt of the failing event")
        eventRepository.onSend = { [eventRepository] _ in
            if eventRepository?.attemptDates(of: failing.transactionId).count == 3 { thirdAttempt.fulfill() }
        }
        wait(for: [thirdAttempt], timeout: 20)
        let attempts = eventRepository.attemptDates(of: failing.transactionId)
        guard attempts.count == 3 else { return XCTFail("failing event was sent \(attempts.count) times") }
        XCTAssertEqual(attempts[1].timeIntervalSince(attempts[0]), 1, accuracy: 0.7)
        XCTAssertEqual(attempts[2].timeIntervalSince(attempts[1]), 2, accuracy: 0.7)

        let delivered = customEvent("Up")
        let deliveredSent = expectation(description: "new event is sent while the retry delay is grown")
        eventRepository.onSend = { event in
            if event.transactionId == delivered.transactionId { deliveredSent.fulfill() }
        }
        Thread.sleep(forTimeInterval: 1.5)
        try databaseRepository.create(event: delivered)
        wait(for: [deliveredSent], timeout: 1)

        Thread.sleep(forTimeInterval: 1)
        XCTAssertEqual(eventRepository.attemptDates(of: failing.transactionId).count, 3)
        manager.canScheduleOperations = false
    }

    func testRetryDelayReturnsToTheFirstValueWhenTheQueueBecomesEmptyWithoutDelivery() throws {
        let removed = customEvent("Down")
        let next = customEvent("Down")
        eventRepository.results[removed.transactionId] = .failure(.serverError(protocolError(503)))
        eventRepository.results[next.transactionId] = .failure(.serverError(protocolError(503)))
        let manager = GuaranteedDeliveryManager(
            persistenceStorage: DI.injectOrFail(PersistenceStorage.self),
            databaseRepository: databaseRepository,
            eventRepository: eventRepository,
            retryDeadline: 1,
            maxRetryDeadline: 30
        )
        manager.canScheduleOperations = true
        try databaseRepository.create(event: removed)

        let thirdAttempt = expectation(description: "third attempt of the event that will be removed")
        eventRepository.onSend = { [eventRepository] _ in
            if eventRepository?.attemptDates(of: removed.transactionId).count == 3 { thirdAttempt.fulfill() }
        }
        wait(for: [thirdAttempt], timeout: 20)
        Thread.sleep(forTimeInterval: 0.3)
        try databaseRepository.delete(event: removed)

        let secondAttemptOfNext = expectation(description: "second attempt of the next event")
        eventRepository.onSend = { [eventRepository] _ in
            if eventRepository?.attemptDates(of: next.transactionId).count == 2 { secondAttemptOfNext.fulfill() }
        }
        Thread.sleep(forTimeInterval: 0.3)
        try databaseRepository.create(event: next)
        wait(for: [secondAttemptOfNext], timeout: 3)

        let attempts = eventRepository.attemptDates(of: next.transactionId)
        guard attempts.count == 2 else { return XCTFail("next event was sent \(attempts.count) times") }
        XCTAssertEqual(attempts[1].timeIntervalSince(attempts[0]), 1.2, accuracy: 0.6)
        manager.canScheduleOperations = false
    }

    func testTrackVisitAndCustomOperationWithTheSameNameAreDifferentOperations() {
        let visit = Event(type: .trackVisit, body: "{}")
        let custom = customEvent(Event.Operation.trackVisit.rawValue)

        XCTAssertEqual(custom.deliveryOperationName, visit.deliveryOperationName)
        XCTAssertNotEqual(custom.deliveryOperationKey, visit.deliveryOperationKey)
    }

    private func run(_ event: Event) {
        let queue = OperationQueue()
        queue.addOperation(DeliveryOperation(
            databaseRepository: databaseRepository,
            eventRepository: eventRepository,
            event: event,
            pauseManager: pauseManager,
            retryDelayManager: retryDelayManager
        ))
        queue.waitUntilAllOperationsAreFinished()
    }

    private func retryDelayManager(grownBy transactionIds: [String]) -> DeliveryRetryDelayManager {
        let manager = DeliveryRetryDelayManager()
        (0..<3).forEach { _ in
            transactionIds.forEach { manager.register(.serverFailure, transactionId: $0, isRetry: true) }
            _ = manager.completeRound()
        }
        XCTAssertEqual(manager.current, 480)
        return manager
    }

    private func retriedEvent(_ name: String) throws -> Event {
        let event = customEvent(name)
        try databaseRepository.create(event: event)
        try databaseRepository.update(event: event)
        return try storedEvent(event)
    }

    private func storedEvent(_ event: Event) throws -> Event {
        try XCTUnwrap(
            try databaseRepository.query(fetchLimit: 100, retryDeadline: -60).first { $0.transactionId == event.transactionId }
        )
    }

    private func customEvent(_ name: String) -> Event {
        let body = BodyEncoder(encodable: CustomEvent(name: name, payload: "{}")).body
        return Event(type: .customEvent, body: body)
    }

    private func protocolError(_ code: Int) -> ProtocolError {
        ProtocolError(status: code >= 500 ? .internalServerError : .protocolError, errorMessage: "", httpStatusCode: code)
    }
}

private final class ScriptedEventRepository: EventRepository {

    private let lock = NSLock()
    private var scriptedResults: [String: Result<Void, MindboxError>] = [:]
    private var attempts: [(transactionId: String, date: Date)] = []
    private var sendObserver: ((Event) -> Void)?

    var results: [String: Result<Void, MindboxError>] {
        get { locked { scriptedResults } }
        set { locked { scriptedResults = newValue } }
    }

    var onSend: ((Event) -> Void)? {
        get { locked { sendObserver } }
        set { locked { sendObserver = newValue } }
    }

    var sentTransactionIds: [String] {
        locked { attempts.map(\.transactionId) }
    }

    func attemptDates(of transactionId: String) -> [Date] {
        locked { attempts.filter { $0.transactionId == transactionId }.map(\.date) }
    }

    func send(event: Event, completion: @escaping (Result<Void, MindboxError>) -> Void) {
        locked { attempts.append((event.transactionId, Date())) }
        onSend?(event)
        completion(results[event.transactionId] ?? .success(()))
    }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    func send<T>(type: T.Type, event: Event, completion: @escaping (Result<T, MindboxError>) -> Void) where T: Decodable {}

    func sendRaw(event: Event, completion: @escaping (Result<Data, MindboxError>) -> Void) {}

    func cancelAllRequests() {}
}
