//
//  InappSessionManagerTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 27.01.2025.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

final class InappSessionManagerTests: XCTestCase {

    private var manager: InappSessionManager!
    private var coreManagerMock: InAppCoreManagerMock!

    override func setUp() {
        super.setUp()
        manager = DI.injectOrFail(InappSessionManagerProtocol.self) as? InappSessionManager
        coreManagerMock = DI.injectOrFail(InAppCoreManagerProtocol.self) as? InAppCoreManagerMock
        SessionTemporaryStorage.shared.expiredInappSession = ""
    }

    override func tearDown() {
        manager = nil
        coreManagerMock = nil
        SessionTemporaryStorage.shared.expiredInappSession = nil
        super.tearDown()
    }

    func test_lastVisitTimestampIsAlwaysSet() throws {
        XCTAssertNil(manager.lastTrackVisitTimestamp, "Изначально должно быть nil")
        manager.checkInappSession()
        XCTAssertNotNil(manager.lastTrackVisitTimestamp, "lastTrackVisitTimestamp должен быть установлен")
    }

    func test_inappSession_isNil_No_Session_Update() throws {
        manager.lastTrackVisitTimestamp = Date().addingTimeInterval(-100)
        let oldTimestamp = manager.lastTrackVisitTimestamp

        SessionTemporaryStorage.shared.expiredInappSession = nil

        manager.checkInappSession()

        XCTAssertFalse(coreManagerMock.discardEventsCalled)
        XCTAssertTrue(coreManagerMock.sendEventCalled.isEmpty)

        let newTimestamp = manager.lastTrackVisitTimestamp
        XCTAssertNotNil(newTimestamp)
        XCTAssertNotEqual(newTimestamp, oldTimestamp)
    }

    func test_inappSession_isZero_No_Session_Update() throws {
        manager.lastTrackVisitTimestamp = Date().addingTimeInterval(-100)
        let oldTimestamp = manager.lastTrackVisitTimestamp

        SessionTemporaryStorage.shared.expiredInappSession = "0.00:00:00.0000000"

        manager.checkInappSession()

        XCTAssertFalse(coreManagerMock.discardEventsCalled)
        XCTAssertTrue(coreManagerMock.sendEventCalled.isEmpty)

        let newTimestamp = manager.lastTrackVisitTimestamp
        XCTAssertNotNil(newTimestamp)
        XCTAssertNotEqual(newTimestamp, oldTimestamp)
    }

    func test_inappSession_isNegative_No_Session_Update() throws {
        manager.lastTrackVisitTimestamp = Date().addingTimeInterval(-100)
        let oldTimestamp = manager.lastTrackVisitTimestamp

        SessionTemporaryStorage.shared.expiredInappSession = "-0.00:00:01.0000000"

        manager.checkInappSession()

        XCTAssertFalse(coreManagerMock.discardEventsCalled)
        XCTAssertTrue(coreManagerMock.sendEventCalled.isEmpty)

        let newTimestamp = manager.lastTrackVisitTimestamp
        XCTAssertNotNil(newTimestamp)
        XCTAssertNotEqual(newTimestamp, oldTimestamp)
    }

    func test_timeBetweenVisitsLessThanSessionTimeInSeconds_NoSessionUpdate() throws {
        let now = Date()
        manager.lastTrackVisitTimestamp = now.addingTimeInterval(-2400)
        let oldTimestamp = manager.lastTrackVisitTimestamp

        SessionTemporaryStorage.shared.expiredInappSession = "0.00:59:00.0000000"

        manager.checkInappSession()

        XCTAssertFalse(coreManagerMock.discardEventsCalled)
        XCTAssertTrue(coreManagerMock.sendEventCalled.isEmpty)

        let newTimestamp = manager.lastTrackVisitTimestamp
        XCTAssertNotNil(newTimestamp)
        XCTAssertNotEqual(newTimestamp, oldTimestamp)
    }

    func test_timeBetweenVisitsGreaterThanSessionTimeInSeconds_SessionUpdated() throws {
        manager.lastTrackVisitTimestamp = Date().addingTimeInterval(-2400)
        let oldTimestamp = manager.lastTrackVisitTimestamp

        SessionTemporaryStorage.shared.expiredInappSession = "0.00:30:00.0000000"

        manager.checkInappSession()

        XCTAssertTrue(coreManagerMock.discardEventsCalled)
        XCTAssertEqual(coreManagerMock.sendEventCalled, [.start], "sendEvent(.start) должен быть вызван ровно один раз")

        let newTimestamp = manager.lastTrackVisitTimestamp
        XCTAssertNotNil(newTimestamp)
        XCTAssertNotEqual(newTimestamp, oldTimestamp, "Timestamp должен быть обновлён")
    }
}
