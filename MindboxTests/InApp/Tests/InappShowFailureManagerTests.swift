//
//  InappShowFailureManagerTests.swift
//  MindboxTests
//
//  Created by Cursor on 19.02.2026.
//

import XCTest
@testable import Mindbox

final class InappShowFailureManagerTests: XCTestCase {
    private var databaseRepository: InappShowFailureDatabaseRepositoryMock!
    private var featureToggleManager: FeatureToggleManager!
    private var manager: InappShowFailureManager!

    override func setUp() {
        super.setUp()
        databaseRepository = InappShowFailureDatabaseRepositoryMock()
        featureToggleManager = FeatureToggleManager()
        manager = InappShowFailureManager(
            databaseRepository: databaseRepository,
            featureToggleManager: featureToggleManager
        )
    }

    override func tearDown() {
        manager = nil
        featureToggleManager = nil
        databaseRepository = nil
        super.tearDown()
    }

    func testAddFailureAndSend_createsEventWithFailure() throws {
        manager.addFailure(
            inappId: "inapp-1",
            reason: .presentationFailed,
            details: "No window available"
        )

        manager.sendFailures()

        assertCreatedEventsCountEventually(1)
        let event = try XCTUnwrap(databaseRepository.createdEvents.first)
        XCTAssertEqual(event.type, .inAppShowFailureEvent)

        let failures = try XCTUnwrap(decodeFailures(from: event))
        XCTAssertEqual(failures.count, 1)
        XCTAssertEqual(failures[0].inappId, "inapp-1")
        XCTAssertEqual(failures[0].failureReason, .presentationFailed)
        XCTAssertEqual(failures[0].errorDetails, "No window available")
    }

    func testAddFailure_setsDateTimeUtcInsideMethod() throws {
        manager.addFailure(
            inappId: "inapp-2",
            reason: .unknownError,
            details: nil
        )

        manager.sendFailures()

        assertCreatedEventsCountEventually(1)
        let event = try XCTUnwrap(databaseRepository.createdEvents.first)
        let failure = try XCTUnwrap(decodeFailures(from: event)?.first)
        XCTAssertFalse(failure.dateTimeUtc.isEmpty)
        XCTAssertNotNil(makeUTCFormatter().date(from: failure.dateTimeUtc))
    }

    func testAddFailure_duplicateInappId_isIgnored() throws {
        manager.addFailure(
            inappId: "inapp-duplicate",
            reason: .imageDownloadFailed,
            details: "first"
        )
        manager.addFailure(
            inappId: "inapp-duplicate",
            reason: .unknownError,
            details: "second"
        )

        manager.sendFailures()

        assertCreatedEventsCountEventually(1)
        let event = try XCTUnwrap(databaseRepository.createdEvents.first)
        let failures = try XCTUnwrap(decodeFailures(from: event))
        XCTAssertEqual(failures.count, 1)
        XCTAssertEqual(failures[0].failureReason, .imageDownloadFailed)
        XCTAssertEqual(failures[0].errorDetails, "first")
    }

    func testAddFailure_targetingFailure_priorityReplacesExisting() throws {
        manager.addFailure(
            inappId: "inapp-priority",
            reason: .productSegmentRequestFailed,
            details: "product"
        )
        manager.addFailure(
            inappId: "inapp-priority",
            reason: .geoTargetingFailed,
            details: "geo"
        )
        manager.addFailure(
            inappId: "inapp-priority",
            reason: .customerSegmentRequestFailed,
            details: "segment"
        )

        manager.sendFailures()
        assertCreatedEventsCountEventually(1)

        let event = try XCTUnwrap(databaseRepository.createdEvents.first)
        let failures = try XCTUnwrap(decodeFailures(from: event))
        XCTAssertEqual(failures.count, 1)
        XCTAssertEqual(failures[0].failureReason, .customerSegmentRequestFailed)
        XCTAssertEqual(failures[0].errorDetails, "segment")
    }

    func testAddFailure_targetingFailure_priorityDoesNotDowngrade() throws {
        manager.addFailure(
            inappId: "inapp-priority-no-downgrade",
            reason: .customerSegmentRequestFailed,
            details: "segment"
        )
        manager.addFailure(
            inappId: "inapp-priority-no-downgrade",
            reason: .geoTargetingFailed,
            details: "geo"
        )
        manager.addFailure(
            inappId: "inapp-priority-no-downgrade",
            reason: .productSegmentRequestFailed,
            details: "product"
        )

        manager.sendFailures()
        assertCreatedEventsCountEventually(1)

        let event = try XCTUnwrap(databaseRepository.createdEvents.first)
        let failures = try XCTUnwrap(decodeFailures(from: event))
        XCTAssertEqual(failures.count, 1)
        XCTAssertEqual(failures[0].failureReason, .customerSegmentRequestFailed)
        XCTAssertEqual(failures[0].errorDetails, "segment")
    }

    func testClearFailures_removesBufferedFailures() {
        manager.addFailure(
            inappId: "inapp-clear",
            reason: .presentationFailed,
            details: "clear me"
        )
        manager.clearFailures()
        manager.sendFailures()

        assertCreatedEventsCountEventually(0)
    }

