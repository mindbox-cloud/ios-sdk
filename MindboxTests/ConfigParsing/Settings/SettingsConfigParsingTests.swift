//
//  SettingsConfigParsingTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 9/11/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

// swiftlint:disable force_try line_length

fileprivate enum SettingsConfig: String, Configurable {
    typealias DecodeType = Settings

    case configWithSettings = "SettingsConfig"

    case settingsOperationsError = "SettingsOperationsError"
    case settingsOperationsTypeError = "SettingsOperationsTypeError"

    case settingsOperationsViewProductError = "SettingsOperationsViewProductError"
    case settingsOperationsViewProductTypeError = "SettingsOperationsViewProductTypeError"

    case settingsOperationsViewProductSystemNameError = "SettingsOperationsViewProductSystemNameError"
    case settingsOperationsViewProductSystemNameTypeError = "SettingsOperationsViewProductSystemNameTypeError"

    case settingsAllOperationsWithErrors = "SettingsAllOperationsWithErrors"
    case settingsAllOperationsWithTypeErrors = "SettingsAllOperationsWithTypeErrors"

    case settingsOperationsViewCategoryAndSetCartError = "SettingsOperationsViewCategoryAndSetCartError"
    case settingsOperationsViewCategoryAndSetCartTypeError = "SettingsOperationsViewCategoryAndSetCartTypeError"
    case settingsOperationsViewCategoryAndSetCartSystemNameError = "SettingsOperationsViewCategoryAndSetCartSystemNameError"
    case settingsOperationsViewCategoryAndSetCartSystemNameTypeError = "SettingsOperationsViewCategoryAndSetCartSystemNameTypeError"
    case settingsOperationsViewCategoryAndSetCartSystemNameMixedError = "SettingsOperationsViewCategoryAndSetCartSystemNameMixedError"

    case ttlError = "SettingsTtlError"
    case ttlTypeError = "SettingsTtlTypeError"

    case ttlInappsError = "SettingsTtlInappsError"
    case ttlInappsTypeError = "SettingsTtlInappsTypeError"
    
    case settingsSlidingExpirationError = "SettingsSlidingExpirationError"
    case settingsSlidingExpirationTypeError = "SettingsSlidingExpirationTypeError"
    
    case settingsSlidingExpirationConfigError = "SettingsSlidingExpirationConfigError"
    case settingsSlidingExpirationConfigTypeError = "SettingsSlidingExpirationConfigTypeError"
    
    case settingsSlidingExpirationPushTokenError = "SettingsSlidingExpirationPushTokenKeepaliveError"
    case settingsSlidingExpirationPushTokenTypeError = "SettingsSlidingExpirationPushTokenKeepaliveTypeError"

    case settingsInAppSettingsError = "SettingsInAppSettingsError"
    case settingsInAppSettingsTypeError = "SettingsInAppSettingsTypeError"
    case settingsInAppSettingsPartialError = "SettingsInAppSettingsPartialError"
    case settingsInAppSettingsMissingMaxInappsPerSession = "SettingsInAppSettingsMissingMaxInappsPerSession"
    case settingsInAppSettingsMissingMaxInappsPerDay = "SettingsInAppSettingsMissingMaxInappsPerDay"
    case settingsInAppSettingsMissingMinIntervalBetweenShows = "SettingsInAppSettingsMissingMinIntervalBetweenShows"
    case settingsInAppSettingsTypeErrors = "SettingsInAppSettingsTypeErrors"

    case settingsBaseAddressesError = "SettingsBaseAddressesError"
    case settingsBaseAddressesTypeError = "SettingsBaseAddressesTypeError"
    case settingsBaseAddressesOperationsError = "SettingsBaseAddressesOperationsError"
    case settingsBaseAddressesOperationsTypeError = "SettingsBaseAddressesOperationsTypeError"

}

final class SettingsConfigParsingTests: XCTestCase {

    // MARK: Settings

