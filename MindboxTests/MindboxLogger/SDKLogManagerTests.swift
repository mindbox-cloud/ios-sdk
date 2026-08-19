//
//  SDKLogManagerTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 16.02.2023.
//  Copyright © 2023 Mikhail Barilov. All rights reserved.
//

import XCTest
@testable import Mindbox
@testable import MindboxLogger

final class SDKLogManagerTests: XCTestCase {

    // Shared cross-platform vectors: target is the MD5 hex of the lowercased deviceUUID.
    private enum Stub {
        static let deviceUUID = "216E6225-3170-4089-A6F0-3D1ED8F64153" // persisted uppercased, as the real SDK stores it
        static let target = "334db432a8f72f64a89664682f7bc032"
        static let foreignTarget = "248eccb79da2bbca61c133c59e4a1516" // another device's target
        static let emptyStringTarget = "d41d8cd98f00b204e9800998ecf8427e" // md5 of ""
    }

    var eventRepositoryMock: EventRepositoryMock!
    var logsManager: SDKLogsManager!
    var persistenceStorageMock: PersistenceStorage!

    override func setUp() {
        super.setUp()
        persistenceStorageMock = DI.injectOrFail(PersistenceStorage.self)
        persistenceStorageMock.deviceUUID = Stub.deviceUUID
        eventRepositoryMock = DI.injectOrFail(EventRepositoryMock.self)
        logsManager = DI.injectOrFail(SDKLogsManagerProtocol.self) as? SDKLogsManager
    }

    override func tearDown() {
        eventRepositoryMock = nil
        persistenceStorageMock = nil
        logsManager = nil
        super.tearDown()
    }

    func testBody_withMatchingTarget_shouldSendLogs() {
        logsManager.sendLogs(logs: [makeLog(target: Stub.target)])

        XCTAssertEqual(eventRepositoryMock.requests.count, 1)
    }

    func testBody_withForeignTarget_shouldNotSendLogs() {
        logsManager.sendLogs(logs: [makeLog(target: Stub.foreignTarget)])

        XCTAssertNil(eventRepositoryMock.lastBody)
        XCTAssertEqual(eventRepositoryMock.requests.count, 0)
    }

    func testBody_withUppercasedTargetHex_shouldSendLogs() {
        logsManager.sendLogs(logs: [makeLog(target: Stub.target.uppercased())])

        XCTAssertEqual(eventRepositoryMock.requests.count, 1)
    }

    func testBody_withRepeatedRequestID_shouldReturnOneRequest() {
        let logs = [
            makeLog(requestId: "1", target: Stub.target),
            makeLog(requestId: "1", target: Stub.target)
        ]

        logsManager.sendLogs(logs: logs)

        XCTAssertEqual(eventRepositoryMock.requests.count, 1)
    }

    func testBody_withNilDeviceUUID_shouldNotSendLogs() {
        persistenceStorageMock.deviceUUID = nil
        let logs = [
            makeLog(requestId: "1", target: Stub.target),
            makeLog(requestId: "2", target: Stub.emptyStringTarget)
        ]

        logsManager.sendLogs(logs: logs)

        XCTAssertEqual(eventRepositoryMock.requests.count, 0)
    }

    func testBody_withEmptyDeviceUUID_shouldNotSendLogs() {
        // A blank persisted deviceUUID must match nothing, even a config carrying md5("").
        persistenceStorageMock.deviceUUID = ""
        logsManager.sendLogs(logs: [makeLog(target: Stub.emptyStringTarget)])

        XCTAssertEqual(eventRepositoryMock.requests.count, 0)
    }

    func testBody_withEmptyTarget_shouldNotSendLogs() {
        // Parity with Android's validator: a blank target must never match.
        logsManager.sendLogs(logs: [makeLog(target: "")])

        XCTAssertEqual(eventRepositoryMock.requests.count, 0)
    }