    func testSendFailures_success_clearsBufferedFailures() {
        manager.addFailure(
            inappId: "inapp-send-success",
            reason: .presentationFailed,
            details: nil
        )

        manager.sendFailures()
        manager.sendFailures()

        assertCreatedEventsCountEventually(1)
    }

    func testSendFailures_createEventFails_keepsBufferedFailures() {
        manager.addFailure(
            inappId: "inapp-retry",
            reason: .unknownError,
            details: "will retry"
        )
        databaseRepository.createError = InappShowFailureRepositoryError.createFailed

        manager.sendFailures()
        assertCreatedEventsCountEventually(0)

        databaseRepository.createError = nil
        manager.sendFailures()
        assertCreatedEventsCountEventually(1)
    }
    
    func testAddFailure_whenFeatureDisabled_doesNotBufferFailure() {
        applyFeatureToggle(shouldSendInAppShowError: false)
        
        manager.addFailure(
            inappId: "inapp-add-disabled",
            reason: .presentationFailed,
            details: "should be ignored"
        )
        
        applyFeatureToggle(shouldSendInAppShowError: true)
        manager.sendFailures()

        assertCreatedEventsCountEventually(0)
    }
    
    func testSendFailures_whenFeatureDisabled_doesNotSendAndKeepsBufferedFailures() throws {
        manager.addFailure(
            inappId: "inapp-toggle-disabled",
            reason: .presentationFailed,
            details: "disabled"
        )
        applyFeatureToggle(shouldSendInAppShowError: false)

        manager.sendFailures()
        assertCreatedEventsCountEventually(0)

        applyFeatureToggle(shouldSendInAppShowError: true)
        manager.sendFailures()

        assertCreatedEventsCountEventually(1)
        let event = try XCTUnwrap(databaseRepository.createdEvents.first)
        let failure = try XCTUnwrap(decodeFailures(from: event)?.first)
        XCTAssertEqual(failure.inappId, "inapp-toggle-disabled")
    }
}

private extension InappShowFailureManagerTests {
    struct InAppShowFailuresBody: Decodable {
        let failures: [InAppShowFailure]
    }

    func decodeFailures(from event: Event) -> [InAppShowFailure]? {
        BodyDecoder<InAppShowFailuresBody>(decodable: event.body)?.body.failures
    }

    func makeUTCFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        return formatter
    }
    
    func applyFeatureToggle(shouldSendInAppShowError: Bool) {
        let settingsJSON = """
        {
          "featureToggles": {
            "MobileSdkShouldSendInAppShowError": \(shouldSendInAppShowError ? "true" : "false")
          }
        }
        """
        let settingsData = settingsJSON.data(using: .utf8) ?? Data()
        let settings = try? JSONDecoder().decode(Settings.self, from: settingsData)
        featureToggleManager.applyFeatureToggles(settings?.featureToggles)
    }

    func assertCreatedEventsCountEventually(
        _ expectedCount: Int,
        timeout: TimeInterval = 1,
        settleTime: TimeInterval = 0.05,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        _ = waitUntil(timeout: timeout) {
            databaseRepository.createdEvents.count == expectedCount
        }

        // Let pending async tasks finish and verify count is stable.
        RunLoop.current.run(until: Date().addingTimeInterval(settleTime))
        XCTAssertEqual(databaseRepository.createdEvents.count, expectedCount, file: file, line: line)
    }

    @discardableResult
    func waitUntil(
        timeout: TimeInterval,
        pollInterval: TimeInterval = 0.01,
        condition: () -> Bool
    ) -> Bool {
        let timeoutDate = Date().addingTimeInterval(timeout)
        while Date() < timeoutDate {
            if condition() {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(pollInterval))
        }

        return condition()
    }
}

private enum InappShowFailureRepositoryError: Error {
    case createFailed
}

private final class InappShowFailureDatabaseRepositoryMock: DatabaseRepositoryProtocol {
    var limit: Int = 0
    var lifeLimitDate: Date?
    var deprecatedLimit: Int = 0
    var onObjectsDidChange: (() -> Void)?

    private let stateQueue = DispatchQueue(label: "com.Mindbox.InappShowFailureDatabaseRepositoryMock.state")
    private var _createError: Error?
    private var _createdEvents: [Event] = []

    var createError: Error? {
        get { stateQueue.sync { _createError } }
        set { stateQueue.sync { _createError = newValue } }
    }

    var createdEvents: [Event] {
        stateQueue.sync { _createdEvents }
    }

    func create(event: Event) throws {
        try stateQueue.sync {
            if let createError = _createError {
                throw createError
            }
            _createdEvents.append(event)
        }
    }

    func readEvent(by transactionId: String) throws -> Event? {
        createdEvents.first(where: { $0.transactionId == transactionId })
    }

    func update(event: Event) throws {}

    func delete(event: Event) throws {}

    func query(fetchLimit: Int, retryDeadline: TimeInterval) throws -> [Event] {
        []
    }

    func removeDeprecatedEventsIfNeeded() throws {}

    func countDeprecatedEvents() throws -> Int {
        0
    }

    func erase() throws {
        stateQueue.sync {
            _createdEvents.removeAll()
        }
    }

    func countEvents() throws -> Int {
        createdEvents.count
    }
}
