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

    var eventRepositoryMock: EventRepositoryMock!
    var logsManager: SDKLogsManager!
    var persistenceStorageMock: PersistenceStorage!

    override func setUp() {
        super.setUp()
        persistenceStorageMock = testContainer.inject(PersistenceStorage.self)
        persistenceStorageMock.deviceUUID = "2"
        eventRepositoryMock = EventRepositoryMock()
        logsManager = SDKLogsManager(persistenceStorage: persistenceStorageMock, eventRepository: eventRepositoryMock)
    }

    override func tearDown() {
        eventRepositoryMock = nil
        persistenceStorageMock = nil
        logsManager = nil
        super.tearDown()
    }

    func testBody_withWrongUUID_shouldReturnNil() {
        let dateFrom = Date().addingTimeInterval(-60)
        let dateTo = Date()
        let logs: [Monitoring.Logs] = [
            .init(requestId: "1",
                  deviceUUID: "2",
                  from: dateFrom.toString(withFormat: .utc),
                  to: dateTo.toString(withFormat: .utc))
        ]
        persistenceStorageMock.deviceUUID = "3"
        logsManager.sendLogs(logs: logs)

        XCTAssertNil(eventRepositoryMock.lastBody)
        XCTAssertEqual(eventRepositoryMock.requests.count, 0)
    }

    func testBody_withRepeatedRequestID_shouldReturnOneRequest() {
        let dateFrom = Date().addingTimeInterval(-60).toString(withFormat: .utc)
        let dateTo = Date().toString(withFormat: .utc)
        let logs: [Monitoring.Logs] = [
            .init(requestId: "1", deviceUUID: "2", from: dateFrom, to: dateTo),
            .init(requestId: "1", deviceUUID: "2", from: dateFrom, to: dateTo)
        ]

        logsManager.sendLogs(logs: logs)
        XCTAssertEqual(eventRepositoryMock.requests.count, 1)
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
}
