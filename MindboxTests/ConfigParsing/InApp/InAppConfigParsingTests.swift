//
//  InAppConfigParsingTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 2/17/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

// swiftlint:disable force_try

fileprivate enum InAppConfig: String, Configurable {
    typealias DecodeType = ConfigResponse

    // MARK: - Level 1: InAppDTO fields

    // id
    case inAppIdError = "InAppIdError" // Key is `idTest` instead of `id`
    case inAppIdTypeError = "InAppIdTypeError" // Type of `id` is Int instead of String

    // sdkVersion
    case inAppSdkVersionError = "InAppSdkVersionError" // Key is `sdkVersionTest` instead of `sdkVersion`
    case inAppSdkVersionTypeError = "InAppSdkVersionTypeError" // Type of `sdkVersion` is Int instead of SDKVersion

    // frequency
    case inAppFrequencyError = "InAppFrequencyError" // Key is `frequencyTest` instead of `frequency`
    case inAppFrequencyTypeError = "InAppFrequencyTypeError" // Type of `frequency` is Int instead of Frequency
    case inAppFrequencyUnknownType = "InAppFrequencyUnknownType" // frequency.$type is unknown
    case inAppFrequencyNil = "InAppFrequencyNil" // frequency field is absent

    // targeting
    case inAppTargetingError = "InAppTargetingError" // Key is `targetingTest` instead of `targeting`
    case inAppTargetingTypeError = "InAppTargetingTypeError" // Type of `targeting` is Int instead of Targeting

    // form
    case inAppFormError = "InAppFormError" // Key is `formTest` instead of `form`
    case inAppFormTypeError = "InAppFormTypeError" // Type of `form` is Int instead of InAppFormDTO

    // delayTime
    case inAppDelayTimeTypeError = "InAppDelayTimeTypeError" // Type of `delayTime` is Int instead of String

    // FailableDecodableArray
    case inAppOneCorrupted = "InAppOneCorrupted" // Two InApps: first has broken id, second is valid

    // MARK: - Level 2: form.variants

    case inAppFormVariantsTypeError = "InAppFormVariantsTypeError" // form.variants is Int instead of array
    case inAppFormVariantMissingType = "InAppFormVariantMissingType" // variant has no $type field
    case inAppFormVariantUnknownType = "InAppFormVariantUnknownType" // variant.$type is unknown

    // MARK: - Level 3: background.layers

    case inAppLayersTypeError = "InAppLayersTypeError" // background.layers is Int instead of array
    case inAppLayerMissingType = "InAppLayerMissingType" // layer has no $type field
    case inAppLayerUnknownType = "InAppLayerUnknownType" // layer.$type is unknown

    // MARK: - Webview layer

    case inAppWebviewValid = "InAppWebviewValid" // Valid webview InApp with params
    case inAppWebviewParamsTypeError = "InAppWebviewParamsTypeError" // webview params is Int instead of object
}

final class InAppConfigParsingTests: XCTestCase {

    // MARK: - Level 1: InAppDTO fields

    // MARK: id

    func test_InApp_withIdError_shouldSkipInApp() {
        let config = try! InAppConfig.inAppIdError.getConfig()
        XCTAssertNotNil(config.inapps, "inapps array must NOT be nil")
        XCTAssertTrue(config.inapps!.elements.isEmpty, "InApp must be skipped when id key is invalid")
    }

    func test_InApp_withIdTypeError_shouldSkipInApp() {
        let config = try! InAppConfig.inAppIdTypeError.getConfig()
        XCTAssertNotNil(config.inapps)
        XCTAssertTrue(config.inapps!.elements.isEmpty, "InApp must be skipped when id has wrong type")
    }

    // MARK: sdkVersion

    func test_InApp_withSdkVersionError_shouldSkipInApp() {
        let config = try! InAppConfig.inAppSdkVersionError.getConfig()
        XCTAssertNotNil(config.inapps)
        XCTAssertTrue(config.inapps!.elements.isEmpty, "InApp must be skipped when sdkVersion key is invalid")
    }

    func test_InApp_withSdkVersionTypeError_shouldSkipInApp() {
        let config = try! InAppConfig.inAppSdkVersionTypeError.getConfig()
        XCTAssertNotNil(config.inapps)
        XCTAssertTrue(config.inapps!.elements.isEmpty, "InApp must be skipped when sdkVersion has wrong type")
    }

    // MARK: frequency

