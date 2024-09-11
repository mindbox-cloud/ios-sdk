//
//  SettingsConfigParsingTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 9/11/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

fileprivate enum SettingsConfig: String, Configurable {
    typealias DecodeType = Settings
    
    case configWithSettings = "SettingsConfig"
    
    // Operations file names
    
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
    
    // TTL file names
    
    case ttlError = "SettingsTtlError"
    case ttlTypeError = "SettingsTtlTypeError"
    
    case ttlInappsError = "SettingsTtlInappsError"
    case ttlInappsTypeError = "SettingsTtlInappsTypeError"
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
    }
    
    func test_SettingsConfig_withOperationsTypeError_shouldSetOperationsToNil() {
        let config = try! SettingsConfig.settingsOperationsTypeError.getConfig()
        XCTAssertNil(config.operations, "Operations must be `nil` if the type of `operations` is not a `SettingsOperations`")
        XCTAssertNil(config.operations?.viewProduct)
        XCTAssertNil(config.operations?.viewCategory)
        XCTAssertNil(config.operations?.setCart)
        
        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.ttl?.inapps, "TTL must be successfully parsed")
    }
    
    func test_SettingsConfig_withOperationsViewProductError_shouldSetViewProductToNil() {
        let config = try! SettingsConfig.settingsOperationsViewProductError.getConfig()
        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNil(config.operations?.viewProduct, "ViewProduct must be `nil` if the key `viewProduct` is not found")
        XCTAssertNotNil(config.operations?.viewCategory)
        XCTAssertNotNil(config.operations?.setCart)
        
        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.ttl?.inapps, "TTL must be successfully parsed")
    }
    
    func test_SettingsConfig_withOperationsViewProductTypeError_shouldSetViewProductToNil() {
        let config = try! SettingsConfig.settingsOperationsViewProductTypeError.getConfig()
        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNil(config.operations?.viewProduct, "ViewProduct must be `nil` if the type of `viewProduct` is not an `Operation`")
        XCTAssertNotNil(config.operations?.viewCategory)
        XCTAssertNotNil(config.operations?.setCart)
        
        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.ttl?.inapps, "TTL must be successfully parsed")
    }
    
    func test_SettingsConfig_withOperationsViewProductSystemNameError_shouldSetViewProductToNil() {
        let config = try! SettingsConfig.settingsOperationsViewProductSystemNameError.getConfig()
        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNil(config.operations?.viewProduct, "ViewProduct must be `nil` if the key `systemName` is not found")
        XCTAssertNotNil(config.operations?.viewCategory)
        XCTAssertNotNil(config.operations?.setCart)
        
        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.ttl?.inapps, "TTL must be successfully parsed")
    }
    
    func test_SettingsConfig_withOperationsViewProductSystemNameTypeError_shouldSetViewProductToNil() {
        let config = try! SettingsConfig.settingsOperationsViewProductSystemNameTypeError.getConfig()
        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNil(config.operations?.viewProduct, "ViewProduct must be `nil` if the type of `systemName` is not a `String`")
        XCTAssertNotNil(config.operations?.viewCategory)
        XCTAssertNotNil(config.operations?.setCart)
        
        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.ttl?.inapps, "TTL must be successfully parsed")
    }
    
    func test_SettingsConfig_withAllOperationsWithErrors_shouldSetOperationsToNil() {
        let config = try! SettingsConfig.settingsAllOperationsWithErrors.getConfig()
        XCTAssertNil(config.operations, "Operations must be `nil` if all three operations are `nil`")
        XCTAssertNil(config.operations?.viewProduct)
        XCTAssertNil(config.operations?.viewCategory)
        XCTAssertNil(config.operations?.setCart)
        
        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.ttl?.inapps, "TTL must be successfully parsed")
    }
    
    func test_SettingsConfig_withAllOperationsWithTypeErrors_shouldSetOperationsToNil() {
        let config = try! SettingsConfig.settingsAllOperationsWithTypeErrors.getConfig()
        XCTAssertNil(config.operations, "Operations must be `nil` if all three operations are `nil`")
        XCTAssertNil(config.operations?.viewProduct)
        XCTAssertNil(config.operations?.viewCategory)
        XCTAssertNil(config.operations?.setCart)
        
        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.ttl?.inapps, "TTL must be successfully parsed")
    }
    
    func test_SettingsConfig_withOperationsViewCategoryAndSetCartError_shouldSetViewCategoryAndSetCartToNil() {
        let config = try! SettingsConfig.settingsOperationsViewCategoryAndSetCartError.getConfig()
        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNotNil(config.operations?.viewProduct, "ViewProduct must be successfully parsed")
        XCTAssertNil(config.operations?.viewCategory, "ViewCategory must be `nil` if the key `viewCategory` is not found")
        XCTAssertNil(config.operations?.setCart, "setCart must be `nil` if the key `setCart` is not found")
        
        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.ttl?.inapps, "TTL must be successfully parsed")
    }
    
    func test_SettingsConfig_withOperationsViewCategoryAndSetCartTypeError_shouldSetViewCategoryAndSetCartToNil() {
        let config = try! SettingsConfig.settingsOperationsViewCategoryAndSetCartTypeError.getConfig()
        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNotNil(config.operations?.viewProduct, "ViewProduct must be successfully parsed")
        XCTAssertNil(config.operations?.viewCategory, "ViewCategory must be `nil` if the type of `ViewCategory` is not a `SettingsOperations`")
        XCTAssertNil(config.operations?.setCart, "setCart must be `nil` if the type `setCart` is not a `SettingsOperations`")
        
        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.ttl?.inapps, "TTL must be successfully parsed")
    }
    
    func test_SettingsConfig_withOperationsViewCategoryAndSetCartSystemNameError_shouldSetViewCategoryAndSetCartToNil() {
        let config = try! SettingsConfig.settingsOperationsViewCategoryAndSetCartSystemNameError.getConfig()
        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNotNil(config.operations?.viewProduct, "ViewProduct must be successfully parsed")
        XCTAssertNil(config.operations?.viewCategory, "ViewCategory must be `nil` if the key `systemName` is not found")
        XCTAssertNil(config.operations?.setCart, "setCart must be `nil` if the key `systemName` is not found")
        
        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.ttl?.inapps, "TTL must be successfully parsed")
    }
    
    func test_SettingsConfig_withOperationsViewCategoryAndSetCartSystemNameTypeError_shouldSetViewCategoryAndSetCartToNil() {
        let config = try! SettingsConfig.settingsOperationsViewCategoryAndSetCartSystemNameTypeError.getConfig()
        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNotNil(config.operations?.viewProduct, "ViewProduct must be successfully parsed")
        XCTAssertNil(config.operations?.viewCategory, "ViewCategory must be `nil` if the type of `systemName` is not a `String`")
        XCTAssertNil(config.operations?.setCart, "setCart must be `nil` if the type `systemName` is not a `String`")
        
        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.ttl?.inapps, "TTL must be successfully parsed")
    }
    
    func test_SettingsConfig_withOperationsViewCategoryAndSetCartSystemNameMixedError_shouldSetViewCategoryAndSetCartToNil() {
        let config = try! SettingsConfig.settingsOperationsViewCategoryAndSetCartSystemNameMixedError.getConfig()
        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNotNil(config.operations?.viewProduct, "ViewProduct must be successfully parsed")
        XCTAssertNil(config.operations?.viewCategory, "ViewCategory must be `nil` if the key `systemName` is not found")
        XCTAssertNil(config.operations?.setCart, "setCart must be `nil` if the type `systemName` is not a `String`")
        
        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.ttl?.inapps, "TTL must be successfully parsed")
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
    }
    
    func test_SettingsConfig_withTtlTypeError_shouldSetTtlToNil() {
        let config = try! SettingsConfig.ttlTypeError.getConfig()
        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNotNil(config.operations?.viewProduct)
        XCTAssertNotNil(config.operations?.viewCategory)
        XCTAssertNotNil(config.operations?.setCart)
        
        XCTAssertNil(config.ttl, "TTL must be `nil` if the type of `inapps` is not a `TimeToLive`")
        XCTAssertNil(config.ttl?.inapps, "TTL must be nil")
    }
    
    func test_SettingsConfig_withTtlInappsError_shouldSetTtlToNil() {
        let config = try! SettingsConfig.ttlInappsError.getConfig()
        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNotNil(config.operations?.viewProduct)
        XCTAssertNotNil(config.operations?.viewCategory)
        XCTAssertNotNil(config.operations?.setCart)
        
        XCTAssertNil(config.ttl, "TTL must be `nil` if the key `inapps` is not found")
        XCTAssertNil(config.ttl?.inapps, "TTL must be nil")
    }
    
    func test_SettingsConfig_withTtlInappsTypeError_shouldSetTtlToNil() {
        let config = try! SettingsConfig.ttlInappsTypeError.getConfig()
        XCTAssertNotNil(config.operations)
        XCTAssertNotNil(config.operations?.viewProduct)
        XCTAssertNotNil(config.operations?.viewCategory)
        XCTAssertNotNil(config.operations?.setCart)
        
        XCTAssertNil(config.ttl, "TTL must be `nil` if the key `inapps` is not a `String`")
        XCTAssertNil(config.ttl?.inapps, "TTL must be `nil` if the key `inapps` is not a `String`")
    }
}
