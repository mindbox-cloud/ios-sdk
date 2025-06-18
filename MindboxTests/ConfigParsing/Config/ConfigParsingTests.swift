//
//  ConfigParsingTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 9/11/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

// swiftlint:disable force_try

fileprivate enum Config: String, Configurable {
    typealias DecodeType = ConfigResponse

    case configWithSettingsABTestsMonitoringInapps = "ConfigWithSettingsABTestsMonitoringInapps" // Correct config

    case configSettingsError = "ConfigSettingsError" // Key is `settingsTest` instead of `settings`
    case configSettingsTypeError = "ConfigSettingsTypeError" // Type of `settings` is Int instead of Settings

    case configMonitoringError = "ConfigMonitoringError" // Key is `monitoringTest` instead of `monitoring`
    case configMonitoringTypeError = "ConfigMonitoringTypeError" // Type of `monitoring` is Int instead of Monitoring

    case configABTestsError = "ConfigABTestsError" // Key is `abtestsTest` instead of `abtests`
    case configABTestsTypeError = "ConfigABTestsTypeError" // Type of `abtests` is Int instead of [ABTest]

    case configInAppsError = "ConfigInAppsError" // Key is `inappsTest` instead of `inapps`
    case configInAppsTypeError = "ConfigInAppsTypeError" // Type of `inapps` is Int instead of FailableDecodableArray<InAppDTO>
    case configInAppIsPriorityInvalid = "ConfigInAppIsPriorityInvalid" // isPriority is String instead of Bool

    case configABTestsOneElementError = "ConfigABTestsOneElementError" // Key is `saltTest` instead of `salt`
    case configABTestsOneElementTypeError = "ConfigABTestsOneElementTypeError" // Type of `variants` is Int instead of [ABTestVariant]
}

final class ConfigParsingTests: XCTestCase {

    func test_Config_shouldParseSuccessfully() throws {
        // Correct config
        let config = try! Config.configWithSettingsABTestsMonitoringInapps.getConfig()
        XCTAssertNotNil(config.inapps, "Must NOT be nil")
        XCTAssertNotNil(config.abtests, "Must NOT be nil")
        XCTAssertNotNil(config.settings, "Must NOT be nil")
        XCTAssertNotNil(config.monitoring, "Must NOT be nil")
    }

    func test_Config_withSettingsError_shouldSetSettingsToNil() {
        // Key is `settingsTest` instead of `settings`
        let config = try! Config.configSettingsError.getConfig()
        XCTAssertNil(config.settings, "Settings must be `nil` if the key `settings` is not found")
        XCTAssertNotNil(config.inapps)
        XCTAssertNotNil(config.abtests)
        XCTAssertNotNil(config.monitoring)
    }

    func test_Config_withSettingsTypeError_shouldSetSettingsToNil() {
        // Type of `settings` is Int instead of Settings
        let config = try! Config.configSettingsTypeError.getConfig()
        XCTAssertNil(config.settings, "Settings must be `nil` if the type of `settings` is not `Settings`")
        XCTAssertNotNil(config.inapps)
        XCTAssertNotNil(config.abtests)
        XCTAssertNotNil(config.monitoring)
    }

    func test_Config_withMonitoringError_shouldSetMonitoringToNil() {
        // Key is `monitoringTest` instead of `monitoring`
        let config = try! Config.configMonitoringError.getConfig()
        XCTAssertNil(config.monitoring, "Monitoring must be `nil` if the key `monitoring` is not found")
        XCTAssertNotNil(config.settings)
        XCTAssertNotNil(config.inapps)
        XCTAssertNotNil(config.abtests)
    }

    func test_Config_withMonitoringTypeError_shouldSetMonitoringToNil() {
        // Type of `monitoring` is Int instead of Monitoring
        let config = try! Config.configMonitoringTypeError.getConfig()
        XCTAssertNil(config.monitoring, "Monitoring must be `nil` if the type of `monitoring` is not `Monitoring`")
        XCTAssertNotNil(config.settings)
        XCTAssertNotNil(config.inapps)
        XCTAssertNotNil(config.abtests)
    }

    func test_Config_withABTestsError_shouldSetABTestsToNil() {
        // Key is `abtestsTest` instead of `abtests`
        let config = try! Config.configABTestsError.getConfig()
        XCTAssertNil(config.abtests, "ABTests must be `nil` if the key `abtests` is not found")
        XCTAssertNotNil(config.monitoring)
        XCTAssertNotNil(config.settings)
        XCTAssertNotNil(config.inapps)
    }

    func test_Config_withABTestsTypeError_shouldSetABTestsToNil() {
        // Type of `abtests` is Int instead of [ABTest]
        let config = try! Config.configABTestsTypeError.getConfig()
        XCTAssertNil(config.abtests, "ABTests must be `nil` if the type of `abtests` is not `[ABTest]`")
        XCTAssertNotNil(config.monitoring)
        XCTAssertNotNil(config.settings)
        XCTAssertNotNil(config.inapps)
    }

    func test_Config_withInAppsError_shouldSetInAppsToNil() {
        // Key is `inappsTest` instead of `inapps`
        let config = try! Config.configInAppsError.getConfig()
        XCTAssertNil(config.inapps, "InApps must be `nil` if the key `inapps` is not found")
        XCTAssertNotNil(config.abtests)
        XCTAssertNotNil(config.monitoring)
        XCTAssertNotNil(config.settings)
    }

    func test_Config_withInAppsTypeError_shouldSetInAppsToNil() {
        // Type of `inapps` is Int instead of FailableDecodableArray<InAppDTO>
        let config = try! Config.configInAppsTypeError.getConfig()
        XCTAssertNil(config.inapps, "InApps must be `nil` if the type of `inapps` is not `FailableDecodableArray<InAppDTO>`")
        XCTAssertNotNil(config.abtests)
        XCTAssertNotNil(config.monitoring)
        XCTAssertNotNil(config.settings)
    }

    func test_Config_withABTestsOneElementError_shouldSetABTestsToNil() {
        // Key is `saltTest` instead of `salt`
        let config = try! Config.configABTestsOneElementError.getConfig()
        XCTAssertNil(config.abtests, "ABTests must be `nil` if even one element is corrupted")
        XCTAssertNotNil(config.monitoring)
        XCTAssertNotNil(config.settings)
        XCTAssertNotNil(config.inapps)
    }

    func test_Config_withABTestsOneElementTypeError_shouldSetABTestsToNil() {
        // Type of `variants` is Int instead of [ABTestVariant]
        let config = try! Config.configABTestsOneElementTypeError.getConfig()
        XCTAssertNil(config.abtests, "ABTests must be `nil` if even one element is corrupted")
        XCTAssertNotNil(config.monitoring)
        XCTAssertNotNil(config.settings)
        XCTAssertNotNil(config.inapps)
    }
    
    func test_Config_withInAppIsPriorityInvalid_shouldSetIsPriorityToFalse() {
        // isPriority is String instead of Bool
        let config = try! Config.configInAppIsPriorityInvalid.getConfig()
        XCTAssertNotNil(config.inapps, "InApps must NOT be `nil`")
        if let inapps = config.inapps?.elements, let firstInApp = inapps.first {
            XCTAssertEqual(firstInApp.id, "1")
            XCTAssertFalse(firstInApp.isPriority, "isPriority must be `false` when the value is invalid")
        } else {
            XCTFail("InApps should contain at least one element")
        }
    }
}