    func test_InApp_withFrequencyError_shouldDefaultToOnceLifetime() {
        // Key is `frequencyTest` — decodeIfPresent returns nil — defaults to once/lifetime
        let config = try! InAppConfig.inAppFrequencyError.getConfig()
        XCTAssertNotNil(config.inapps)
        guard let inapp = config.inapps?.elements.first else {
            XCTFail("InApp should survive when frequency key is missing")
            return
        }
        XCTAssertEqual(inapp.frequency, .once(OnceFrequency(kind: .lifetime)),
                       "Frequency must default to once/lifetime when frequency key is not found")
    }

    func test_InApp_withFrequencyTypeError_shouldSkipInApp() {
        // Type is Int — decodeIfPresent throws on type mismatch
        let config = try! InAppConfig.inAppFrequencyTypeError.getConfig()
        XCTAssertNotNil(config.inapps)
        XCTAssertTrue(config.inapps!.elements.isEmpty, "InApp must be skipped when frequency has wrong type")
    }

    func test_InApp_withFrequencyUnknownType_shouldSkipInApp() {
        // frequency.$type = "unknownFrequencyType" → .unknown → explicit throw
        let config = try! InAppConfig.inAppFrequencyUnknownType.getConfig()
        XCTAssertNotNil(config.inapps)
        XCTAssertTrue(config.inapps!.elements.isEmpty,
                      "InApp must be skipped when frequency has unknown $type")
    }

    func test_InApp_withFrequencyNil_shouldDefaultToOnceLifetime() {
        // frequency field absent entirely — defaults to once/lifetime
        let config = try! InAppConfig.inAppFrequencyNil.getConfig()
        XCTAssertNotNil(config.inapps)
        guard let inapp = config.inapps?.elements.first else {
            XCTFail("InApp should survive when frequency is nil")
            return
        }
        XCTAssertEqual(inapp.frequency, .once(OnceFrequency(kind: .lifetime)),
                       "Frequency must default to once/lifetime when frequency is absent")
    }

    // MARK: targeting

    func test_InApp_withTargetingError_shouldSkipInApp() {
        let config = try! InAppConfig.inAppTargetingError.getConfig()
        XCTAssertNotNil(config.inapps)
        XCTAssertTrue(config.inapps!.elements.isEmpty, "InApp must be skipped when targeting key is invalid")
    }

    func test_InApp_withTargetingTypeError_shouldSkipInApp() {
        let config = try! InAppConfig.inAppTargetingTypeError.getConfig()
        XCTAssertNotNil(config.inapps)
        XCTAssertTrue(config.inapps!.elements.isEmpty, "InApp must be skipped when targeting has wrong type")
    }

    // MARK: form

    func test_InApp_withFormError_shouldSkipInApp() {
        let config = try! InAppConfig.inAppFormError.getConfig()
        XCTAssertNotNil(config.inapps)
        XCTAssertTrue(config.inapps!.elements.isEmpty, "InApp must be skipped when form key is invalid")
    }

    func test_InApp_withFormTypeError_shouldSkipInApp() {
        let config = try! InAppConfig.inAppFormTypeError.getConfig()
        XCTAssertNotNil(config.inapps)
        XCTAssertTrue(config.inapps!.elements.isEmpty, "InApp must be skipped when form has wrong type")
    }

    // MARK: delayTime

    func test_InApp_withDelayTimeTypeError_shouldSetDelayTimeToNil() {
        // delayTime = 123 (Int) — caught in do/catch → nil, InApp survives
        let config = try! InAppConfig.inAppDelayTimeTypeError.getConfig()
        XCTAssertNotNil(config.inapps)
        guard let inapp = config.inapps?.elements.first else {
            XCTFail("InApp should survive when delayTime has wrong type")
            return
        }
        XCTAssertNil(inapp.delayTime, "delayTime must be nil when its type is invalid")
        XCTAssertEqual(inapp.id, "test-valid-inapp-id")
    }

    // MARK: FailableDecodableArray

    func test_InApp_withOneCorrupted_shouldKeepValidInApp() {
        // Two InApps: first has broken id (skipped), second is valid (survives)
        let config = try! InAppConfig.inAppOneCorrupted.getConfig()
        XCTAssertNotNil(config.inapps)
        XCTAssertEqual(config.inapps!.elements.count, 1,
                       "Only the valid InApp should remain after FailableDecodableArray filters out the corrupted one")
        XCTAssertEqual(config.inapps!.elements.first?.id, "test-valid-inapp-id")
    }

    // MARK: - Level 2: form.variants

