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
    private var manager: InappShowFailureManager!

    override func setUp() {
        super.setUp()
        databaseRepository = InappShowFailureDatabaseRepositoryMock()
        manager = InappShowFailureManager(databaseRepository: databaseRepository)
    }

    override func tearDown() {
        manager = nil
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

        XCTAssertEqual(databaseRepository.createdEvents.count, 1)
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

        let event = try XCTUnwrap(databaseRepository.createdEvents.first)
        let failures = try XCTUnwrap(decodeFailures(from: event))
        XCTAssertEqual(failures.count, 1)
        XCTAssertEqual(failures[0].failureReason, .imageDownloadFailed)
        XCTAssertEqual(failures[0].errorDetails, "first")
    }

    func testClearFailures_removesBufferedFailures() {
        manager.addFailure(
            inappId: "inapp-clear",
            reason: .presentationFailed,
            details: "clear me"
        )
        manager.clearFailures()

        manager.sendFailures()

        XCTAssertTrue(databaseRepository.createdEvents.isEmpty)
    }

    func testSendFailures_success_clearsBufferedFailures() {
        manager.addFailure(
            inappId: "inapp-send-success",
            reason: .presentationFailed,
            details: nil
        )

        manager.sendFailures()
        manager.sendFailures()

        XCTAssertEqual(databaseRepository.createdEvents.count, 1)
    }

    func testSendFailures_createEventFails_keepsBufferedFailures() {
        manager.addFailure(
            inappId: "inapp-retry",
            reason: .unknownError,
            details: "will retry"
        )
        databaseRepository.createError = InappShowFailureRepositoryError.createFailed

        manager.sendFailures()
        XCTAssertTrue(databaseRepository.createdEvents.isEmpty)

        databaseRepository.createError = nil
        manager.sendFailures()
        XCTAssertEqual(databaseRepository.createdEvents.count, 1)
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
}

private enum InappShowFailureRepositoryError: Error {
    case createFailed
}

private final class InappShowFailureDatabaseRepositoryMock: DatabaseRepositoryProtocol {
    var limit: Int = 0
    var lifeLimitDate: Date?
    var deprecatedLimit: Int = 0
    var onObjectsDidChange: (() -> Void)?

    var createError: Error?
    private(set) var createdEvents: [Event] = []

    func create(event: Event) throws {
        if let createError {
            throw createError
        }
        createdEvents.append(event)
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
        createdEvents.removeAll()
    }

    func countEvents() throws -> Int {
        createdEvents.count
    }
}
