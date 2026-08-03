//
//  MonitoringConfigParsingTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 9/11/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

// swiftlint:disable force_try force_unwrapping

fileprivate enum MonitoringConfig: String, Configurable {
    typealias DecodeType = Monitoring

    case configWithMonitoring = "MonitoringConfig" // Correct config

    case monitoringLogsError = "MonitoringLogsError" // Key is `logsTests` instead of `logs`
    case monitoringLogsTypeError = "MonitoringLogsTypeError" // Type of `logs` is Int instead of FailableDecodableArray<Logs>

    case monitoringLogsOneElementError = "MonitoringLogsOneElementError" // Key is `request` instead of `requestId`
    case monitoringLogsTwoElementsError = "MonitoringLogsTwoElementsError" // Key is `request` instead of `requestId` and key is `toTest` instead of `to`

    case monitoringLogsOneElementTypeError = "MonitoringLogsOneElementTypeError" // Type of `requestId` is Int instead of String
    case monitoringLogsTwoElementsTypeError = "MonitoringLogsTwoElementsTypeError" // Type of `requestId` is Int instead of String and type of `from` is Object instead `String`
    case monitoringLogsElementsMixedError = "MonitoringLogsElementsMixedError" // Type of `requestId` is Int instead of String and key is `fromTest` instead of `from`

    case monitoringLogsOldDeviceUuidFormat = "MonitoringLogsOldDeviceUuidFormat" // Legacy element with `deviceUUID` instead of `target`, next to a new-format element
    case monitoringLogsBothFieldsFormat = "MonitoringLogsBothFieldsFormat" // Element carries both `deviceUUID` and `target`
}

final class MonitoringConfigParsingTests: XCTestCase {

    func test_MonitoringConfig_shouldParseSuccessfully() {
        // Correct config
        let config = try! MonitoringConfig.configWithMonitoring.getConfig()

        XCTAssertEqual(config.logs.elements.count, 2)
        XCTAssertEqual(config.logs.elements.first?.target, "334db432a8f72f64a89664682f7bc032")
        XCTAssertEqual(config.logs.elements.last?.target, "248eccb79da2bbca61c133c59e4a1516")

        for log in config.logs.elements {
            XCTContext.runActivity(named: "Check log \(log) is in `config.logs.elements`") { _ in
                XCTAssertFalse(log.target.isEmpty)
                XCTAssertFalse(log.requestId.isEmpty)
                XCTAssertFalse(log.from.isEmpty)
                XCTAssertFalse(log.to.isEmpty)
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
            XCTContext.runActivity(named: "Check log \(log) is in `config.logs.elements`") { _ in
                XCTAssertFalse(log.target.isEmpty)
                XCTAssertFalse(log.requestId.isEmpty)
                XCTAssertFalse(log.from.isEmpty)
                XCTAssertFalse(log.to.isEmpty)
            }
        }
    }

    func test_MonitoringConfig_withLogsOneElementTypeError_shouldParseSuccessfullyRemainsElements() {
        // Type of `requestId` is Int instead of String
        let config = try? MonitoringConfig.monitoringLogsOneElementTypeError.getConfig()
        XCTAssertNotNil(config?.logs, "Monitoring must be parsed successfully")

        XCTAssertEqual(config?.logs.elements.count, 1)

        for log in config!.logs.elements {
            XCTContext.runActivity(named: "Check log \(log) is in `config.logs.elements`") { _ in
                XCTAssertFalse(log.target.isEmpty)
                XCTAssertFalse(log.requestId.isEmpty)
                XCTAssertFalse(log.from.isEmpty)
                XCTAssertFalse(log.to.isEmpty)
            }
        }
    }

    func test_MonitoringConfig_withLogsTwoElementsError_shouldParseSuccessfullyRemainsElements() {
        // Key is `request` instead of `requestId` and key is `toTest` instead of `to`
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

    func test_MonitoringConfig_withOldDeviceUuidFormat_shouldDropLegacyElements() {
        // First element has legacy `deviceUUID` instead of `target`, second is new-format
        let config = try! MonitoringConfig.monitoringLogsOldDeviceUuidFormat.getConfig()

        XCTAssertEqual(config.logs.elements.count, 1, "Legacy element must be dropped, new-format element must remain")
        XCTAssertEqual(config.logs.elements.first?.target, "248eccb79da2bbca61c133c59e4a1516")
    }

    func test_MonitoringConfig_withBothFieldsInElement_shouldParseTarget() {
        // Element carries both legacy `deviceUUID` and new `target`; `target` is decoded, `deviceUUID` is ignored
        let config = try! MonitoringConfig.monitoringLogsBothFieldsFormat.getConfig()

        XCTAssertEqual(config.logs.elements.count, 1)
        XCTAssertEqual(config.logs.elements.first?.target, "334db432a8f72f64a89664682f7bc032")
    }
}
