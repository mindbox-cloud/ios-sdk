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

    case configWithMonitoring = "MonitoringConfig"

    case monitoringLogsError = "MonitoringLogsError"
    case monitoringLogsTypeError = "MonitoringLogsTypeError"

    case monitoringLogsOneElementError = "MonitoringLogsOneElementError"
    case monitoringLogsTwoElementsError = "MonitoringLogsTwoElementsError"

    case monitoringLogsOneElementTypeError = "MonitoringLogsOneElementTypeError"
    case monitoringLogsTwoElementsTypeError = "MonitoringLogsTwoElementsTypeError"
    case monitoringLogsElementsMixedError = "MonitoringLogsElementsMixedError"

    case monitoringLogsOldDeviceUuidFormat = "MonitoringLogsOldDeviceUuidFormat"
    case monitoringLogsBothFieldsFormat = "MonitoringLogsBothFieldsFormat"
}

final class MonitoringConfigParsingTests: XCTestCase {

    func test_MonitoringConfig_shouldParseSuccessfully() {
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
            XCTContext.runActivity(named: "Check log \(log) is in `config.logs.elements`") { _ in
                XCTAssertFalse(log.target.isEmpty)
                XCTAssertFalse(log.requestId.isEmpty)
                XCTAssertFalse(log.from.isEmpty)
                XCTAssertFalse(log.to.isEmpty)
            }
        }
    }

    func test_MonitoringConfig_withLogsOneElementTypeError_shouldParseSuccessfullyRemainsElements() {
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

    func test_MonitoringConfig_withOldDeviceUuidFormat_shouldDropLegacyElements() {
        let config = try! MonitoringConfig.monitoringLogsOldDeviceUuidFormat.getConfig()

        XCTAssertEqual(config.logs.elements.count, 1, "Legacy element must be dropped, new-format element must remain")
        XCTAssertEqual(config.logs.elements.first?.target, "248eccb79da2bbca61c133c59e4a1516")
    }

    func test_MonitoringConfig_withBothFieldsInElement_shouldParseTarget() {
        let config = try! MonitoringConfig.monitoringLogsBothFieldsFormat.getConfig()

        XCTAssertEqual(config.logs.elements.count, 1)
        XCTAssertEqual(config.logs.elements.first?.target, "334db432a8f72f64a89664682f7bc032")
    }
}