    func test_InApp_withFormVariantsTypeError_shouldSkipInApp() {
        // form.variants = Int(1) — InAppFormDTO fails to decode
        let config = try! InAppConfig.inAppFormVariantsTypeError.getConfig()
        XCTAssertNotNil(config.inapps)
        XCTAssertTrue(config.inapps!.elements.isEmpty,
                      "InApp must be skipped when form.variants has wrong type")
    }

    func test_InApp_withFormVariantMissingType_shouldSkipInApp() {
        // variant has no $type → CustomDecodingError → array decode fails → InApp skipped
        let config = try! InAppConfig.inAppFormVariantMissingType.getConfig()
        XCTAssertNotNil(config.inapps)
        XCTAssertTrue(config.inapps!.elements.isEmpty,
                      "InApp must be skipped when form variant is missing $type")
    }

    func test_InApp_withFormVariantUnknownType_shouldSurviveWithUnknownVariant() {
        // variant.$type = "unknownVariantType" → .unknown case, InApp survives
        let config = try! InAppConfig.inAppFormVariantUnknownType.getConfig()
        XCTAssertNotNil(config.inapps)
        guard let inapp = config.inapps?.elements.first else {
            XCTFail("InApp should survive when form variant has unknown $type")
            return
        }
        XCTAssertEqual(inapp.id, "test-valid-inapp-id")
        XCTAssertNotNil(inapp.form.variants)
        XCTAssertEqual(inapp.form.variants?.first, .unknown,
                       "Form variant must be .unknown when $type is unrecognized")
    }

    // MARK: - Level 3: background.layers

    func test_InApp_withLayersTypeError_shouldSkipInApp() {
        // background.layers = Int(1) → cascades up → InApp skipped
        let config = try! InAppConfig.inAppLayersTypeError.getConfig()
        XCTAssertNotNil(config.inapps)
        XCTAssertTrue(config.inapps!.elements.isEmpty,
                      "InApp must be skipped when background.layers has wrong type")
    }

    func test_InApp_withLayerMissingType_shouldSkipInApp() {
        // layer has no $type → CustomDecodingError → cascades up → InApp skipped
        let config = try! InAppConfig.inAppLayerMissingType.getConfig()
        XCTAssertNotNil(config.inapps)
        XCTAssertTrue(config.inapps!.elements.isEmpty,
                      "InApp must be skipped when layer is missing $type")
    }

    func test_InApp_withLayerUnknownType_shouldSurviveWithUnknownLayer() {
        // layer.$type = "unknownLayerType" → .unknown case, InApp survives
        let config = try! InAppConfig.inAppLayerUnknownType.getConfig()
        XCTAssertNotNil(config.inapps)
        guard let inapp = config.inapps?.elements.first else {
            XCTFail("InApp should survive when layer has unknown $type")
            return
        }
        XCTAssertEqual(inapp.id, "test-valid-inapp-id")
    }

    // MARK: - Webview layer

    func test_InApp_withWebviewValid_shouldParseWebviewLayer() {
        let config = try! InAppConfig.inAppWebviewValid.getConfig()
        XCTAssertNotNil(config.inapps)
        guard let inapp = config.inapps?.elements.first else {
            XCTFail("Valid webview InApp should be parsed successfully")
            return
        }
        XCTAssertEqual(inapp.id, "webview-inapp-id")

        guard let variant = inapp.form.variants?.first else {
            XCTFail("Webview InApp should have a form variant")
            return
        }
        guard case .modal(let modal) = variant else {
            XCTFail("Variant should be modal")
            return
        }
        guard let content = modal.content,
              let background = content.background,
              let layer = background.layers?.first else {
            XCTFail("Modal should have a background layer")
            return
        }
        guard case .webview(let webviewLayer) = layer else {
            XCTFail("Layer should be webview type")
            return
        }
        XCTAssertEqual(webviewLayer.baseUrl, "https://inapp.local/popup")
        XCTAssertEqual(webviewLayer.contentUrl,
                       "https://api-staging.mindbox.ru/mobile/byendpoint/webview/stable/inapp-dev-v2.html")
        XCTAssertNotNil(webviewLayer.params)
        XCTAssertFalse(webviewLayer.params!.isEmpty, "Webview params should not be empty")
    }

    func test_InApp_withWebviewParamsTypeError_shouldSkipInApp() {
        // params = Int(123) instead of object → WebviewContentBackgroundLayerDTO fails → InApp skipped
        let config = try! InAppConfig.inAppWebviewParamsTypeError.getConfig()
        XCTAssertNotNil(config.inapps)
        XCTAssertTrue(config.inapps!.elements.isEmpty,
                      "InApp must be skipped when webview params has wrong type")
    }
}