    func test_SettingsConfig_shouldParseSuccessfully() {
        let config = try! SettingsConfig.configWithSettings.getConfig()
        XCTAssertNotNil(config.operations)
        XCTAssertNotNil(config.operations?.viewProduct)
        XCTAssertNotNil(config.operations?.viewCategory)
        XCTAssertNotNil(config.operations?.setCart)

        XCTAssertNotNil(config.ttl)
        XCTAssertNotNil(config.ttl?.inapps)
        
        XCTAssertNotNil(config.slidingExpiration)
        XCTAssertNotNil(config.slidingExpiration?.config)
        XCTAssertNotNil(config.slidingExpiration?.pushTokenKeepalive)
        
        XCTAssertNotNil(config.inapp, "InAppSettings must be successfully parsed")
        XCTAssertEqual(config.inapp?.maxInappsPerSession, 1, "maxInappsPerSession must be parsed correctly")
        XCTAssertEqual(config.inapp?.maxInappsPerDay, 1, "maxInappsPerDay must be parsed correctly")
        XCTAssertEqual(config.inapp?.minIntervalBetweenShows, "0.00:00:10", "minIntervalBetweenShows must be parsed correctly")

        XCTAssertNotNil(config.featureToggles, "FeatureToggles must be successfully parsed")
        XCTAssertEqual(config.featureToggles?.shouldSendInAppShowError, true, "shouldSendInAppShowError must be parsed correctly")

        XCTAssertNotNil(config.baseAddresses, "BaseAddresses must be successfully parsed")
        XCTAssertEqual(config.baseAddresses?.operations, "anonymizer-demo-api-regular.mindbox.ru", "operations must be parsed correctly")
    }

    // MARK: - Operations

    func test_SettingsConfig_withOperationsError_shouldSetOperationsToNil() {
        let config = try! SettingsConfig.settingsOperationsError.getConfig()
        XCTAssertNil(config.operations, "Operations must be `nil` if the key `operations` is not found")
        XCTAssertNil(config.operations?.viewProduct)
        XCTAssertNil(config.operations?.viewCategory)
        XCTAssertNil(config.operations?.setCart)

        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.ttl?.inapps, "TTL must be successfully parsed")
        
