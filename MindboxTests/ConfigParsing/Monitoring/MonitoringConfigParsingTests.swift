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
    
    case configWithMonitoring = "MonitoringConfig" // Correct config
    
    case monitoringLogsError = "MonitoringLogsError" // Key is `logsTests` instead of `logs`
    case monitoringLogsTypeError = "MonitoringLogsTypeError" // Type of `logs` is Int instead of FailableDecodableArray<Logs>
    
    case monitoringLogsOneElementError = "MonitoringLogsOneElementError" // Key is `request` instead of `requestId`
    case monitoringLogsTwoElementsError = "MonitoringLogsTwoElementsError" // Key is `request` instead of `requestId` and key is `device` instead of `deviceUUID`
    
    case monitoringLogsOneElementTypeError = "MonitoringLogsOneElementTypeError" // Type of `requestId` is Int instead of String
    case monitoringLogsTwoElementsTypeError = "MonitoringLogsTwoElementsTypeError" // Type of `requestId` is Int instead of String and type of `from` is Object instead `String`
    case monitoringLogsElementsMixedError = "MonitoringLogsElementsMixedError" // Type of `requestId` is Int instead of String and key is `fromTest` instead of `from`
}

final class MonitoringConfigParsingTests: XCTestCase {
    
    func test_MonitoringConfig_shouldParseSuccessfully() {
        // Correct config
        let config = try! MonitoringConfig.configWithMonitoring.getConfig()
        
        XCTAssertEqual(config.logs.elements.count, 2)
        
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
        // Key is `logsTests` instead of `logs`
        let config = try? MonitoringConfig.monitoringLogsError.getConfig()
        XCTAssertNil(config, "Monitoring must be `nil` if the key `logs` is not found")
        XCTAssertNil(config?.logs, "Logs must be `nil` if the key `logs` is not found")
    }

    func test_MonitoringConfig_withLogsTypeError_shouldSetMonitoringToNil() {
        // Type of `logs` is Int instead of FailableDecodableArray<Logs>
        let config = try? MonitoringConfig.monitoringLogsTypeError.getConfig()
        XCTAssertNil(config, "Monitoring must be `nil` if the type of `logs` is not a `FailableDecodableArray<Logs>`")
        XCTAssertNil(config?.logs, "Logs must be `nil` if the type of `logs` is not a `FailableDecodableArray<Logs>`")
    }
    
    func test_MonitoringConfig_withLogsOneElementError_shouldParseSuccessfullyRemainsElements() {
        // Type of `requestId` is Int instead of String
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
        // Type of `requestId` is Int instead of String
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
        // Key is `request` instead `requestId` and key is `device` instead of `deviceUUID`
        let config = try? MonitoringConfig.monitoringLogsTwoElementsError.getConfig()
        XCTAssertNotNil(config?.logs, "Monitoring must be parsed successfully")
        
        XCTAssertEqual(config?.logs.elements.count, 0)
    }
    
    func test_MonitoringConfig_withLogsTwoElementsTypeError_shouldParseSuccessfullyRemainsElements() {
        // Type of `requestId` is Int instead of String and type of `from` is Object instead of `String`
        let config = try? MonitoringConfig.monitoringLogsTwoElementsTypeError.getConfig()
        XCTAssertNotNil(config?.logs, "Monitoring must be parsed successfully, but with empty array")
        
        XCTAssertEqual(config?.logs.elements.count, 0)
    }
    
    func test_MonitoringConfig_withLogsTwoElementsMixedError_shouldParseSuccessfullyRemainsElements() {
        // Type of `requestId` is Int instead of String and key is `fromTest` instead of `from`
        let config = try? MonitoringConfig.monitoringLogsElementsMixedError.getConfig()
        XCTAssertNotNil(config?.logs, "Monitoring must be parsed successfully, but with empty array")
        
        XCTAssertEqual(config?.logs.elements.count, 0)
    }
}
