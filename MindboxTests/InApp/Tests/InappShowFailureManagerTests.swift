//
//  InappShowFailureManagerTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 19.02.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import XCTest
import UIKit
@testable import Mindbox
@testable import MindboxLogger

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
            details: "No window available",
            tags: nil
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

    func testEveryInappFailure_goesOutInErrorsTypedInappShowFailure_neverInFailures() throws {
        manager.addFailure(inappId: "inapp-1", reason: .geoRequestFailed, details: nil, tags: nil)
        manager.addFailure(inappId: "inapp-2", reason: .imageDownloadFailed, details: nil, tags: ["a": "b"])

        manager.sendFailures()

        assertCreatedEventsCountEventually(1)
        let event = try XCTUnwrap(databaseRepository.createdEvents.first)
        XCTAssertFalse(event.body.contains("\"failures\""))
        let errors = try XCTUnwrap(decodeFailures(from: event))
        XCTAssertEqual(errors.map(\.type), ["inappShowFailure", "inappShowFailure"])
        XCTAssertEqual(errors.map(\.inappId), ["inapp-1", "inapp-2"])
        XCTAssertEqual(errors.map(\.placeSystemName), [nil, nil])
        XCTAssertEqual(errors[1].tags, ["a": "b"])
    }

    func testSendWaitBudgetExceeded_namesThePlaceInAnEmbeddedBlockShowFailure() throws {
        manager.sendWaitBudgetExceeded(place: "silent-place", waited: 30, phase: .configMissing)

        assertCreatedEventsCountEventually(1)
        let event = try XCTUnwrap(databaseRepository.createdEvents.first)
        XCTAssertEqual(event.type, .inAppShowFailureEvent)
        XCTAssertFalse(event.body.contains("\"failures\""))
        let error = try XCTUnwrap(decodeFailures(from: event)?.first)
        XCTAssertEqual(error.type, "embeddedBlockShowFailure")
        XCTAssertEqual(error.placeSystemName, "silent-place")
        XCTAssertEqual(error.failureReason, .waitBudgetExceeded)
        XCTAssertEqual(error.errorDetails, "phase=config_missing; waited=0:00:30.0000000")
        XCTAssertNil(error.inappId)
        XCTAssertNil(error.tags)
        XCTAssertFalse(error.dateTimeUtc.isEmpty)
    }

    func testSendWaitBudgetExceeded_saysWhatTheSDKWasBusyWith() throws {
        manager.sendWaitBudgetExceeded(place: "silent-place", waited: 12.5, phase: .resolvePending)

        assertCreatedEventsCountEventually(1)
        let error = try XCTUnwrap(decodeFailures(from: try XCTUnwrap(databaseRepository.createdEvents.first))?.first)
        XCTAssertEqual(error.errorDetails, "phase=resolve_pending; waited=0:00:12.5000000")
    }

    func testSendWaitBudgetExceeded_whenFeatureDisabled_sendsNothing() {
        applyFeatureToggle(shouldSendInAppShowError: false)

        manager.sendWaitBudgetExceeded(place: "silent-place", waited: 30, phase: .configMissing)

        assertCreatedEventsCountEventually(0)
    }

    func testAddFailure_setsDateTimeUtcInsideMethod() throws {
        manager.addFailure(
            inappId: "inapp-2",
            reason: .unknownError,
            details: nil,
            tags: nil
        )

        manager.sendFailures()

        assertCreatedEventsCountEventually(1)
        let event = try XCTUnwrap(databaseRepository.createdEvents.first)
        let failure = try XCTUnwrap(decodeFailures(from: event)?.first)
        XCTAssertFalse(failure.dateTimeUtc.isEmpty)
        XCTAssertNotNil(failure.dateTimeUtc.toDate(withFormat: .utc))

        let dateTimeUtc = failure.dateTimeUtc
        XCTAssertEqual(dateTimeUtc.count, 20)
        XCTAssertTrue(dateTimeUtc.hasSuffix("Z"))
        XCTAssertFalse(dateTimeUtc.contains("AM"))
        XCTAssertFalse(dateTimeUtc.contains("PM"))
        XCTAssertFalse(dateTimeUtc.contains(" "))
        let pattern = #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$"#
        XCTAssertNotNil(dateTimeUtc.range(of: pattern, options: .regularExpression))
    }

    func testAddFailure_duplicateInappId_isIgnored() throws {
        manager.addFailure(
            inappId: "inapp-duplicate",
            reason: .imageDownloadFailed,
            details: "first",
            tags: nil
        )
        manager.addFailure(
            inappId: "inapp-duplicate",
            reason: .unknownError,
            details: "second",
            tags: nil
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
            details: "product",
            tags: nil
        )
        manager.addFailure(
            inappId: "inapp-priority",
            reason: .geoRequestFailed,
            details: "geo",
            tags: nil
        )
        manager.addFailure(
            inappId: "inapp-priority",
            reason: .customerSegmentRequestFailed,
            details: "segment",
            tags: nil
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
            details: "segment",
            tags: nil
        )
        manager.addFailure(
            inappId: "inapp-priority-no-downgrade",
            reason: .geoRequestFailed,
            details: "geo",
            tags: nil
        )
        manager.addFailure(
            inappId: "inapp-priority-no-downgrade",
            reason: .productSegmentRequestFailed,
            details: "product",
            tags: nil
        )

        manager.sendFailures()
        assertCreatedEventsCountEventually(1)

        let event = try XCTUnwrap(databaseRepository.createdEvents.first)
        let failures = try XCTUnwrap(decodeFailures(from: event))
        XCTAssertEqual(failures.count, 1)
        XCTAssertEqual(failures[0].failureReason, .customerSegmentRequestFailed)
        XCTAssertEqual(failures[0].errorDetails, "segment")
    }

    // MARK: - sendFailure: past the buffer

    func testSendFailure_isNotSwallowedByABufferedTargetingFailure() throws {
        manager.addFailure(inappId: "inapp-1", reason: .geoRequestFailed, details: "geo down", tags: nil)

        manager.sendFailure(inappId: "inapp-1", reason: .presentationFailed, details: "page said nothing", tags: nil)

        assertCreatedEventsCountEventually(1)
        let event = try XCTUnwrap(databaseRepository.createdEvents.first)
        let failures = try XCTUnwrap(decodeFailures(from: event))
        XCTAssertEqual(failures.count, 1)
        XCTAssertEqual(failures[0].failureReason, .presentationFailed)
        XCTAssertEqual(failures[0].errorDetails, "page said nothing")
    }

    func testSendFailure_leavesTheBufferIntact() throws {
        manager.addFailure(inappId: "inapp-1", reason: .geoRequestFailed, details: "geo down", tags: nil)
        manager.sendFailure(inappId: "inapp-1", reason: .webviewLoadFailed, details: "markup", tags: nil)
        assertCreatedEventsCountEventually(1)

        manager.sendFailures()

        assertCreatedEventsCountEventually(2)
        let second = try XCTUnwrap(databaseRepository.createdEvents.last)
        let failures = try XCTUnwrap(decodeFailures(from: second))
        XCTAssertEqual(failures.map(\.failureReason), [.geoRequestFailed])
    }

    func testSendFailure_whenFeatureDisabled_sendsNothing() {
        applyFeatureToggle(shouldSendInAppShowError: false)

        manager.sendFailure(inappId: "inapp-1", reason: .presentationFailed, details: nil, tags: nil)

        assertCreatedEventsCountEventually(0)
    }

    func testErrorDetailsLimit_matchesTheLimitTheBackendAccepts() {
        XCTAssertEqual(InappShowFailureManager.errorDetailsLimit, 1000)
    }

    func testSendFailure_truncatesErrorDetailsToLimit() throws {
        let long = String(repeating: "a", count: InappShowFailureManager.errorDetailsLimit + 100)

        manager.sendFailure(inappId: "inapp-1", reason: .presentationFailed, details: long, tags: nil)

        assertCreatedEventsCountEventually(1)
        let event = try XCTUnwrap(databaseRepository.createdEvents.first)
        let failures = try XCTUnwrap(decodeFailures(from: event))
        XCTAssertEqual(failures[0].errorDetails?.utf8.count, InappShowFailureManager.errorDetailsLimit)
    }

    func testSendFailures_success_clearsBufferedFailures() {
        manager.addFailure(
            inappId: "inapp-send-success",
            reason: .presentationFailed,
            details: nil,
            tags: nil
        )

        manager.sendFailures()
        manager.sendFailures()

        assertCreatedEventsCountEventually(1)
    }

    func testClearFailures_dropsTheBuffer_nothingIsSentAfterwards() {
        manager.addFailure(inappId: "inapp-dropped", reason: .geoRequestFailed, details: nil, tags: nil)

        manager.clearFailures()
        manager.sendFailures()

        assertCreatedEventsCountEventually(0)
    }

    func testSendFailures_createEventFails_keepsBufferedFailures() {
        manager.addFailure(
            inappId: "inapp-retry",
            reason: .unknownError,
            details: "will retry",
            tags: nil
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
            details: "should be ignored",
            tags: nil
        )
        
        applyFeatureToggle(shouldSendInAppShowError: true)
        manager.sendFailures()

        assertCreatedEventsCountEventually(0)
    }
    
    func testAddFailure_errorDetailsBelowLimit_isNotTruncated() throws {
        let details = String(repeating: "a", count: InappShowFailureManager.errorDetailsLimit - 1)

        manager.addFailure(inappId: "inapp-below-limit", reason: .unknownError, details: details, tags: nil)
        manager.sendFailures()

        assertCreatedEventsCountEventually(1)
        let event = try XCTUnwrap(databaseRepository.createdEvents.first)
        let failure = try XCTUnwrap(decodeFailures(from: event)?.first)
        XCTAssertEqual(failure.errorDetails?.count, InappShowFailureManager.errorDetailsLimit - 1)
        XCTAssertEqual(failure.errorDetails, details)
    }

    func testAddFailure_errorDetailsAtLimit_isNotTruncated() throws {
        let details = String(repeating: "b", count: InappShowFailureManager.errorDetailsLimit)

        manager.addFailure(inappId: "inapp-at-limit", reason: .unknownError, details: details, tags: nil)
        manager.sendFailures()

        assertCreatedEventsCountEventually(1)
        let event = try XCTUnwrap(databaseRepository.createdEvents.first)
        let failure = try XCTUnwrap(decodeFailures(from: event)?.first)
        XCTAssertEqual(failure.errorDetails?.count, InappShowFailureManager.errorDetailsLimit)
        XCTAssertEqual(failure.errorDetails, details)
    }

    func testAddFailure_errorDetailsAboveLimit_isTruncatedToLimit() throws {
        let limit = InappShowFailureManager.errorDetailsLimit
        let details = String(repeating: "c", count: limit + 500)

        manager.addFailure(inappId: "inapp-above-limit", reason: .unknownError, details: details, tags: nil)
        manager.sendFailures()

        assertCreatedEventsCountEventually(1)
        let event = try XCTUnwrap(databaseRepository.createdEvents.first)
        let failure = try XCTUnwrap(decodeFailures(from: event)?.first)
        XCTAssertEqual(failure.errorDetails?.count, limit)
        XCTAssertEqual(failure.errorDetails, String(details.prefix(limit)))
    }

    func testAddFailure_errorDetailsNil_remainsNil() throws {
        manager.addFailure(inappId: "inapp-nil-details", reason: .unknownError, details: nil, tags: nil)
        manager.sendFailures()

        assertCreatedEventsCountEventually(1)
        let event = try XCTUnwrap(databaseRepository.createdEvents.first)
        let failure = try XCTUnwrap(decodeFailures(from: event)?.first)
        XCTAssertNil(failure.errorDetails)
    }

    func testAddFailure_errorDetailsEmpty_remainsEmpty() throws {
        manager.addFailure(inappId: "inapp-empty-details", reason: .unknownError, details: "", tags: nil)
        manager.sendFailures()

        assertCreatedEventsCountEventually(1)
        let event = try XCTUnwrap(databaseRepository.createdEvents.first)
        let failure = try XCTUnwrap(decodeFailures(from: event)?.first)
        XCTAssertEqual(failure.errorDetails, "")
    }

    func testAddFailure_errorDetailsMultibyte_truncatesByUTF8Bytes() throws {
        let limit = InappShowFailureManager.errorDetailsLimit
        // Cyrillic 'а' is 2 bytes in UTF-8: total = 2 * limit bytes.
        let details = String(repeating: "а", count: limit)

        manager.addFailure(inappId: "inapp-multibyte", reason: .unknownError, details: details, tags: nil)
        manager.sendFailures()

        assertCreatedEventsCountEventually(1)
        let event = try XCTUnwrap(databaseRepository.createdEvents.first)
        let failure = try XCTUnwrap(decodeFailures(from: event)?.first)
        let truncated = try XCTUnwrap(failure.errorDetails)

        XCTAssertEqual(truncated.utf8.count, limit)
        XCTAssertEqual(truncated.count, limit / 2)
    }

    func testAddFailure_errorDetailsMultibyte_doesNotSplitCharacter() throws {
        let limit = InappShowFailureManager.errorDetailsLimit
        let asciiPrefix = String(repeating: "x", count: limit - 1)
        // Cyrillic 'ё' is 2 bytes — appending it would overflow by 1 byte.
        let details = asciiPrefix + "ё"

        manager.addFailure(inappId: "inapp-no-split", reason: .unknownError, details: details, tags: nil)
        manager.sendFailures()

        assertCreatedEventsCountEventually(1)
        let event = try XCTUnwrap(databaseRepository.createdEvents.first)
        let failure = try XCTUnwrap(decodeFailures(from: event)?.first)
        let truncated = try XCTUnwrap(failure.errorDetails)

        XCTAssertEqual(truncated, asciiPrefix)
        XCTAssertEqual(truncated.utf8.count, limit - 1)
    }

    func testAddFailure_errorDetailsEmoji_isNotSplit() throws {
        let limit = InappShowFailureManager.errorDetailsLimit
        // "🙂" is 4 UTF-8 bytes. Fill almost to the limit, then append an emoji.
        let asciiPrefix = String(repeating: "y", count: limit - 2)
        let details = asciiPrefix + "🙂"

        manager.addFailure(inappId: "inapp-emoji", reason: .unknownError, details: details, tags: nil)
        manager.sendFailures()

        assertCreatedEventsCountEventually(1)
        let event = try XCTUnwrap(databaseRepository.createdEvents.first)
        let failure = try XCTUnwrap(decodeFailures(from: event)?.first)
        let truncated = try XCTUnwrap(failure.errorDetails)

        XCTAssertEqual(truncated, asciiPrefix)
        XCTAssertLessThanOrEqual(truncated.utf8.count, limit)
    }

    func testAddFailure_priorityReplacement_truncatesNewDetails() throws {
        let limit = InappShowFailureManager.errorDetailsLimit
        let longDetails = String(repeating: "d", count: limit + 200)

        manager.addFailure(inappId: "inapp-priority-truncate", reason: .productSegmentRequestFailed, details: "short", tags: nil)
        manager.addFailure(inappId: "inapp-priority-truncate", reason: .customerSegmentRequestFailed, details: longDetails, tags: nil)
        manager.sendFailures()

        assertCreatedEventsCountEventually(1)
        let event = try XCTUnwrap(databaseRepository.createdEvents.first)
        let failure = try XCTUnwrap(decodeFailures(from: event)?.first)
        XCTAssertEqual(failure.failureReason, .customerSegmentRequestFailed)
        XCTAssertEqual(failure.errorDetails?.count, limit)
        XCTAssertEqual(failure.errorDetails, String(longDetails.prefix(limit)))
    }

    func testSendFailures_whenFeatureDisabled_doesNotSendAndKeepsBufferedFailures() throws {
        manager.addFailure(
            inappId: "inapp-toggle-disabled",
            reason: .presentationFailed,
            details: "disabled",
            tags: nil
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

    func testAddFailure_includesTags_whenTagsFeatureEnabled() throws {
        manager.addFailure(
            inappId: "inapp-tags-enabled",
            reason: .presentationFailed,
            details: nil,
            tags: ["templateType": "Popup"]
        )
        manager.sendFailures()

        assertCreatedEventsCountEventually(1)
        let event = try XCTUnwrap(databaseRepository.createdEvents.first)
        let failure = try XCTUnwrap(decodeFailures(from: event)?.first)
        XCTAssertEqual(failure.tags, ["templateType": "Popup"])
    }

    func testAddFailure_omitsTags_whenTagsFeatureDisabled() throws {
        applyTagsFeatureToggle(shouldSendInAppTags: false)

        manager.addFailure(
            inappId: "inapp-tags-disabled",
            reason: .presentationFailed,
            details: nil,
            tags: ["templateType": "Popup"]
        )
        manager.sendFailures()

        assertCreatedEventsCountEventually(1)
        let event = try XCTUnwrap(databaseRepository.createdEvents.first)
        let failure = try XCTUnwrap(decodeFailures(from: event)?.first)
        XCTAssertNil(failure.tags)
    }

    func testAddFailure_priorityReplacement_alsoReplacesTags() throws {
        manager.addFailure(
            inappId: "inapp-priority-tags",
            reason: .productSegmentRequestFailed,
            details: "product",
            tags: ["templateType": "First"]
        )
        manager.addFailure(
            inappId: "inapp-priority-tags",
            reason: .customerSegmentRequestFailed,
            details: "segment",
            tags: ["templateType": "Second"]
        )
        manager.sendFailures()

        assertCreatedEventsCountEventually(1)
        let event = try XCTUnwrap(databaseRepository.createdEvents.first)
        let failure = try XCTUnwrap(decodeFailures(from: event)?.first)
        XCTAssertEqual(failure.failureReason, .customerSegmentRequestFailed)
        XCTAssertEqual(failure.tags, ["templateType": "Second"])
    }
}

private extension InappShowFailureManagerTests {
    /// The wire shape, every `$type` flattened into one record: what the backend reads, not what the SDK built it from.
    struct ShowError: Decodable {
        let type: String
        let inappId: String?
        let placeSystemName: String?
        let failureReason: InAppShowFailureReason
        let errorDetails: String?
        let dateTimeUtc: String
        let tags: [String: String]?

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
            case inappId, placeSystemName, failureReason, errorDetails, dateTimeUtc, tags
        }
    }

    struct InAppShowErrorsBody: Decodable {
        let errors: [ShowError]
    }

    func decodeFailures(from event: Event) -> [ShowError]? {
        BodyDecoder<InAppShowErrorsBody>(decodable: event.body)?.body.errors
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

    func applyTagsFeatureToggle(shouldSendInAppTags: Bool) {
        featureToggleManager.applyFeatureToggles(
            Settings.FeatureToggles(shouldSendInAppShowError: nil, shouldSendInAppTags: shouldSendInAppTags, shouldPrewarmInAppWebView: nil, shouldCacheInAppWebView: nil)
        )
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

final class InAppPresentationErrorMappingTests: XCTestCase {
    func testFailureReasonMapping() {
        XCTAssertEqual(InAppPresentationError.failedToLoadImages.failureReason, .presentationFailed)
        XCTAssertEqual(InAppPresentationError.failedToLoadWindow.failureReason, .presentationFailed)
        XCTAssertEqual(InAppPresentationError.failed("details").failureReason, .presentationFailed)
        XCTAssertEqual(InAppPresentationError.webviewLoadFailed("details").failureReason, .webviewLoadFailed)
        XCTAssertEqual(InAppPresentationError.webviewPresentationFailed("details").failureReason, .webviewPresentationFailed)
    }

    func testFailureDetailsMapping() {
        XCTAssertEqual(
            InAppPresentationError.failedToLoadImages.failureDetails,
            "[InAppPresentationError] Failed to load images."
        )
        XCTAssertEqual(
            InAppPresentationError.failedToLoadWindow.failureDetails,
            "[InAppPresentationError] Failed to load window."
        )
        XCTAssertEqual(
            InAppPresentationError.failed("presentation-failed").failureDetails,
            "presentation-failed"
        )
        XCTAssertEqual(
            InAppPresentationError.webviewLoadFailed("webview-load").failureDetails,
            "webview-load"
        )
        XCTAssertEqual(
            InAppPresentationError.webviewPresentationFailed("webview-presentation").failureDetails,
            "webview-presentation"
        )
    }
}

final class PresentationDisplayUseCaseTests: XCTestCase {
    private var tracker: InAppMessagesTrackerMock!

    override func setUp() {
        super.setUp()
        tracker = InAppMessagesTrackerMock()
    }

    override func tearDown() {
        tracker = nil
        super.tearDown()
    }

    func testPresent_whenStrategyIsNotConfigured_callsOnError() {
        let sut = PresentationDisplayUseCase(
            tracker: tracker,
            dependenciesResolver: { _ in (strategy: nil, factory: nil) }
        )

        var receivedError: InAppPresentationError?
        sut.presentInAppUIModel(
            model: makeModalInApp(),
            onPresented: {},
            onTapAction: { _, _ in },
            onClose: {},
            onError: { receivedError = $0 }
        )

        assertFailedError(
            receivedError,
            details: "[PresentationDisplayUseCase] Presentation strategy is not configured."
        )
    }

    func testPresent_whenWindowCreationFails_callsFailedToLoadWindow() {
        let strategy = PresentationStrategyMock(windowToReturn: nil, presentResult: true)
        let sut = PresentationDisplayUseCase(
            tracker: tracker,
            dependenciesResolver: { _ in (strategy: strategy, factory: ViewFactoryMock(viewControllerToReturn: UIViewController())) }
        )

        var receivedError: InAppPresentationError?
        sut.presentInAppUIModel(
            model: makeModalInApp(),
            onPresented: {},
            onTapAction: { _, _ in },
            onClose: {},
            onError: { receivedError = $0 }
        )

        guard case .failedToLoadWindow = receivedError else {
            return XCTFail("Expected .failedToLoadWindow, got \(String(describing: receivedError))")
        }
    }

    func testPresent_whenFactoryIsMissing_callsOnError() {
        let strategy = PresentationStrategyMock(windowToReturn: UIWindow(), presentResult: true)
        let sut = PresentationDisplayUseCase(
            tracker: tracker,
            dependenciesResolver: { _ in (strategy: strategy, factory: nil) }
        )

        var receivedError: InAppPresentationError?
        sut.presentInAppUIModel(
            model: makeModalInApp(),
            onPresented: {},
            onTapAction: { _, _ in },
            onClose: {},
            onError: { receivedError = $0 }
        )

        assertFailedError(
            receivedError,
            details: "[PresentationDisplayUseCase] Factory does not exist."
        )
    }

    func testPresent_whenFactoryCannotCreateViewController_callsOnError() {
        let strategy = PresentationStrategyMock(windowToReturn: UIWindow(), presentResult: true)
        let factory = ViewFactoryMock(viewControllerToReturn: nil)
        let sut = PresentationDisplayUseCase(
            tracker: tracker,
            dependenciesResolver: { _ in (strategy: strategy, factory: factory) }
        )

        var receivedError: InAppPresentationError?
        sut.presentInAppUIModel(
            model: makeModalInApp(),
            onPresented: {},
            onTapAction: { _, _ in },
            onClose: {},
            onError: { receivedError = $0 }
        )

        assertFailedError(
            receivedError,
            details: "[PresentationDisplayUseCase] Failed to create in-app view controller."
        )
    }

    func testPresent_whenStrategyPresentFails_callsOnError() {
        let strategy = PresentationStrategyMock(windowToReturn: UIWindow(), presentResult: false)
        let factory = ViewFactoryMock(viewControllerToReturn: UIViewController())
        let sut = PresentationDisplayUseCase(
            tracker: tracker,
            dependenciesResolver: { _ in (strategy: strategy, factory: factory) }
        )

        var receivedError: InAppPresentationError?
        sut.presentInAppUIModel(
            model: makeModalInApp(),
            onPresented: {},
            onTapAction: { _, _ in },
            onClose: {},
            onError: { receivedError = $0 }
        )

        assertFailedError(
            receivedError,
            details: "[PresentationDisplayUseCase] Failed to present in-app view controller."
        )
    }

    private func makeModalInApp() -> InAppFormData {
        let modal = ModalFormVariant(content: InappFormVariantContent(background: ContentBackground(layers: []), elements: nil))
        return InAppFormData(
            inAppId: "inapp-id",
            isPriority: false,
            delayTime: nil,
            imagesDict: [:],
            firstImageValue: "",
            content: .modal(modal),
            frequency: nil
        )
    }

    private func assertFailedError(_ error: InAppPresentationError?, details: String, file: StaticString = #filePath, line: UInt = #line) {
        guard case .failed(let message) = error else {
            return XCTFail("Expected .failed(\(details)), got \(String(describing: error))", file: file, line: line)
        }
        XCTAssertEqual(message, details, file: file, line: line)
    }
}

final class SnackbarViewControllerTests: XCTestCase {
    func testLayout_whenImageIsMissing_reportsErrorAndCloses() {
        let model = makeSnackbarModel()
        let snackbarView = SnackbarView(onClose: {})

        var receivedError: InAppPresentationError?
        var closeCalls = 0
        let sut = TopSnackbarViewController(
            model: model,
            imagesDict: [:],
            snackbarView: snackbarView,
            firstImageValue: "missing-image",
            onPresented: {},
            onTapAction: { _, _ in },
            onError: { receivedError = $0 },
            onClose: { closeCalls += 1 }
        )

        sut.loadViewIfNeeded()
        sut.view.frame = CGRect(x: 0, y: 0, width: 320, height: 640)
        sut.viewDidLayoutSubviews()

        guard case .failedToLoadImages = receivedError else {
            return XCTFail("Expected .failedToLoadImages, got \(String(describing: receivedError))")
        }
        XCTAssertEqual(closeCalls, 1)
    }

    private func makeSnackbarModel() -> SnackbarFormVariant {
        let content = SnackbarFormVariantContent(
            background: ContentBackground(layers: []),
            position: ContentPosition(
                gravity: ContentPositionGravity(vertical: .top, horizontal: .center),
                margin: ContentPositionMargin(kind: .dp, top: 0, right: 0, left: 0, bottom: 0)
            ),
            elements: []
        )
        return SnackbarFormVariant(content: content)
    }
}

final class WebViewControllerWindowProviderTests: XCTestCase {
    func testOnInit_withInjectedWindowProvider_callsOnPresentedOnlyOnce() {
        let expectation = expectation(description: "onPresented is called once")
        expectation.expectedFulfillmentCount = 1

        let window = UIWindow()
        let model = makeModalVariant()
        let sut = WebViewController(
            model: model,
            id: "webview-id",
            imagesDict: [:],
            onPresented: {
                expectation.fulfill()
            },
            onTapAction: { _, _ in },
            onCloseInApp: {},
            onError: { _ in },
            windowProvider: { window },
            operation: nil,
            tags: nil
        )

        sut.onInit()
        sut.onInit()

        wait(for: [expectation], timeout: 1.0)
    }

    private func makeModalVariant() -> ModalFormVariant {
        ModalFormVariant(
            content: InappFormVariantContent(
                background: ContentBackground(layers: []),
                elements: nil
            )
        )
    }
}

private final class InAppMessagesTrackerMock: InAppMessagesTrackerProtocol {
    func trackView(id: String, timeToDisplay: String?, tags: [String: String]?) throws {}
    func trackClick(id: String, tags: [String: String]?) throws {}
    func trackTargeting(id: String, tags: [String: String]?) throws {}
}

private final class PresentationStrategyMock: PresentationStrategyProtocol {
    var window: UIWindow?
    private let windowToReturn: UIWindow?
    private let presentResult: Bool

    init(windowToReturn: UIWindow?, presentResult: Bool) {
        self.windowToReturn = windowToReturn
        self.presentResult = presentResult
    }

    func getWindow() -> UIWindow? {
        windowToReturn
    }

    func present(id: String, in window: UIWindow, using viewController: UIViewController) -> Bool {
        presentResult
    }

    func dismiss(viewController: UIViewController) {}

    func setupWindowFrame(model: MindboxFormVariant, imageSize: CGSize) {}
}

private final class ViewFactoryMock: ViewFactoryProtocol {
    private let viewControllerToReturn: UIViewController?

    init(viewControllerToReturn: UIViewController?) {
        self.viewControllerToReturn = viewControllerToReturn
    }

    func create(with params: ViewFactoryParameters) -> UIViewController? {
        viewControllerToReturn
    }
}