    func testBody_withMalformedDatesEntry_shouldStillProcessSubsequentEntries() {
        let logs = [
            Monitoring.Logs(requestId: "1", target: Stub.target, from: "not-a-date", to: "not-a-date"),
            makeLog(requestId: "2", target: Stub.target)
        ]

        logsManager.sendLogs(logs: logs)

        XCTAssertEqual(eventRepositoryMock.requests.count, 1, "The valid entry after the malformed one must still be sent")
        XCTAssertEqual(persistenceStorageMock.handledlogRequestIds, ["1", "2"], "Both entries must be marked handled and persisted")
    }

    func test_status_shouldReturnOk() throws {
        let dateFrom = Date().addingTimeInterval(-60)
        let dateTo = Date()

        let logDate = Date().addingTimeInterval(-30)
        let testLog = LogMessage(timestamp: logDate, message: "OK Log")

        let status = logsManager.getStatus(firstLog: nil, lastLog: nil, logs: [testLog], from: dateFrom, to: dateTo)
        XCTAssertEqual(status, SDKLogsStatus.ok)
    }

    func test_status_shouldReturnNoData() throws {
        let dateFrom = Date().addingTimeInterval(-60)
        let dateTo = Date()

        let status = logsManager.getStatus(firstLog: nil, lastLog: nil, logs: [], from: dateFrom, to: dateTo)
        XCTAssertEqual(status, SDKLogsStatus.noData)
    }

    func test_firstLog_shouldReturnElderLog() throws {
        let dateFrom = Date().addingTimeInterval(-120)
        let dateTo = Date().addingTimeInterval(-60)

        let logDate = Date()
        let stringLogDate = logDate.toString(withFormat: .utc)
        let firstLog = LogMessage(timestamp: logDate, message: "First log")

        let status = logsManager.getStatus(firstLog: firstLog, lastLog: nil, logs: [], from: dateFrom, to: dateTo)
        XCTAssertEqual(status, SDKLogsStatus.elderLog(date: stringLogDate))
    }

    func test_lastLog_shouldReturnLatestLog() throws {
        let dateFrom = Date()
        let dateTo = Date()

        let logDate = Date().addingTimeInterval(-300)
        let stringLogDate = logDate.toString(withFormat: .utc)
        let lastLog = LogMessage(timestamp: logDate, message: "Latest log")

        let status = logsManager.getStatus(firstLog: nil, lastLog: lastLog, logs: [], from: dateFrom, to: dateTo)
        XCTAssertEqual(status, SDKLogsStatus.latestLog(date: stringLogDate))
    }

    func test_status_shouldReturnLargeSize() throws {
        let dateFrom = Date().addingTimeInterval(-60)
        let dateTo = Date()

        let timestamp = Date().addingTimeInterval(-30)
        let message = String(repeating: "HelloWorld", count: 300000)
        let bigMessage = LogMessage(timestamp: timestamp, message: message)

        let status = logsManager.getStatus(firstLog: nil, lastLog: nil, logs: [bigMessage], from: dateFrom, to: dateTo)
        XCTAssertEqual(status, SDKLogsStatus.largeSize)
    }

    func test_actualLogs() throws {
        let normalLog = LogMessage(timestamp: Date(), message: "HelloWorld")

        let bigMessage = String(repeating: "Hello", count: 300000)
        let bigLog = LogMessage(timestamp: Date(), message: bigMessage)

        let expectedResult = [normalLog.description]
        let actualLogs = logsManager.actualLogs(allLogs: [normalLog, bigLog])

        XCTAssertEqual(actualLogs.count, 1)
        XCTAssertEqual(actualLogs, expectedResult)
    }

    private func makeLog(requestId: String = "1",
                         target: String,
                         from: Date = Date().addingTimeInterval(-60),
                         to: Date = Date()) -> Monitoring.Logs {
        .init(requestId: requestId,
              target: target,
              from: from.toString(withFormat: .utc),
              to: to.toString(withFormat: .utc))
    }
}
