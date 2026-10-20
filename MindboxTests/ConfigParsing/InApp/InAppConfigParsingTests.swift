//
//  InAppConfigParsingTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 2/17/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import XCTest
@_spi(Internal) @testable import Mindbox

// swiftlint:disable force_try

fileprivate enum InAppConfig: String, Configurable {
    typealias DecodeType = ConfigResponse

    // MARK: - Level 1: InAppDTO fields

    case inAppIdError = "InAppIdError"
    case inAppIdTypeError = "InAppIdTypeError"

    case inAppSdkVersionError = "InAppSdkVersionError"
    case inAppSdkVersionTypeError = "InAppSdkVersionTypeError"

    case inAppFrequencyError = "InAppFrequencyError"
    case inAppFrequencyTypeError = "InAppFrequencyTypeError"
    case inAppFrequencyUnknownType = "InAppFrequencyUnknownType"
    case inAppFrequencyNil = "InAppFrequencyNil"

    case inAppTargetingError = "InAppTargetingError"
    case inAppTargetingTypeError = "InAppTargetingTypeError"

    case inAppFormError = "InAppFormError"
    case inAppFormTypeError = "InAppFormTypeError"

    case inAppDelayTimeTypeError = "InAppDelayTimeTypeError"

    case inAppOneCorrupted = "InAppOneCorrupted"

    // MARK: - Level 2: form.variants

    case inAppFormVariantsTypeError = "InAppFormVariantsTypeError"
    case inAppFormVariantMissingType = "InAppFormVariantMissingType"
    case inAppFormVariantUnknownType = "InAppFormVariantUnknownType"

    // MARK: - Level 3: background.layers

    case inAppLayersTypeError = "InAppLayersTypeError"
    case inAppLayerMissingType = "InAppLayerMissingType"
    case inAppLayerUnknownType = "InAppLayerUnknownType"

    // MARK: - Webview layer

    case inAppWebviewValid = "InAppWebviewValid"
    case inAppWebviewParamsTypeError = "InAppWebviewParamsTypeError"

    // MARK: - tags

    case inAppTagsValid = "InAppTagsValid"
    case inAppTagsNil = "InAppTagsNil"
    case inAppTagsTypeError = "InAppTagsTypeError"
    case inAppTagsArbitraryKeys = "InAppTagsArbitraryKeys"
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
        let config = try! InAppConfig.inAppFrequencyTypeError.getConfig()
        XCTAssertNotNil(config.inapps)
        XCTAssertTrue(config.inapps!.elements.isEmpty, "InApp must be skipped when frequency has wrong type")
    }

    func test_InApp_withFrequencyUnknownType_shouldSkipInApp() {
        let config = try! InAppConfig.inAppFrequencyUnknownType.getConfig()
        XCTAssertNotNil(config.inapps)
        XCTAssertTrue(config.inapps!.elements.isEmpty,
                      "InApp must be skipped when frequency has unknown $type")
    }

    func test_InApp_withFrequencyNil_shouldDefaultToOnceLifetime() {
        let config = try! InAppConfig.inAppFrequencyNil.getConfig()
        XCTAssertNotNil(config.inapps)
        guard let inapp = config.inapps?.elements.first else {
            XCTFail("InApp should survive when frequency is nil")
            return
        }
        XCTAssertEqual(inapp.frequency, .once(OnceFrequency(kind: .lifetime)),
                       "Frequency must default to once/lifetime when frequency is absent")
    }

    // MARK: frequency wire values

    private struct FrequencyHolder: Decodable {
        let frequency: InappFrequency
    }

    private func decodeFrequency(_ value: String) throws -> InappFrequency {
        let json = "{\"frequency\": \(value)}"
        return try JSONDecoder().decode(FrequencyHolder.self, from: Data(json.utf8)).frequency
    }

    func test_Frequency_unlimited_shouldDecodeAsUnlimited() throws {
        XCTAssertEqual(try decodeFrequency(#"{"$type": "unlimited"}"#), .unlimited)
    }

    func test_Frequency_withMiscasedKind_shouldDecodeAsUnknown() throws {
        XCTAssertEqual(try decodeFrequency(#"{"$type": "Unlimited"}"#), .unknown,
                       "The kind string is a wire contract shared with the backend and Android: a case change is a different kind")
    }

    func test_Frequency_withUnrecognizedKind_shouldDecodeAsUnknown() throws {
        XCTAssertEqual(try decodeFrequency(#"{"$type": "everySecondTuesday"}"#), .unknown)
    }

    func test_Frequency_withoutType_shouldThrow() {
        XCTAssertThrowsError(try decodeFrequency("{}"))
    }

    func test_Frequency_withNonStringType_shouldThrow() {
        XCTAssertThrowsError(try decodeFrequency(#"{"$type": 42}"#))
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
        let config = try! InAppConfig.inAppOneCorrupted.getConfig()
        XCTAssertNotNil(config.inapps)
        XCTAssertEqual(config.inapps!.elements.count, 1,
                       "Only the valid InApp should remain after FailableDecodableArray filters out the corrupted one")
        XCTAssertEqual(config.inapps!.elements.first?.id, "test-valid-inapp-id")
    }

    // MARK: - Level 2: form.variants

    func test_InApp_withFormVariantsTypeError_shouldSkipInApp() {
        let config = try! InAppConfig.inAppFormVariantsTypeError.getConfig()
        XCTAssertNotNil(config.inapps)
        XCTAssertTrue(config.inapps!.elements.isEmpty,
                      "InApp must be skipped when form.variants has wrong type")
    }

    func test_InApp_withFormVariantMissingType_shouldSkipInApp() {
        let config = try! InAppConfig.inAppFormVariantMissingType.getConfig()
        XCTAssertNotNil(config.inapps)
        XCTAssertTrue(config.inapps!.elements.isEmpty,
                      "InApp must be skipped when form variant is missing $type")
    }

    func test_InApp_withFormVariantUnknownType_shouldSurviveWithUnknownVariant() {
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
        let config = try! InAppConfig.inAppLayersTypeError.getConfig()
        XCTAssertNotNil(config.inapps)
        XCTAssertTrue(config.inapps!.elements.isEmpty,
                      "InApp must be skipped when background.layers has wrong type")
    }

    func test_InApp_withLayerMissingType_shouldSkipInApp() {
        let config = try! InAppConfig.inAppLayerMissingType.getConfig()
        XCTAssertNotNil(config.inapps)
        XCTAssertTrue(config.inapps!.elements.isEmpty,
                      "InApp must be skipped when layer is missing $type")
    }

    func test_InApp_withLayerUnknownType_shouldSurviveWithUnknownLayer() {
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
        let params = webviewLayer.params!
        XCTAssertEqual(params.count, 5)

        XCTAssertEqual(params["formId"], .string("143364"))
        XCTAssertEqual(params["popUpId"], .string("143364"))
        XCTAssertEqual(params["popUpEndpointId"], .string("Mpush-test.inapp-quiz-migration"))

        XCTAssertEqual(params["test"], .object(["lalala": .string("123")]))

        XCTAssertEqual(params["someObject"], .array([
            .object(["lalala": .int(123), "blaBla": .bool(true)])
        ]))
    }

    func test_InApp_withWebviewParamsTypeError_shouldSkipInApp() {
        let config = try! InAppConfig.inAppWebviewParamsTypeError.getConfig()
        XCTAssertNotNil(config.inapps)
        XCTAssertTrue(config.inapps!.elements.isEmpty,
                      "InApp must be skipped when webview params has wrong type")
    }

    // MARK: - tags

    func test_InApp_withTagsValid_shouldDecodeTags() {
        let config = try! InAppConfig.inAppTagsValid.getConfig()
        XCTAssertNotNil(config.inapps)
        guard let inapp = config.inapps?.elements.first else {
            XCTFail("InApp should be present")
            return
        }
        XCTAssertEqual(inapp.tags?["layer"], "webView")
        XCTAssertEqual(inapp.tags?["type"], "modal")
    }

    func test_InApp_withTagsNil_shouldHaveNilTags() {
        let config = try! InAppConfig.inAppTagsNil.getConfig()
        XCTAssertNotNil(config.inapps)
        guard let inapp = config.inapps?.elements.first else {
            XCTFail("InApp should be present")
            return
        }
        XCTAssertNil(inapp.tags, "tags must be nil when absent")
    }

    func test_InApp_withTagsTypeError_shouldHaveNilTagsAndNotSkipInApp() {
        let config = try! InAppConfig.inAppTagsTypeError.getConfig()
        XCTAssertNotNil(config.inapps)
        guard let inapp = config.inapps?.elements.first else {
            XCTFail("InApp must NOT be skipped when tags has non-String value")
            return
        }
        XCTAssertNil(inapp.tags, "tags must be nil when any value is not String")
    }

    func test_InApp_withTagsArbitraryKeys_shouldDecodeAllKeys() {
        let config = try! InAppConfig.inAppTagsArbitraryKeys.getConfig()
        XCTAssertNotNil(config.inapps)
        guard let inapp = config.inapps?.elements.first else {
            XCTFail("InApp should be present")
            return
        }
        XCTAssertNotNil(inapp.tags)
        XCTAssertEqual(inapp.tags?.count, 4)
        XCTAssertEqual(inapp.tags?["customKey1"], "value1")
        XCTAssertEqual(inapp.tags?["another-key"], "value2")
        XCTAssertEqual(inapp.tags?["key_with_underscore"], "value3")
        XCTAssertEqual(inapp.tags?["CamelCaseKey"], "value4")
    }
}
