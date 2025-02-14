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
    private var persistenceStorage: PersistenceStorage!
    private var targetingChecker: InAppTargetingCheckerProtocol!

    override func setUp() {
        super.setUp()
        manager = DI.injectOrFail(InappSessionManagerProtocol.self) as? InappSessionManager
        coreManagerMock = DI.injectOrFail(InAppCoreManagerProtocol.self) as? InAppCoreManagerMock
        persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
        targetingChecker = DI.injectOrFail(InAppTargetingCheckerProtocol.self)
        SessionTemporaryStorage.shared.expiredConfigSession = ""
    }

    override func tearDown() {
        manager = nil
        coreManagerMock = nil
        SessionTemporaryStorage.shared.expiredConfigSession = nil
        super.tearDown()
    }

    func test_lastVisitTimestampIsAlwaysSet() throws {
        XCTAssertNil(manager.lastTrackVisitTimestamp, "Изначально должно быть nil")
        manager.checkInappSession()
        XCTAssertNotNil(manager.lastTrackVisitTimestamp, "lastTrackVisitTimestamp должен быть установлен")
    }

    func test_inappSession_isNil_NoSessionUpdate() throws {
        manager.lastTrackVisitTimestamp = Date().addingTimeInterval(-100)
        let oldTimestamp = manager.lastTrackVisitTimestamp

        SessionTemporaryStorage.shared.expiredConfigSession = nil

        manager.checkInappSession()

        XCTAssertFalse(coreManagerMock.discardEventsCalled)
        XCTAssertTrue(coreManagerMock.sendEventCalled.isEmpty)

        let newTimestamp = manager.lastTrackVisitTimestamp
        XCTAssertNotNil(newTimestamp)
        XCTAssertNotEqual(newTimestamp, oldTimestamp)
    }

    func test_inappSession_isZero_NoSessionUpdate() throws {
        manager.lastTrackVisitTimestamp = Date().addingTimeInterval(-100)
        let oldTimestamp = manager.lastTrackVisitTimestamp

        SessionTemporaryStorage.shared.expiredConfigSession = "0.00:00:00.0000000"

        manager.checkInappSession()

        XCTAssertFalse(coreManagerMock.discardEventsCalled)
        XCTAssertTrue(coreManagerMock.sendEventCalled.isEmpty)

        let newTimestamp = manager.lastTrackVisitTimestamp
        XCTAssertNotNil(newTimestamp)
        XCTAssertNotEqual(newTimestamp, oldTimestamp)
    }

    func test_inappSession_isNegative_NoSessionUpdate() throws {
        manager.lastTrackVisitTimestamp = Date().addingTimeInterval(-100)
        let oldTimestamp = manager.lastTrackVisitTimestamp

        SessionTemporaryStorage.shared.expiredConfigSession = "-0.00:00:01.0000000"

        manager.checkInappSession()

        XCTAssertFalse(coreManagerMock.discardEventsCalled)
        XCTAssertTrue(coreManagerMock.sendEventCalled.isEmpty)

        let newTimestamp = manager.lastTrackVisitTimestamp
        XCTAssertNotNil(newTimestamp)
        XCTAssertNotEqual(newTimestamp, oldTimestamp)
    }
    
    func test_inappSession_isWrongFormat_NoSessionUpdate() throws {
        manager.lastTrackVisitTimestamp = Date().addingTimeInterval(-100)
        let oldTimestamp = manager.lastTrackVisitTimestamp

        SessionTemporaryStorage.shared.expiredConfigSession = "100"

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

        SessionTemporaryStorage.shared.expiredConfigSession = "0.00:59:00.0000000"

        manager.checkInappSession()

        XCTAssertFalse(coreManagerMock.discardEventsCalled)
        XCTAssertTrue(coreManagerMock.sendEventCalled.isEmpty)

        let newTimestamp = manager.lastTrackVisitTimestamp
        XCTAssertNotNil(newTimestamp)
        XCTAssertNotEqual(newTimestamp, oldTimestamp)
    }

    func test_timeBetweenVisitsGreaterThanSessionTimeInSeconds_SessionUpdate() throws {
        manager.lastTrackVisitTimestamp = Date().addingTimeInterval(-2400)
        let oldTimestamp = manager.lastTrackVisitTimestamp

        SessionTemporaryStorage.shared.expiredConfigSession = "0.00:30:00.0000000"

        manager.checkInappSession()

        XCTAssertTrue(coreManagerMock.discardEventsCalled)
        XCTAssertEqual(coreManagerMock.sendEventCalled, [.start], "sendEvent(.start) должен быть вызван ровно один раз")

        let newTimestamp = manager.lastTrackVisitTimestamp
        XCTAssertNotNil(newTimestamp)
        XCTAssertNotEqual(newTimestamp, oldTimestamp, "Timestamp должен быть обновлён")
    }
    
    func test_NoSessionUpdate_NoUserVisitCountIncrement() {
        let now = Date()
        manager.lastTrackVisitTimestamp = now.addingTimeInterval(-2400)
        let oldUserVisitCount = persistenceStorage.userVisitCount

        SessionTemporaryStorage.shared.expiredConfigSession = "0.00:59:00.0000000"
        
        manager.checkInappSession()
        XCTAssertEqual(persistenceStorage.userVisitCount, oldUserVisitCount)
    }
    
    func test_sessionUpdate_UpdateUserVisitCount() {
        manager.lastTrackVisitTimestamp = Date().addingTimeInterval(-2400)

        let oldUserVisitCount = persistenceStorage.userVisitCount

        SessionTemporaryStorage.shared.expiredConfigSession = "0.00:30:00.0000000"

        manager.checkInappSession()
        XCTAssertNotEqual(persistenceStorage.userVisitCount, oldUserVisitCount)
        if let oldUserVisitCount = oldUserVisitCount {
            XCTAssertEqual(persistenceStorage.userVisitCount, oldUserVisitCount + 1)
        }
    }
    
    func test_sessionUpdate_ResetStorages() {
        manager.lastTrackVisitTimestamp = Date().addingTimeInterval(-2400)
        SessionTemporaryStorage.shared.expiredConfigSession = "0.00:30:00.0000000"

        SessionTemporaryStorage.shared.observedCustomOperations = ["Test"]
        SessionTemporaryStorage.shared.operationsFromSettings = ["Test2"]
        SessionTemporaryStorage.shared.geoRequestCompleted = true
        SessionTemporaryStorage.shared.checkSegmentsRequestCompleted = true
        SessionTemporaryStorage.shared.isPresentingInAppMessage = true
        SessionTemporaryStorage.shared.sessionShownInApps = ["1"]
        
        targetingChecker.context.isNeedGeoRequest = true
        targetingChecker.checkedSegmentations = [.init(segmentation: .init(ids: .init(externalId: "1")), segment: nil)]
        targetingChecker.checkedProductSegmentations = [.init(ids: .init(externalId: "1"), segment: nil)]
        targetingChecker.geoModels = .init(city: 1, region: 2, country: 3)
        targetingChecker.event = .init(name: "Test", model: nil)

        manager.checkInappSession()
        
        XCTAssertEqual(SessionTemporaryStorage.shared.observedCustomOperations, [])
        XCTAssertEqual(SessionTemporaryStorage.shared.operationsFromSettings, [])
        XCTAssertEqual(SessionTemporaryStorage.shared.geoRequestCompleted, false)
        XCTAssertEqual(SessionTemporaryStorage.shared.checkSegmentsRequestCompleted, false)
        XCTAssertEqual(SessionTemporaryStorage.shared.isPresentingInAppMessage, false)
        XCTAssertEqual(SessionTemporaryStorage.shared.sessionShownInApps, [])
        
        targetingChecker.context.isNeedGeoRequest = false
        targetingChecker.checkedSegmentations = nil
        targetingChecker.checkedProductSegmentations = nil
        targetingChecker.geoModels = nil
        targetingChecker.event = nil
        
        targetingChecker.geoModels = nil
    }
}
