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

    case configWithSettings = "SettingsConfig"

    case settingsFeatureTogglesError = "SettingsFeatureTogglesError"
    case settingsFeatureTogglesTypeError = "SettingsFeatureTogglesTypeError"
    case settingsFeatureTogglesShouldSendInAppShowErrorMissing = "SettingsFeatureTogglesShouldSendInAppShowErrorMissing"
    case settingsFeatureTogglesShouldSendInAppShowErrorTypeError = "SettingsFeatureTogglesShouldSendInAppShowErrorTypeError"
    case settingsFeatureTogglesShouldSendInAppShowErrorFalse = "SettingsFeatureTogglesShouldSendInAppShowErrorFalse"

    case settingsFeatureTogglesShouldSendInAppTagsFalse = "SettingsFeatureTogglesShouldSendInAppTagsFalse"
    case settingsFeatureTogglesShouldSendInAppTagsTypeError = "SettingsFeatureTogglesShouldSendInAppTagsTypeError"
}

final class FeatureTogglesConfigParsingTests: XCTestCase {

    // MARK: - FeatureToggles

    func test_SettingsConfig_withFeatureTogglesTrue_shouldParseSuccessfully() {
        let config = try! FeatureTogglesConfig.configWithSettings.getConfig()

        XCTAssertNotNil(config.featureToggles, "FeatureToggles must be successfully parsed")
        XCTAssertEqual(config.featureToggles?.shouldSendInAppShowError, true, "shouldSendInAppShowError must be true")

        let featureToggleManager = FeatureToggleManager()
        featureToggleManager.applyFeatureToggles(config.featureToggles)
        XCTAssertTrue(featureToggleManager.isFeatureEnabled(.shouldSendInAppShowError))
    }

    func test_SettingsConfig_withFeatureTogglesFalse_shouldParseSuccessfully() {
        let config = try! FeatureTogglesConfig.settingsFeatureTogglesShouldSendInAppShowErrorFalse.getConfig()

        XCTAssertNotNil(config.featureToggles, "FeatureToggles must be successfully parsed")
        XCTAssertEqual(config.featureToggles?.shouldSendInAppShowError, false, "shouldSendInAppShowError must be false")

        let featureToggleManager = FeatureToggleManager()
        featureToggleManager.applyFeatureToggles(config.featureToggles)
        XCTAssertFalse(featureToggleManager.isFeatureEnabled(.shouldSendInAppShowError))
    }

    func test_SettingsConfig_withFeatureTogglesError_shouldSetFeatureTogglesToNil() {
        let config = try! FeatureTogglesConfig.settingsFeatureTogglesError.getConfig()

        XCTAssertNil(config.featureToggles, "FeatureToggles must be `nil` if the key `featureToggles` is not found")
        
        let featureToggleManager = FeatureToggleManager()
        featureToggleManager.applyFeatureToggles(config.featureToggles)
        XCTAssertTrue(featureToggleManager.isFeatureEnabled(.shouldSendInAppShowError))
    }

    func test_SettingsConfig_withFeatureTogglesTypeError_shouldSetFeatureTogglesToNil() {
        let config = try! FeatureTogglesConfig.settingsFeatureTogglesTypeError.getConfig()

        XCTAssertNil(config.featureToggles, "FeatureToggles must be `nil` if the type of `featureToggles` is not a `Settings.FeatureToggles`")
        
        let featureToggleManager = FeatureToggleManager()
        featureToggleManager.applyFeatureToggles(config.featureToggles)
        XCTAssertTrue(featureToggleManager.isFeatureEnabled(.shouldSendInAppShowError))
    }

    func test_SettingsConfig_withFeatureTogglesMissingShouldSendInAppShowError_shouldDefaultToTrue() {
        let config = try! FeatureTogglesConfig.settingsFeatureTogglesShouldSendInAppShowErrorMissing.getConfig()

        XCTAssertNotNil(config.featureToggles, "FeatureToggles must be successfully parsed")
        
        let featureToggleManager = FeatureToggleManager()
        featureToggleManager.applyFeatureToggles(config.featureToggles)
        XCTAssertTrue(featureToggleManager.isFeatureEnabled(.shouldSendInAppShowError))
    }

    func test_SettingsConfig_withFeatureTogglesShouldSendInAppShowErrorTypeError_shouldDefaultToTrue() {
        let config = try! FeatureTogglesConfig.settingsFeatureTogglesShouldSendInAppShowErrorTypeError.getConfig()

        XCTAssertNotNil(config.featureToggles, "FeatureToggles must be successfully parsed")

        let featureToggleManager = FeatureToggleManager()
        featureToggleManager.applyFeatureToggles(config.featureToggles)
        XCTAssertTrue(featureToggleManager.isFeatureEnabled(.shouldSendInAppShowError))
    }

    // MARK: - FeatureToggles: MobileSdkShouldSendInAppTags

    func test_SettingsConfig_withFeatureTogglesTagsTrue_shouldParseSuccessfully() {
        let config = try! FeatureTogglesConfig.configWithSettings.getConfig()

        XCTAssertNotNil(config.featureToggles, "FeatureToggles must be successfully parsed")
        XCTAssertEqual(config.featureToggles?.shouldSendInAppTags, true, "shouldSendInAppTags must be true")

        let featureToggleManager = FeatureToggleManager()
        featureToggleManager.applyFeatureToggles(config.featureToggles)
        XCTAssertTrue(featureToggleManager.isFeatureEnabled(.shouldSendInAppTags))
    }

    func test_SettingsConfig_withFeatureTogglesTagsFalse_shouldParseSuccessfully() {
        let config = try! FeatureTogglesConfig.settingsFeatureTogglesShouldSendInAppTagsFalse.getConfig()

        XCTAssertNotNil(config.featureToggles, "FeatureToggles must be successfully parsed")
        XCTAssertEqual(config.featureToggles?.shouldSendInAppTags, false, "shouldSendInAppTags must be false")

        let featureToggleManager = FeatureToggleManager()
        featureToggleManager.applyFeatureToggles(config.featureToggles)
        XCTAssertFalse(featureToggleManager.isFeatureEnabled(.shouldSendInAppTags))
    }

    func test_SettingsConfig_withFeatureTogglesMissingShouldSendInAppTags_shouldDefaultToTrue() {
        let config = try! FeatureTogglesConfig.settingsFeatureTogglesShouldSendInAppShowErrorMissing.getConfig()

        XCTAssertNotNil(config.featureToggles, "FeatureToggles must be successfully parsed")

        let featureToggleManager = FeatureToggleManager()
        featureToggleManager.applyFeatureToggles(config.featureToggles)
        XCTAssertTrue(featureToggleManager.isFeatureEnabled(.shouldSendInAppTags))
    }

    func test_SettingsConfig_withFeatureTogglesShouldSendInAppTagsTypeError_shouldDefaultToTrue() {
        let config = try! FeatureTogglesConfig.settingsFeatureTogglesShouldSendInAppTagsTypeError.getConfig()

        XCTAssertNotNil(config.featureToggles, "FeatureToggles must be successfully parsed")

        let featureToggleManager = FeatureToggleManager()
        featureToggleManager.applyFeatureToggles(config.featureToggles)
        XCTAssertTrue(featureToggleManager.isFeatureEnabled(.shouldSendInAppTags))
    }
}