        XCTAssertNotNil(config.slidingExpiration, "SlidingExpiration must be successfully parsed")
        XCTAssertNotNil(config.slidingExpiration?.config, "SlidingExpiration must be successfully parsed")
    }

    func test_SettingsConfig_withOperationsTypeError_shouldSetOperationsToNil() {
        let config = try! SettingsConfig.settingsOperationsTypeError.getConfig()
        XCTAssertNil(config.operations, "Operations must be `nil` if the type of `operations` is not a `SettingsOperations`")
        XCTAssertNil(config.operations?.viewProduct)
        XCTAssertNil(config.operations?.viewCategory)
        XCTAssertNil(config.operations?.setCart)

        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.ttl?.inapps, "TTL must be successfully parsed")
        
        XCTAssertNotNil(config.slidingExpiration, "SlidingExpiration must be successfully parsed")
        XCTAssertNotNil(config.slidingExpiration?.config, "SlidingExpiration must be successfully parsed")
    }

    func test_SettingsConfig_withOperationsViewProductError_shouldSetViewProductToNil() {
        let config = try! SettingsConfig.settingsOperationsViewProductError.getConfig()
        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNil(config.operations?.viewProduct, "ViewProduct must be `nil` if the key `viewProduct` is not found")
        XCTAssertNotNil(config.operations?.viewCategory)
        XCTAssertNotNil(config.operations?.setCart)

        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.ttl?.inapps, "TTL must be successfully parsed")
        
        XCTAssertNotNil(config.slidingExpiration, "SlidingExpiration must be successfully parsed")
        XCTAssertNotNil(config.slidingExpiration?.config, "SlidingExpiration must be successfully parsed")
    }

    func test_SettingsConfig_withOperationsViewProductTypeError_shouldSetViewProductToNil() {
        let config = try! SettingsConfig.settingsOperationsViewProductTypeError.getConfig()
        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNil(config.operations?.viewProduct, "ViewProduct must be `nil` if the type of `viewProduct` is not an `Operation`")
        XCTAssertNotNil(config.operations?.viewCategory)
        XCTAssertNotNil(config.operations?.setCart)

        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.ttl?.inapps, "TTL must be successfully parsed")
        
        XCTAssertNotNil(config.slidingExpiration, "SlidingExpiration must be successfully parsed")
        XCTAssertNotNil(config.slidingExpiration?.config, "SlidingExpiration must be successfully parsed")
    }

    func test_SettingsConfig_withOperationsViewProductSystemNameError_shouldSetViewProductToNil() {
        let config = try! SettingsConfig.settingsOperationsViewProductSystemNameError.getConfig()
        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNil(config.operations?.viewProduct, "ViewProduct must be `nil` if the key `systemName` is not found")
        XCTAssertNotNil(config.operations?.viewCategory)
        XCTAssertNotNil(config.operations?.setCart)

        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.ttl?.inapps, "TTL must be successfully parsed")
        
        XCTAssertNotNil(config.slidingExpiration, "SlidingExpiration must be successfully parsed")
        XCTAssertNotNil(config.slidingExpiration?.config, "SlidingExpiration must be successfully parsed")
    }

    func test_SettingsConfig_withOperationsViewProductSystemNameTypeError_shouldSetViewProductToNil() {
        let config = try! SettingsConfig.settingsOperationsViewProductSystemNameTypeError.getConfig()
        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNil(config.operations?.viewProduct, "ViewProduct must be `nil` if the type of `systemName` is not a `String`")
        XCTAssertNotNil(config.operations?.viewCategory)
        XCTAssertNotNil(config.operations?.setCart)

        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.ttl?.inapps, "TTL must be successfully parsed")
        
        XCTAssertNotNil(config.slidingExpiration, "SlidingExpiration must be successfully parsed")
        XCTAssertNotNil(config.slidingExpiration?.config, "SlidingExpiration must be successfully parsed")
    }

    func test_SettingsConfig_withAllOperationsWithErrors_shouldSetOperationsToNil() {
        let config = try! SettingsConfig.settingsAllOperationsWithErrors.getConfig()
        XCTAssertNil(config.operations, "Operations must be `nil` if all three operations are `nil`")
        XCTAssertNil(config.operations?.viewProduct)
        XCTAssertNil(config.operations?.viewCategory)
        XCTAssertNil(config.operations?.setCart)

        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.ttl?.inapps, "TTL must be successfully parsed")
        
        XCTAssertNotNil(config.slidingExpiration, "SlidingExpiration must be successfully parsed")
        XCTAssertNotNil(config.slidingExpiration?.config, "SlidingExpiration must be successfully parsed")
    }

    func test_SettingsConfig_withAllOperationsWithTypeErrors_shouldSetOperationsToNil() {
        let config = try! SettingsConfig.settingsAllOperationsWithTypeErrors.getConfig()
        XCTAssertNil(config.operations, "Operations must be `nil` if all three operations are `nil`")
        XCTAssertNil(config.operations?.viewProduct)
        XCTAssertNil(config.operations?.viewCategory)
        XCTAssertNil(config.operations?.setCart)

        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.ttl?.inapps, "TTL must be successfully parsed")
        
        XCTAssertNotNil(config.slidingExpiration, "SlidingExpiration must be successfully parsed")
        XCTAssertNotNil(config.slidingExpiration?.config, "SlidingExpiration must be successfully parsed")
    }

    func test_SettingsConfig_withOperationsViewCategoryAndSetCartError_shouldSetViewCategoryAndSetCartToNil() {
        let config = try! SettingsConfig.settingsOperationsViewCategoryAndSetCartError.getConfig()
        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNotNil(config.operations?.viewProduct, "ViewProduct must be successfully parsed")
        XCTAssertNil(config.operations?.viewCategory, "ViewCategory must be `nil` if the key `viewCategory` is not found")
        XCTAssertNil(config.operations?.setCart, "setCart must be `nil` if the key `setCart` is not found")

        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.ttl?.inapps, "TTL must be successfully parsed")
        
        XCTAssertNotNil(config.slidingExpiration, "SlidingExpiration must be successfully parsed")
        XCTAssertNotNil(config.slidingExpiration?.config, "SlidingExpiration must be successfully parsed")
    }

    func test_SettingsConfig_withOperationsViewCategoryAndSetCartTypeError_shouldSetViewCategoryAndSetCartToNil() {
        let config = try! SettingsConfig.settingsOperationsViewCategoryAndSetCartTypeError.getConfig()
        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNotNil(config.operations?.viewProduct, "ViewProduct must be successfully parsed")
        XCTAssertNil(config.operations?.viewCategory, "ViewCategory must be `nil` if the type of `ViewCategory` is not a `SettingsOperations`")
        XCTAssertNil(config.operations?.setCart, "setCart must be `nil` if the type `setCart` is not a `SettingsOperations`")

        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.ttl?.inapps, "TTL must be successfully parsed")
        
        XCTAssertNotNil(config.slidingExpiration, "SlidingExpiration must be successfully parsed")
        XCTAssertNotNil(config.slidingExpiration?.config, "SlidingExpiration must be successfully parsed")
    }

    func test_SettingsConfig_withOperationsViewCategoryAndSetCartSystemNameError_shouldSetViewCategoryAndSetCartToNil() {
        let config = try! SettingsConfig.settingsOperationsViewCategoryAndSetCartSystemNameError.getConfig()
        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNotNil(config.operations?.viewProduct, "ViewProduct must be successfully parsed")
        XCTAssertNil(config.operations?.viewCategory, "ViewCategory must be `nil` if the key `systemName` is not found")
        XCTAssertNil(config.operations?.setCart, "setCart must be `nil` if the key `systemName` is not found")

        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.ttl?.inapps, "TTL must be successfully parsed")
        
        XCTAssertNotNil(config.slidingExpiration, "SlidingExpiration must be successfully parsed")
        XCTAssertNotNil(config.slidingExpiration?.config, "SlidingExpiration must be successfully parsed")
    }

    func test_SettingsConfig_withOperationsViewCategoryAndSetCartSystemNameTypeError_shouldSetViewCategoryAndSetCartToNil() {
        let config = try! SettingsConfig.settingsOperationsViewCategoryAndSetCartSystemNameTypeError.getConfig()
        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNotNil(config.operations?.viewProduct, "ViewProduct must be successfully parsed")
        XCTAssertNil(config.operations?.viewCategory, "ViewCategory must be `nil` if the type of `systemName` is not a `String`")
        XCTAssertNil(config.operations?.setCart, "setCart must be `nil` if the type `systemName` is not a `String`")

        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.ttl?.inapps, "TTL must be successfully parsed")
        
        XCTAssertNotNil(config.slidingExpiration, "SlidingExpiration must be successfully parsed")
        XCTAssertNotNil(config.slidingExpiration?.config, "SlidingExpiration must be successfully parsed")
    }

    func test_SettingsConfig_withOperationsViewCategoryAndSetCartSystemNameMixedError_shouldSetViewCategoryAndSetCartToNil() {
        let config = try! SettingsConfig.settingsOperationsViewCategoryAndSetCartSystemNameMixedError.getConfig()
        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNotNil(config.operations?.viewProduct, "ViewProduct must be successfully parsed")
        XCTAssertNil(config.operations?.viewCategory, "ViewCategory must be `nil` if the key `systemName` is not found")
        XCTAssertNil(config.operations?.setCart, "setCart must be `nil` if the type `systemName` is not a `String`")

        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.ttl?.inapps, "TTL must be successfully parsed")
        
        XCTAssertNotNil(config.slidingExpiration, "SlidingExpiration must be successfully parsed")
        XCTAssertNotNil(config.slidingExpiration?.config, "SlidingExpiration must be successfully parsed")
    }

    // MARK: - TTL

    func test_SettingsConfig_withTtlError_shouldSetTtlToNil() {
        let config = try! SettingsConfig.ttlError.getConfig()
        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNotNil(config.operations?.viewProduct)
        XCTAssertNotNil(config.operations?.viewCategory)
        XCTAssertNotNil(config.operations?.setCart)

        XCTAssertNil(config.ttl, "TTL must be `nil` if the key `ttl` is not found")
        XCTAssertNil(config.ttl?.inapps, "TTL must be nil")
        
        XCTAssertNotNil(config.slidingExpiration, "SlidingExpiration must be successfully parsed")
        XCTAssertNotNil(config.slidingExpiration?.config, "SlidingExpiration must be successfully parsed")
    }

    func test_SettingsConfig_withTtlTypeError_shouldSetTtlToNil() {
        let config = try! SettingsConfig.ttlTypeError.getConfig()
        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNotNil(config.operations?.viewProduct)
        XCTAssertNotNil(config.operations?.viewCategory)
        XCTAssertNotNil(config.operations?.setCart)

        XCTAssertNil(config.ttl, "TTL must be `nil` if the type of `inapps` is not a `TimeToLive`")
        XCTAssertNil(config.ttl?.inapps, "TTL must be nil")
        
        XCTAssertNotNil(config.slidingExpiration, "SlidingExpiration must be successfully parsed")
        XCTAssertNotNil(config.slidingExpiration?.config, "SlidingExpiration must be successfully parsed")
    }

    func test_SettingsConfig_withTtlInappsError_shouldSetTtlToNil() {
        let config = try! SettingsConfig.ttlInappsError.getConfig()
        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNotNil(config.operations?.viewProduct)
        XCTAssertNotNil(config.operations?.viewCategory)
        XCTAssertNotNil(config.operations?.setCart)

        XCTAssertNil(config.ttl, "TTL must be `nil` if the key `inapps` is not found")
        XCTAssertNil(config.ttl?.inapps, "TTL must be nil")
        
        XCTAssertNotNil(config.slidingExpiration, "SlidingExpiration must be successfully parsed")
        XCTAssertNotNil(config.slidingExpiration?.config, "SlidingExpiration must be successfully parsed")
    }

    func test_SettingsConfig_withTtlInappsTypeError_shouldSetTtlToNil() {
        let config = try! SettingsConfig.ttlInappsTypeError.getConfig()
        XCTAssertNotNil(config.operations)
        XCTAssertNotNil(config.operations?.viewProduct)
        XCTAssertNotNil(config.operations?.viewCategory)
        XCTAssertNotNil(config.operations?.setCart)

        XCTAssertNil(config.ttl, "TTL must be `nil` if the key `inapps` is not a `String`")
        XCTAssertNil(config.ttl?.inapps, "TTL must be `nil` if the key `inapps` is not a `String`")
        
        XCTAssertNotNil(config.slidingExpiration, "SlidingExpiration must be successfully parsed")
        XCTAssertNotNil(config.slidingExpiration?.config, "SlidingExpiration must be successfully parsed")
    }
    
    // MARK: - Sliding Expiration
    
    func test_SettingsConfig_withSlidingExpirationError_shouldSetSlidingExpirationToNil() {
        let config = try! SettingsConfig.settingsSlidingExpirationError.getConfig()

        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")

        XCTAssertNil(config.slidingExpiration, "SlidingExpiration must be `nil` if the key `slidingExpiration` is not found")
        XCTAssertNil(config.slidingExpiration?.config)
        XCTAssertNil(config.slidingExpiration?.pushTokenKeepalive)
    }

    func test_SettingsConfig_withSlidingExpirationTypeError_shouldSetSlidingExpirationToNil() {
        let config = try! SettingsConfig.settingsSlidingExpirationTypeError.getConfig()

        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")

        XCTAssertNil(config.slidingExpiration, "SlidingExpiration must be `nil` if the key `slidingExpiration` is not a `Settings.SlidingExpiration`")
        XCTAssertNil(config.slidingExpiration?.config)
        XCTAssertNil(config.slidingExpiration?.pushTokenKeepalive)
    }

    func test_SettingsConfig_withSlidingExpirationInappSessionError_shouldSetConfigToNil() {
        let config = try! SettingsConfig.settingsSlidingExpirationConfigError.getConfig()

        XCTAssertNotNil(config.operations)
        XCTAssertNotNil(config.ttl)

        XCTAssertNotNil(config.slidingExpiration, "SlidingExpiration must be successfully parsed")
        
        XCTAssertNil(config.slidingExpiration?.config, "Config must be `nil` if the key `config` is not found")
        XCTAssertNotNil(config.slidingExpiration?.pushTokenKeepalive)
    }

    func test_SettingsConfig_withSlidingExpirationInappSessionTypeError_shouldSetConfigToNil() {
        let config = try! SettingsConfig.settingsSlidingExpirationConfigTypeError.getConfig()

        XCTAssertNotNil(config.operations)
        XCTAssertNotNil(config.ttl)

        XCTAssertNotNil(config.slidingExpiration, "SlidingExpiration must be successfully parsed")
        
        XCTAssertNil(config.slidingExpiration?.config, "Config must be `nil` if the key `config` is not a String")
        XCTAssertNotNil(config.slidingExpiration?.pushTokenKeepalive)
    }
    
    func test_SettingsConfig_withSlidingExpirationPushTokenKeepaliveError_shouldSetPushTokenToNil() {
        let config = try! SettingsConfig.settingsSlidingExpirationPushTokenError.getConfig()
        
        XCTAssertNotNil(config.operations)
        XCTAssertNotNil(config.ttl)
        
        XCTAssertNotNil(config.slidingExpiration, "SlidingExpiration must be successfully parsed")
        XCTAssertNotNil(config.slidingExpiration?.config)
        XCTAssertNil(config.slidingExpiration?.pushTokenKeepalive, "PushTokenKeepalive must be `nil` if the key `pushTokenKeepalive` is not found")
    }
    
    func test_SettingsConfig_withSlidingExpirationPushTokenKeepaliveTypeError_shouldSetPushTokenToNil() {
        let config = try! SettingsConfig.settingsSlidingExpirationPushTokenTypeError.getConfig()
        
        XCTAssertNotNil(config.operations)
        XCTAssertNotNil(config.ttl)
        
        XCTAssertNotNil(config.slidingExpiration, "SlidingExpiration must be successfully parsed")
        XCTAssertNotNil(config.slidingExpiration?.config)
        XCTAssertNil(config.slidingExpiration?.pushTokenKeepalive, "PushTokenKeepalive must be `nil` if the key `pushTokenKeepalive` is not a String")
    }

    // MARK: - InApp Settings
    
    func test_SettingsConfig_withInAppSettingsError_shouldSetInAppSettingsToNil() {
        let config = try! SettingsConfig.settingsInAppSettingsError.getConfig()
        
        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.slidingExpiration, "SlidingExpiration must be successfully parsed")
        
        XCTAssertNil(config.inapp, "InAppSettings must be `nil` if the key `inapp` is not found")
        XCTAssertNil(config.inapp?.maxInappsPerSession)
        XCTAssertNil(config.inapp?.maxInappsPerDay)
        XCTAssertNil(config.inapp?.minIntervalBetweenShows)
    }
    
    func test_SettingsConfig_withInAppSettingsTypeError_shouldSetInAppSettingsToNil() {
        let config = try! SettingsConfig.settingsInAppSettingsTypeError.getConfig()
        
        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.slidingExpiration, "SlidingExpiration must be successfully parsed")
        
        XCTAssertNil(config.inapp, "InAppSettings must be `nil` if the type of `inapp` is not a `Settings.InAppSettings`")
        XCTAssertNil(config.inapp?.maxInappsPerSession)
        XCTAssertNil(config.inapp?.maxInappsPerDay)
        XCTAssertNil(config.inapp?.minIntervalBetweenShows)
    }
    
    func test_SettingsConfig_withInAppSettingsPartialError_shouldKeepValidValues() {
        let config = try! SettingsConfig.settingsInAppSettingsPartialError.getConfig()
        
        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.slidingExpiration, "SlidingExpiration must be successfully parsed")
        
        XCTAssertNotNil(config.inapp, "InAppSettings must be successfully parsed")
        XCTAssertEqual(config.inapp?.maxInappsPerSession, 1, "maxInappsPerSession must be parsed correctly")
        XCTAssertNil(config.inapp?.maxInappsPerDay, "maxInappsPerDay must be nil due to type error")
        XCTAssertNil(config.inapp?.minIntervalBetweenShows, "minIntervalBetweenShows must be nil as it's missing")
    }
    
    func test_SettingsConfig_withInAppSettingsMissingMaxInappsPerSession_shouldKeepOtherValues() {
        let config = try! SettingsConfig.settingsInAppSettingsMissingMaxInappsPerSession.getConfig()
        
        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.slidingExpiration, "SlidingExpiration must be successfully parsed")
        
        XCTAssertNotNil(config.inapp, "InAppSettings must be successfully parsed")
        XCTAssertNil(config.inapp?.maxInappsPerSession, "maxInappsPerSession must be nil as it's missing")
        XCTAssertEqual(config.inapp?.maxInappsPerDay, 1, "maxInappsPerDay must be parsed correctly")
        XCTAssertEqual(config.inapp?.minIntervalBetweenShows, "0.00:00:10", "minIntervalBetweenShows must be parsed correctly")
    }
    
    func test_SettingsConfig_withInAppSettingsMissingMaxInappsPerDay_shouldKeepOtherValues() {
        let config = try! SettingsConfig.settingsInAppSettingsMissingMaxInappsPerDay.getConfig()
        
        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.slidingExpiration, "SlidingExpiration must be successfully parsed")
        
        XCTAssertNotNil(config.inapp, "InAppSettings must be successfully parsed")
        XCTAssertEqual(config.inapp?.maxInappsPerSession, 1, "maxInappsPerSession must be parsed correctly")
        XCTAssertNil(config.inapp?.maxInappsPerDay, "maxInappsPerDay must be nil as it's missing")
        XCTAssertEqual(config.inapp?.minIntervalBetweenShows, "0.00:00:10", "minIntervalBetweenShows must be parsed correctly")
    }
    
    func test_SettingsConfig_withInAppSettingsMissingMinIntervalBetweenShows_shouldKeepOtherValues() {
        let config = try! SettingsConfig.settingsInAppSettingsMissingMinIntervalBetweenShows.getConfig()
        
        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.slidingExpiration, "SlidingExpiration must be successfully parsed")
        
        XCTAssertNotNil(config.inapp, "InAppSettings must be successfully parsed")
        XCTAssertEqual(config.inapp?.maxInappsPerSession, 1, "maxInappsPerSession must be parsed correctly")
        XCTAssertEqual(config.inapp?.maxInappsPerDay, 1, "maxInappsPerDay must be parsed correctly")
        XCTAssertNil(config.inapp?.minIntervalBetweenShows, "minIntervalBetweenShows must be nil as it's missing")
    }
    
    func test_SettingsConfig_withInAppSettingsTypeErrors_shouldSetAllValuesToNil() {
        let config = try! SettingsConfig.settingsInAppSettingsTypeErrors.getConfig()

        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.slidingExpiration, "SlidingExpiration must be successfully parsed")

        XCTAssertNil(config.inapp, "InAppSettings must be nil")
        XCTAssertNil(config.inapp?.maxInappsPerSession, "maxInappsPerSession must be nil due to type error")
        XCTAssertNil(config.inapp?.maxInappsPerDay, "maxInappsPerDay must be nil due to type error")
        XCTAssertNil(config.inapp?.minIntervalBetweenShows, "minIntervalBetweenShows must be nil due to type error")
    }

    // MARK: - BaseAddresses

    func test_SettingsConfig_withBaseAddressesError_shouldSetBaseAddressesToNil() {
        let config = try! SettingsConfig.settingsBaseAddressesError.getConfig()
        XCTAssertNil(config.baseAddresses, "BaseAddresses must be `nil` if the key `baseAddresses` is not found")

        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.slidingExpiration, "SlidingExpiration must be successfully parsed")
        XCTAssertNotNil(config.inapp, "InAppSettings must be successfully parsed")
        XCTAssertNotNil(config.featureToggles, "FeatureToggles must be successfully parsed")
    }

    func test_SettingsConfig_withBaseAddressesTypeError_shouldSetBaseAddressesToNil() {
        let config = try! SettingsConfig.settingsBaseAddressesTypeError.getConfig()
        XCTAssertNil(config.baseAddresses, "BaseAddresses must be `nil` if the type of `baseAddresses` is not a `BaseAddresses`")

        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.slidingExpiration, "SlidingExpiration must be successfully parsed")
        XCTAssertNotNil(config.inapp, "InAppSettings must be successfully parsed")
        XCTAssertNotNil(config.featureToggles, "FeatureToggles must be successfully parsed")
    }

    func test_SettingsConfig_withBaseAddressesOperationsError_shouldSetOperationsToNil() {
        let config = try! SettingsConfig.settingsBaseAddressesOperationsError.getConfig()
        XCTAssertNotNil(config.baseAddresses, "BaseAddresses must be successfully parsed")
        XCTAssertNil(config.baseAddresses?.operations, "operations must be `nil` if the key `operations` is not found")

        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.slidingExpiration, "SlidingExpiration must be successfully parsed")
    }

    func test_SettingsConfig_withBaseAddressesOperationsTypeError_shouldSetOperationsToNil() {
        let config = try! SettingsConfig.settingsBaseAddressesOperationsTypeError.getConfig()
        XCTAssertNotNil(config.baseAddresses, "BaseAddresses must be successfully parsed")
        XCTAssertNil(config.baseAddresses?.operations, "operations must be `nil` if the type of `operations` is not a `String`")

        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.slidingExpiration, "SlidingExpiration must be successfully parsed")
    }

}
