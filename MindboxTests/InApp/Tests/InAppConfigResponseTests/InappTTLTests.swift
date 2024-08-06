//
//  InappTTLTests.swift
//  MindboxTests
//
//  Created by vailence on 08.04.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

class InappTTLTests: XCTestCase {
    var persistenceStorage: PersistenceStorage!
    var service: TTLValidationProtocol!

    override func setUp() {
        super.setUp()
        persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
        service = TTLValidationService(persistenceStorage: persistenceStorage)
    }
    
    override func tearDown() {
        persistenceStorage = nil
        service = nil
        super.tearDown()
    }
    
    func testNeedResetInapps_WithTTL_Exceeds() throws {
        persistenceStorage.configDownloadDate = Calendar.current.date(byAdding: .hour, value: -2, to: Date())
        let settings = Settings(operations: nil, ttl: .init(inapps: "01:00:00"))
        let config = ConfigResponse(settings: settings)
        let result = service.needResetInapps(config: config)
        XCTAssertTrue(result, "Inapps должны быть сброшены, так как время ttl истекло.")
    }
    
    func testNeedResetInapps_WithTTL_NotExceeded() throws {
        persistenceStorage.configDownloadDate = Calendar.current.date(byAdding: .second, value: -1, to: Date())
        let settings = Settings(operations: nil, ttl: .init(inapps: "00:00:02"))
        let config = ConfigResponse(settings: settings)
        let result = service.needResetInapps(config: config)
        XCTAssertFalse(result, "Inapps не должны быть сброшены, так как время ttl еще не истекло.")
    }
    
    func testNeedResetInapps_WithoutTTL() throws {
        persistenceStorage.configDownloadDate = Date()
        let settings = Settings(operations: nil, ttl: nil)
        let config = ConfigResponse(settings: settings)
        let result = service.needResetInapps(config: config)
        XCTAssertFalse(result, "Inapps не должны быть сброшены, так как в конфиге отсутствует TTL.")
    }
    
    func testNeedResetInapps_WithTTLHalfHourAgo_NotExceeded() throws {
        persistenceStorage.configDownloadDate = Calendar.current.date(byAdding: .minute, value: -30, to: Date())
        let settings = Settings(operations: nil, ttl: .init(inapps: "01:00:00"))
        let config = ConfigResponse(settings: settings)
        let result = service.needResetInapps(config: config)
        XCTAssertFalse(result, "Inapps не должны быть сброшены, так как время TTL еще не истекло.")
    }
    
    func testNeedResetInapps_WithTTLHalfMinutesAgo_NotExceeded() throws {
        persistenceStorage.configDownloadDate = Calendar.current.date(byAdding: .second, value: -30, to: Date())
        let settings = Settings(operations: nil, ttl: .init(inapps: "00:01:00"))
        let config = ConfigResponse(settings: settings)
        let result = service.needResetInapps(config: config)
        XCTAssertFalse(result, "Inapps не должны быть сброшены, так как время TTL еще не истекло.")
    }
    
    func testNeedResetInapps_WithTTLOneDayAgo_NotExceeded() throws {
        persistenceStorage.configDownloadDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        let settings = Settings(operations: nil, ttl: .init(inapps: "2.00:00:00"))
        let config = ConfigResponse(settings: settings)
        let result = service.needResetInapps(config: config)
        XCTAssertFalse(result, "Inapps не должны быть сброшены, так как время TTL еще не истекло.")
    }
    
    func testNeedResetInapps_WithMinusTTL_NotExceeded() throws {
        persistenceStorage.configDownloadDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())
        let settings = Settings(operations: nil, ttl: .init(inapps: "-2.00:00:00"))
        let config = ConfigResponse(settings: settings)
        let result = service.needResetInapps(config: config)
        XCTAssertFalse(result, "Inapps не должны быть сброшены, так как время TTL еще не истекло.")
    }
    
    func testNeedResetInapps_WithMinusOneDayTTL_NotExceeded() throws {
        persistenceStorage.configDownloadDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())
        let settings = Settings(operations: nil, ttl: .init(inapps: "-1.00:00:00"))
        let config = ConfigResponse(settings: settings)
        let result = service.needResetInapps(config: config)
        XCTAssertFalse(result, "Inapps не должны быть сброшены, так как время TTL еще не истекло.")
    }
}
