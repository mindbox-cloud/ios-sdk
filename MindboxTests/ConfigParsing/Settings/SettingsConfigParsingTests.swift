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
    
    case configWithSettings = "SettingsConfig" // Correct config
    
    // Operations file names
    
    case settingsOperationsError = "SettingsOperationsError" // Key is `operationsTests` instead of `operations`
    case settingsOperationsTypeError = "SettingsOperationsTypeError" // Type of `operations` is Int instead of `SettingsOperations`
    
    case settingsOperationsViewProductError = "SettingsOperationsViewProductError" // Key is `viewProductTest` instead of `viewProduct`
    case settingsOperationsViewProductTypeError = "SettingsOperationsViewProductTypeError" // Type of `viewProduct` is Int instead of Operation
    
    case settingsOperationsViewProductSystemNameError = "SettingsOperationsViewProductSystemNameError" // Key is `systemNameTest` instead of `systemName`
    case settingsOperationsViewProductSystemNameTypeError = "SettingsOperationsViewProductSystemNameTypeError" // Type of `systemName` is Int instead of String
    
    case settingsAllOperationsWithErrors = "SettingsAllOperationsWithErrors" // Keys are `viewProductTest`, `viewCategoryTest` and `setCartTest` instead of `viewProduct`, `viewCategory` and `setCart`
    case settingsAllOperationsWithTypeErrors = "SettingsAllOperationsWithTypeErrors" // Types of `viewProduct`, `viewCategory` and `setCart` are Int instead of String
    
    case settingsOperationsViewCategoryAndSetCartError = "SettingsOperationsViewCategoryAndSetCartError" // Keys are `viewCategoryTest` and `setCartTest` instead of `viewCategory` and `setCart`
    case settingsOperationsViewCategoryAndSetCartTypeError = "SettingsOperationsViewCategoryAndSetCartTypeError" // Types of `viewCategory` and `setCart` are Int instead of String
    case settingsOperationsViewCategoryAndSetCartSystemNameError = "SettingsOperationsViewCategoryAndSetCartSystemNameError" // Keys are `systemNameTest` instead of `systemName`
    case settingsOperationsViewCategoryAndSetCartSystemNameTypeError = "SettingsOperationsViewCategoryAndSetCartSystemNameTypeError" // Types of `systemName` are Int instead of String
    case settingsOperationsViewCategoryAndSetCartSystemNameMixedError = "SettingsOperationsViewCategoryAndSetCartSystemNameMixedError" // Key of `viewCategory` is `systemNameTest` instead of `systemName` and type of `setCart`:`systemName` is Int instead of String
    
    // TTL file names
    
    case ttlError = "SettingsTtlError" // Key `ttlTest` instead of `ttl`
    case ttlTypeError = "SettingsTtlTypeError" // Type of `ttl` is Int instead of TimeToLive
    
    case ttlInappsError = "SettingsTtlInappsError" // Key is `inappsTest` instead of `inapps`
    case ttlInappsTypeError = "SettingsTtlInappsTypeError" // Type of `ttl` is Int instead of String
}

final class SettingsConfigParsingTests: XCTestCase {

    // MARK: Settings
    
