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
    var container: TestDependencyProvider!
    var persistenceStorage: PersistenceStorage!
    var service: TTLValidationProtocol!

    override func setUp() {
        super.setUp()
        container = try! TestDependencyProvider()
        persistenceStorage = container.persistenceStorage
        service = container.ttlValidationService
    }
    
    override func tearDown() {
        container = nil
        persistenceStorage = nil
        service = nil
        super.tearDown()
    }
    
    func testNeedResetInapps_WithTTL_Exceeds() throws {
        persistenceStorage.configDownloadDate = Calendar.current.date(byAdding: .hour, value: -2, to: Date())
        let service = TTLValidationService(persistenceStorage: persistenceStorage)
        let settings = Settings(operations: nil, ttl: .init(inapps: .init(unit: .hours, value: 1)))
        let config = ConfigResponse(settings: settings)
        let result = service.needResetInapps(config: config)
        XCTAssertTrue(result, "Inapps должны быть сброшены, так как время ttl истекло.")
    }
    
    func testNeedResetInapps_WithTTL_NotExceeded() throws {
        persistenceStorage.configDownloadDate = Calendar.current.date(byAdding: .second, value: -1, to: Date())
        let service = TTLValidationService(persistenceStorage: persistenceStorage)
        let settings = Settings(operations: nil, ttl: .init(inapps: .init(unit: .seconds, value: 1)))
        let config = ConfigResponse(settings: settings)
        let result = service.needResetInapps(config: config)
        XCTAssertFalse(result, "Inapps не должны быть сброшены, так как время ttl еще не истекло.")
    }
    
    func testNeedResetInapps_WithoutTTL() throws {
        persistenceStorage.configDownloadDate = Date()
        let service = TTLValidationService(persistenceStorage: persistenceStorage)
        let settings = Settings(operations: nil, ttl: nil)
        let config = ConfigResponse(settings: settings)
        let result = service.needResetInapps(config: config)
        XCTAssertFalse(result, "Inapps не должны быть сброшены, так как в конфиге отсутствует TTL.")
    }
    
    func testNeedResetInapps_ExactlyAtTTL_ShouldNotReset() throws {
        let service = TTLValidationService(persistenceStorage: persistenceStorage)
        let settings = Settings(operations: nil, ttl: .init(inapps: .init(unit: .seconds, value: 1)))
        let config = ConfigResponse(settings: settings)
        persistenceStorage.configDownloadDate = Calendar.current.date(byAdding: .second, value: -1, to: Date())
        let result = service.needResetInapps(config: config)
        XCTAssertFalse(result, "Inapps не должны сбрасываться, если текущее время точно совпадает с истечением TTL.")
    }
    
    func testNeedResetInapps_WithTTLHalfHourAgo_NotExceeded() throws {
        persistenceStorage.configDownloadDate = Calendar.current.date(byAdding: .minute, value: -30, to: Date())
        let service = TTLValidationService(persistenceStorage: persistenceStorage)
        let settings = Settings(operations: nil, ttl: .init(inapps: .init(unit: .hours, value: 1)))
        let config = ConfigResponse(settings: settings)
        let result = service.needResetInapps(config: config)
        XCTAssertFalse(result, "Inapps не должны быть сброшены, так как время TTL еще не истекло.")
    }
}
