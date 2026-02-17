//
//  FeatureTogglesConfigParsingTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 17.02.2025.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

// swiftlint:disable force_try line_length

fileprivate enum FeatureTogglesConfig: String, Configurable {
    typealias DecodeType = Settings

    case configWithSettings = "SettingsConfig" // Correct config

    // FeatureToggles file names

    case settingsFeatureTogglesError = "SettingsFeatureTogglesError" // Key is `featureTogglesTest` instead of `featureToggles`
    case settingsFeatureTogglesTypeError = "SettingsFeatureTogglesTypeError" // Type of `featureToggles` is Int instead of FeatureToggles
    case settingsFeatureTogglesShouldSendInAppShowErrorMissing = "SettingsFeatureTogglesShouldSendInAppShowErrorMissing" // Missing `shouldSendInAppShowError`
    case settingsFeatureTogglesShouldSendInAppShowErrorTypeError = "SettingsFeatureTogglesShouldSendInAppShowErrorTypeError" // Type of `shouldSendInAppShowError` is String instead of Bool
    case settingsFeatureTogglesShouldSendInAppShowErrorFalse = "SettingsFeatureTogglesShouldSendInAppShowErrorFalse" // `shouldSendInAppShowError` is false
}

final class FeatureTogglesConfigParsingTests: XCTestCase {

    // MARK: - FeatureToggles

    func test_SettingsConfig_withFeatureTogglesTrue_shouldParseSuccessfully() {
        // `shouldSendInAppShowError` is true
        let config = try! FeatureTogglesConfig.configWithSettings.getConfig()

        XCTAssertNotNil(config.featureToggles, "FeatureToggles must be successfully parsed")
        XCTAssertEqual(config.featureToggles?.shouldSendInAppShowError, true, "shouldSendInAppShowError must be true")

        FeatureToggleManager.shared.applyFeatureToggles(config.featureToggles)
        XCTAssertTrue(FeatureToggleManager.shared.shouldSendInAppShowError())
    }

    func test_SettingsConfig_withFeatureTogglesFalse_shouldParseSuccessfully() {
        // `shouldSendInAppShowError` is false
        let config = try! FeatureTogglesConfig.settingsFeatureTogglesShouldSendInAppShowErrorFalse.getConfig()

        XCTAssertNotNil(config.featureToggles, "FeatureToggles must be successfully parsed")
        XCTAssertEqual(config.featureToggles?.shouldSendInAppShowError, false, "shouldSendInAppShowError must be false")

        FeatureToggleManager.shared.applyFeatureToggles(config.featureToggles)
        XCTAssertFalse(FeatureToggleManager.shared.shouldSendInAppShowError())
    }

    func test_SettingsConfig_withFeatureTogglesError_shouldSetFeatureTogglesToNil() {
        // Key is `featureTogglesTest` instead of `featureToggles`
        let config = try! FeatureTogglesConfig.settingsFeatureTogglesError.getConfig()

        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.slidingExpiration, "SlidingExpiration must be successfully parsed")
        XCTAssertNotNil(config.inapp, "InAppSettings must be successfully parsed")

        XCTAssertNil(config.featureToggles, "FeatureToggles must be `nil` if the key `featureToggles` is not found")
        
        FeatureToggleManager.shared.applyFeatureToggles(config.featureToggles)
        XCTAssertTrue(FeatureToggleManager.shared.shouldSendInAppShowError())
    }

    func test_SettingsConfig_withFeatureTogglesTypeError_shouldSetFeatureTogglesToNil() {
        // Type of `featureToggles` is Int instead of FeatureToggles
        let config = try! FeatureTogglesConfig.settingsFeatureTogglesTypeError.getConfig()

        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.slidingExpiration, "SlidingExpiration must be successfully parsed")
        XCTAssertNotNil(config.inapp, "InAppSettings must be successfully parsed")

        XCTAssertNil(config.featureToggles, "FeatureToggles must be `nil` if the type of `featureToggles` is not a `Settings.FeatureToggles`")
        
        FeatureToggleManager.shared.applyFeatureToggles(config.featureToggles)
        XCTAssertTrue(FeatureToggleManager.shared.shouldSendInAppShowError())
    }

    func test_SettingsConfig_withFeatureTogglesMissingShouldSendInAppShowError_shouldDefaultToTrue() {
        // Missing `shouldSendInAppShowError`
        let config = try! FeatureTogglesConfig.settingsFeatureTogglesShouldSendInAppShowErrorMissing.getConfig()

        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.slidingExpiration, "SlidingExpiration must be successfully parsed")
        XCTAssertNotNil(config.inapp, "InAppSettings must be successfully parsed")

        XCTAssertNotNil(config.featureToggles, "FeatureToggles must be successfully parsed")
        
        FeatureToggleManager.shared.applyFeatureToggles(config.featureToggles)
        XCTAssertTrue(FeatureToggleManager.shared.shouldSendInAppShowError())
    }

    func test_SettingsConfig_withFeatureTogglesShouldSendInAppShowErrorTypeError_shouldDefaultToTrue() {
        // Type of `shouldSendInAppShowError` is String instead of Bool
        let config = try! FeatureTogglesConfig.settingsFeatureTogglesShouldSendInAppShowErrorTypeError.getConfig()

        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.slidingExpiration, "SlidingExpiration must be successfully parsed")
        XCTAssertNotNil(config.inapp, "InAppSettings must be successfully parsed")

        XCTAssertNotNil(config.featureToggles, "FeatureToggles must be successfully parsed")
        
        FeatureToggleManager.shared.applyFeatureToggles(config.featureToggles)
        XCTAssertTrue(FeatureToggleManager.shared.shouldSendInAppShowError())
    }
}
