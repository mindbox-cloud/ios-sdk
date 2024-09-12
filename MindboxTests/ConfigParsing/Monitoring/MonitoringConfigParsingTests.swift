//
//  MonitoringConfigParsingTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 9/11/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

fileprivate enum MonitoringConfig: String, Configurable {
    typealias DecodeType = Monitoring
    
    case configWithMonitoring = "MonitoringConfig"
    
    case monitoringLogsError = "MonitoringLogsError"
    case monitoringLogsTypeError = "MonitoringLogsTypeError"
    case monitoringLogsOneElementError = "MonitoringLogsOneElementError"
    case monitoringLogsTwoElementsError = "MonitoringLogsTwoElementsError"
    case monitoringLogsOneElementTypeError = "MonitoringLogsOneElementTypeError"
    case monitoringLogsTwoElementsTypeError = "MonitoringLogsTwoElementsTypeError"
    case monitoringLogsElementsMixedError = "MonitoringLogsElementsMixedError"
}

final class MonitoringConfigParsingTests: XCTestCase {
    
    func test_MonitoringConfig_shouldParseSuccessfully() {
        let config = try! MonitoringConfig.configWithMonitoring.getConfig()
        XCTAssertTrue(config.logs.elements.count == 2)
        for log in config.logs.elements {
            XCTContext.runActivity(named: "Check log \(log) is in `config.logs.elements`") { test in
                XCTAssertNotNil(log.deviceUUID)
                XCTAssertNotNil(log.requestId)
                XCTAssertNotNil(log.from)
                XCTAssertNotNil(log.to)
            }
        }
    }
    
    func test_MonitoringConfig_withLogsError_shouldSetMonitoringToNil() {
        let config = try? MonitoringConfig.monitoringLogsError.getConfig()
        XCTAssertNil(config, "Monitoring must be `nil` if the key `logs` is not found")
        XCTAssertNil(config?.logs, "Logs must be `nil` if the key `logs` is not found")
    }

    func test_MonitoringConfig_withLogsTypeError_shouldSetMonitoringToNil() {
        let config = try? MonitoringConfig.monitoringLogsTypeError.getConfig()
        XCTAssertNil(config, "Monitoring must be `nil` if the type of `logs` is not a `FailableDecodableArray<Logs>`")
        XCTAssertNil(config?.logs, "Logs must be `nil` if the type of `logs` is not a `FailableDecodableArray<Logs>`")
    }
    
    func test_MonitoringConfig_withLogsOneElementError_shouldParseSuccessfullyRemainsElements() {
        let config = try? MonitoringConfig.monitoringLogsOneElementError.getConfig()
        XCTAssertNotNil(config?.logs, "Monitoring must be parsed successfully")
        
        XCTAssertEqual(config?.logs.elements.count, 1)
        
        for log in config!.logs.elements {
            XCTContext.runActivity(named: "Check log \(log) is in `config.logs.elements`") { test in
                XCTAssertNotNil(log.deviceUUID)
                XCTAssertNotNil(log.requestId)
                XCTAssertNotNil(log.from)
                XCTAssertNotNil(log.to)
            }
        }
    }
    
    func test_MonitoringConfig_withLogsOneElementTypeError_shouldParseSuccessfullyRemainsElements() {
        let config = try? MonitoringConfig.monitoringLogsOneElementTypeError.getConfig()
        XCTAssertNotNil(config?.logs, "Monitoring must be parsed successfully")
        
        XCTAssertEqual(config?.logs.elements.count, 1)
        
        for log in config!.logs.elements {
            XCTContext.runActivity(named: "Check log \(log) is in `config.logs.elements`") { test in
                XCTAssertNotNil(log.deviceUUID)
                XCTAssertNotNil(log.requestId)
                XCTAssertNotNil(log.from)
                XCTAssertNotNil(log.to)
            }
        }
    }
    
    func test_MonitoringConfig_withLogsTwoElementsError_shouldParseSuccessfullyRemainsElements() {
        let config = try? MonitoringConfig.monitoringLogsTwoElementsError.getConfig()
        XCTAssertNotNil(config?.logs, "Monitoring must be parsed successfully")
        
        XCTAssertEqual(config?.logs.elements.count, 0)
    }
    
    func test_MonitoringConfig_withLogsTwoElementsTypeError_shouldParseSuccessfullyRemainsElements() {
        let config = try? MonitoringConfig.monitoringLogsTwoElementsTypeError.getConfig()
        XCTAssertNotNil(config?.logs, "Monitoring must be parsed successfully, but with empty array")
        
        XCTAssertEqual(config?.logs.elements.count, 0)
    }
    
    func test_MonitoringConfig_withLogsTwoElementsMixedError_shouldParseSuccessfullyRemainsElements() {
        let config = try? MonitoringConfig.monitoringLogsElementsMixedError.getConfig()
        XCTAssertNotNil(config?.logs, "Monitoring must be parsed successfully, but with empty array")
        
        XCTAssertEqual(config?.logs.elements.count, 0)
    }
}