    func test_SettingsConfig_shouldParseSuccessfully() {
        // Correct config
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
        // Key is `operationsTests` instead of `operations`
        let config = try! SettingsConfig.settingsOperationsError.getConfig()
        XCTAssertNil(config.operations, "Operations must be `nil` if the key `operations` is not found")
        XCTAssertNil(config.operations?.viewProduct)
        XCTAssertNil(config.operations?.viewCategory)
        XCTAssertNil(config.operations?.setCart)
        
        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.ttl?.inapps, "TTL must be successfully parsed")
    }
    
    func test_SettingsConfig_withOperationsTypeError_shouldSetOperationsToNil() {
        // Type of `operations` is Int instead of `SettingsOperations`
        let config = try! SettingsConfig.settingsOperationsTypeError.getConfig()
        XCTAssertNil(config.operations, "Operations must be `nil` if the type of `operations` is not a `SettingsOperations`")
        XCTAssertNil(config.operations?.viewProduct)
        XCTAssertNil(config.operations?.viewCategory)
        XCTAssertNil(config.operations?.setCart)
        
        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.ttl?.inapps, "TTL must be successfully parsed")
    }
    
    func test_SettingsConfig_withOperationsViewProductError_shouldSetViewProductToNil() {
        // Key is `viewProductTest` instead of `viewProduct`
        let config = try! SettingsConfig.settingsOperationsViewProductError.getConfig()
        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNil(config.operations?.viewProduct, "ViewProduct must be `nil` if the key `viewProduct` is not found")
        XCTAssertNotNil(config.operations?.viewCategory)
        XCTAssertNotNil(config.operations?.setCart)
        
        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.ttl?.inapps, "TTL must be successfully parsed")
    }
    
    func test_SettingsConfig_withOperationsViewProductTypeError_shouldSetViewProductToNil() {
        // Type of `viewProduct` is Int instead of Operation
        let config = try! SettingsConfig.settingsOperationsViewProductTypeError.getConfig()
        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNil(config.operations?.viewProduct, "ViewProduct must be `nil` if the type of `viewProduct` is not an `Operation`")
        XCTAssertNotNil(config.operations?.viewCategory)
        XCTAssertNotNil(config.operations?.setCart)
        
        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.ttl?.inapps, "TTL must be successfully parsed")
    }
    
    func test_SettingsConfig_withOperationsViewProductSystemNameError_shouldSetViewProductToNil() {
        // Key is `systemNameTest` instead of `systemName`
        let config = try! SettingsConfig.settingsOperationsViewProductSystemNameError.getConfig()
        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNil(config.operations?.viewProduct, "ViewProduct must be `nil` if the key `systemName` is not found")
        XCTAssertNotNil(config.operations?.viewCategory)
        XCTAssertNotNil(config.operations?.setCart)
        
        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.ttl?.inapps, "TTL must be successfully parsed")
    }
    
    func test_SettingsConfig_withOperationsViewProductSystemNameTypeError_shouldSetViewProductToNil() {
        // Type of `systemName` is Int instead of String
        let config = try! SettingsConfig.settingsOperationsViewProductSystemNameTypeError.getConfig()
        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNil(config.operations?.viewProduct, "ViewProduct must be `nil` if the type of `systemName` is not a `String`")
        XCTAssertNotNil(config.operations?.viewCategory)
        XCTAssertNotNil(config.operations?.setCart)
        
        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.ttl?.inapps, "TTL must be successfully parsed")
    }
    
    func test_SettingsConfig_withAllOperationsWithErrors_shouldSetOperationsToNil() {
        // Keys are `viewProductTest`, `viewCategoryTest` and `setCartTest` instead of `viewProduct`, `viewCategory` and `setCart`
        let config = try! SettingsConfig.settingsAllOperationsWithErrors.getConfig()
        XCTAssertNil(config.operations, "Operations must be `nil` if all three operations are `nil`")
        XCTAssertNil(config.operations?.viewProduct)
        XCTAssertNil(config.operations?.viewCategory)
        XCTAssertNil(config.operations?.setCart)
        
        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.ttl?.inapps, "TTL must be successfully parsed")
    }
    
    func test_SettingsConfig_withAllOperationsWithTypeErrors_shouldSetOperationsToNil() {
        // Types of `viewProduct`, `viewCategory` and `setCart` are Int instead of String
        let config = try! SettingsConfig.settingsAllOperationsWithTypeErrors.getConfig()
        XCTAssertNil(config.operations, "Operations must be `nil` if all three operations are `nil`")
        XCTAssertNil(config.operations?.viewProduct)
        XCTAssertNil(config.operations?.viewCategory)
        XCTAssertNil(config.operations?.setCart)
        
        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.ttl?.inapps, "TTL must be successfully parsed")
    }
    
    func test_SettingsConfig_withOperationsViewCategoryAndSetCartError_shouldSetViewCategoryAndSetCartToNil() {
        // Keys are `viewCategoryTest` and `setCartTest` instead of `viewCategory` and `setCart`
        let config = try! SettingsConfig.settingsOperationsViewCategoryAndSetCartError.getConfig()
        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNotNil(config.operations?.viewProduct, "ViewProduct must be successfully parsed")
        XCTAssertNil(config.operations?.viewCategory, "ViewCategory must be `nil` if the key `viewCategory` is not found")
        XCTAssertNil(config.operations?.setCart, "setCart must be `nil` if the key `setCart` is not found")
        
        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.ttl?.inapps, "TTL must be successfully parsed")
    }
    
    func test_SettingsConfig_withOperationsViewCategoryAndSetCartTypeError_shouldSetViewCategoryAndSetCartToNil() {
        // Types of `viewCategory` and `setCart` are Int instead of String
        let config = try! SettingsConfig.settingsOperationsViewCategoryAndSetCartTypeError.getConfig()
        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNotNil(config.operations?.viewProduct, "ViewProduct must be successfully parsed")
        XCTAssertNil(config.operations?.viewCategory, "ViewCategory must be `nil` if the type of `ViewCategory` is not a `SettingsOperations`")
        XCTAssertNil(config.operations?.setCart, "setCart must be `nil` if the type `setCart` is not a `SettingsOperations`")
        
        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.ttl?.inapps, "TTL must be successfully parsed")
    }
    
    func test_SettingsConfig_withOperationsViewCategoryAndSetCartSystemNameError_shouldSetViewCategoryAndSetCartToNil() {
        // Keys are `systemNameTest` instead of `systemName`
        let config = try! SettingsConfig.settingsOperationsViewCategoryAndSetCartSystemNameError.getConfig()
        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNotNil(config.operations?.viewProduct, "ViewProduct must be successfully parsed")
        XCTAssertNil(config.operations?.viewCategory, "ViewCategory must be `nil` if the key `systemName` is not found")
        XCTAssertNil(config.operations?.setCart, "setCart must be `nil` if the key `systemName` is not found")
        
        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.ttl?.inapps, "TTL must be successfully parsed")
    }
    
    func test_SettingsConfig_withOperationsViewCategoryAndSetCartSystemNameTypeError_shouldSetViewCategoryAndSetCartToNil() {
        // Types of `systemName` are Int instead of String
        let config = try! SettingsConfig.settingsOperationsViewCategoryAndSetCartSystemNameTypeError.getConfig()
        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNotNil(config.operations?.viewProduct, "ViewProduct must be successfully parsed")
        XCTAssertNil(config.operations?.viewCategory, "ViewCategory must be `nil` if the type of `systemName` is not a `String`")
        XCTAssertNil(config.operations?.setCart, "setCart must be `nil` if the type `systemName` is not a `String`")
        
        XCTAssertNotNil(config.ttl, "TTL must be successfully parsed")
        XCTAssertNotNil(config.ttl?.inapps, "TTL must be successfully parsed")
    }
    
    func test_SettingsConfig_withOperationsViewCategoryAndSetCartSystemNameMixedError_shouldSetViewCategoryAndSetCartToNil() {
        // Key of `viewCategory` is `systemNameTest` instead of `systemName` and type of `setCart`:`systemName` is Int instead of String
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
        // Key `ttlTest` instead of `ttl`
        let config = try! SettingsConfig.ttlError.getConfig()
        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNotNil(config.operations?.viewProduct)
        XCTAssertNotNil(config.operations?.viewCategory)
        XCTAssertNotNil(config.operations?.setCart)
        
        XCTAssertNil(config.ttl, "TTL must be `nil` if the key `ttl` is not found")
        XCTAssertNil(config.ttl?.inapps, "TTL must be nil")
    }
    
    func test_SettingsConfig_withTtlTypeError_shouldSetTtlToNil() {
        // Type of `ttl` is Int instead of TimeToLive
        let config = try! SettingsConfig.ttlTypeError.getConfig()
        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNotNil(config.operations?.viewProduct)
        XCTAssertNotNil(config.operations?.viewCategory)
        XCTAssertNotNil(config.operations?.setCart)
        
        XCTAssertNil(config.ttl, "TTL must be `nil` if the type of `inapps` is not a `TimeToLive`")
        XCTAssertNil(config.ttl?.inapps, "TTL must be nil")
    }
    
    func test_SettingsConfig_withTtlInappsError_shouldSetTtlToNil() {
        // Key is `inappsTest` instead of `inapps`
        let config = try! SettingsConfig.ttlInappsError.getConfig()
        XCTAssertNotNil(config.operations, "Operations must be successfully parsed")
        XCTAssertNotNil(config.operations?.viewProduct)
        XCTAssertNotNil(config.operations?.viewCategory)
        XCTAssertNotNil(config.operations?.setCart)
        
        XCTAssertNil(config.ttl, "TTL must be `nil` if the key `inapps` is not found")
        XCTAssertNil(config.ttl?.inapps, "TTL must be nil")
    }
    
    func test_SettingsConfig_withTtlInappsTypeError_shouldSetTtlToNil() {
        // Type of `ttl` is Int instead of String
        let config = try! SettingsConfig.ttlInappsTypeError.getConfig()
        XCTAssertNotNil(config.operations)
        XCTAssertNotNil(config.operations?.viewProduct)
        XCTAssertNotNil(config.operations?.viewCategory)
        XCTAssertNotNil(config.operations?.setCart)
        
        XCTAssertNil(config.ttl, "TTL must be `nil` if the key `inapps` is not a `String`")
        XCTAssertNil(config.ttl?.inapps, "TTL must be `nil` if the key `inapps` is not a `String`")
    }
}
