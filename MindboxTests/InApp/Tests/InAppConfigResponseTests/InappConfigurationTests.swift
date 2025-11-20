//
//  InappConfigurationTests.swift
//  MindboxTests
//
//  Created by vailence on 28.11.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Testing
@testable import Mindbox

fileprivate enum InappConfig: String, Configurable {
    typealias DecodeType = ConfigResponse

    case configWithTwoInapps = "InAppConfiguration"
    case configWithOperationInapp = "InAppConfigurationWithOperations"
}

@Suite("In-app mapper tests")
final class InappConfigurationTests {

    private var mapper: InappMapperProtocol
    private var targetingChecker: InAppTargetingCheckerProtocol
    private var stub: InAppConfigStub

    init() {
        TestConfiguration.configure()
        self.mapper = DI.injectOrFail(InappMapperProtocol.self)
        self.targetingChecker = DI.injectOrFail(InAppTargetingCheckerProtocol.self)
        self.stub = InAppConfigStub()
    }

    // MARK: - SDK version

    @Test("First in-app does not match SDK version, second is chosen", .tags(.sdkVersion))
    func first_inapp_does_not_fit_sdk_returns_second() async throws {
        let response = try InappConfig.configWithTwoInapps.getConfig()

        let sdkValidator = DI.injectOrFail(SDKVersionValidator.self)
        sdkValidator.sdkVersionNumeric = 9

        let result = await handleInapps(event: nil, response: response)
        #expect(result?.inAppId == "2")
    }

    @Test("Both in-apps match SDK version, first is chosen", .tags(.sdkVersion))
    func both_inapps_fit_sdk_returns_first() async throws {
        let response = try InappConfig.configWithTwoInapps.getConfig()

        let sdkValidator = DI.injectOrFail(SDKVersionValidator.self)
        sdkValidator.sdkVersionNumeric = 5

        let result = await handleInapps(event: nil, response: response)
        #expect(result?.inAppId == "1")
    }

    @Test("Both in-apps do not match SDK version, nothing is shown", .tags(.sdkVersion))
    func both_inapps_do_not_fit_sdk_returns_nil() async throws {
        let response = try InappConfig.configWithTwoInapps.getConfig()

        let sdkValidator = DI.injectOrFail(SDKVersionValidator.self)
        sdkValidator.sdkVersionNumeric = 1

        let result = await handleInapps(event: nil, response: response)
        #expect(result == nil)
    }

    // MARK: - Custom operations

    @Test("Empty custom operation name returns nil", .tags(.customOperation))
    func operation_empty_name_returns_nil() async throws {
        let response = try InappConfig.configWithOperationInapp.getConfig()
        let event = ApplicationEvent(name: "", model: nil)

        let result = await handleInapps(event: event, response: response)
        #expect(result == nil)
    }

    @Test("Wrong custom operation name returns nil", .tags(.customOperation))
    func operation_wrong_name_returns_nil() async throws {
        let response = try InappConfig.configWithOperationInapp.getConfig()
        let event = ApplicationEvent(name: "hello", model: nil)

        let result = await handleInapps(event: event, response: response)
        #expect(result == nil)
    }

    @Test("Correct custom operation name returns in-app", .tags(.customOperation))
    func operation_correct_name_returns_inapp() async throws {
        let response = try InappConfig.configWithOperationInapp.getConfig()
        let event = ApplicationEvent(name: "test", model: nil)

        let result = await handleInapps(event: event, response: response)
        #expect(result?.inAppId == "1")
    }

    // MARK: - Category ID

    @Test("Empty model in viewCategory returns nil", .tags(.category))
    func categoryID_emptyModel_returns_nil() async throws {
        let response = try stub.getCategoryID_Substring()
        let event = ApplicationEvent(name: "Mobile.viewCategory", model: nil)

        let result = await handleInapps(event: event, response: response)
        #expect(result == nil)
    }

    @Test("Wrong system name for product operation returns nil", .tags(.product))
    func product_wrong_systemName_returns_nil() async throws {
        let response = try stub.getProductID_substring()
        let event = ApplicationEvent(
            name: "viewProduct",
            model: .init(viewProduct: .init(product: .init(ids: [
                "website": "Boots".uppercased(),
                "system1c": "81".uppercased()
            ])))
        )

        let result = await handleInapps(event: event, response: response)
        #expect(result == nil)
    }

    @Test("Correct system name for product operation returns in-app", .tags(.product))
    func product_correct_systemName_returns_inapp() async throws {
        let response = try stub.getProductID_substring()
        let event = ApplicationEvent(
            name: "Mobile.viewProduct",
            model: .init(viewProduct: .init(product: .init(ids: [
                "website": "Boots".uppercased(),
                "system1c": "81".uppercased()
            ])))
        )

        let result = await handleInapps(event: event, response: response)
        #expect(result?.inAppId == "1")
    }

    @Test("Wrong system name for category operation returns nil", .tags(.category))
    func category_wrong_systemName_returns_nil() async throws {
        let response = try stub.getCategoryID_Substring()
        let event = ApplicationEvent(
            name: "viewCategory",
            model: .init(viewProductCategory: .init(productCategory: .init(ids: [
                "System1C": "Boots".uppercased(),
                "TestSite": "81".uppercased()
            ])))
        )

        let result = await handleInapps(event: event, response: response)
        #expect(result == nil)
    }

    @Test("Correct system name for category operation returns in-app", .tags(.category))
    func category_correct_systemName_returns_inapp() async throws {
        let response = try stub.getCategoryID_Substring()
        let event = ApplicationEvent(
            name: "Mobile.viewCategory",
            model: .init(viewProductCategory: .init(productCategory: .init(ids: [
                "System1C": "Boots".uppercased(),
                "TestSite": "81".uppercased()
            ])))
        )

        let result = await handleInapps(event: event, response: response)
        #expect(result?.inAppId == "1")
    }

    @Test("Category substring matches returns in-app", .tags(.category))
    func categoryID_substring_true() async throws {
        let response = try stub.getCategoryID_Substring()
        let event = ApplicationEvent(
            name: "Mobile.ViewCategory",
            model: .init(viewProductCategory: .init(productCategory: .init(ids: [
                "System1C": "Boots".uppercased(),
                "TestSite": "81".uppercased()
            ])))
        )

        let result = await handleInapps(event: event, response: response)
        #expect(result?.inAppId == "1")
    }

    @Test("Category substring does not match returns nil", .tags(.category))
    func categoryID_substring_false() async throws {
        let response = try stub.getCategoryID_Substring()
        let event = ApplicationEvent(
            name: "Mobile.viewCategory",
            model: .init(viewProductCategory: .init(productCategory: .init(ids: [
                "System1C": "Bovts".uppercased(),
                "TestSite": "81".uppercased()
            ])))
        )

        let result = await handleInapps(event: event, response: response)
        #expect(result == nil)
    }

    @Test("Category notSubstring matches returns in-app", .tags(.category))
    func categoryID_notSubstring_true() async throws {
        let response = try stub.getCategoryID_notSubstring()
        let event = ApplicationEvent(
            name: "Mobile.viewCategory",
            model: .init(viewProductCategory: .init(productCategory: .init(ids: [
                "System1C": "Boots".uppercased(),
                "TestSite": "Button".uppercased()
            ])))
        )

        let result = await handleInapps(event: event, response: response)
        #expect(result?.inAppId == "1")
    }

    @Test("Category notSubstring does not match returns nil", .tags(.category))
    func categoryID_notSubstring_false() async throws {
        let response = try stub.getCategoryID_notSubstring()
        let event = ApplicationEvent(
            name: "Mobile.viewCategory",
            model: .init(viewProductCategory: .init(productCategory: .init(ids: [
                "System1C": "Boots".uppercased(),
                "TestSite": "Buttootn".uppercased()
            ])))
        )

        let result = await handleInapps(event: event, response: response)
        #expect(result == nil)
    }

    @Test("Category startsWith matches returns in-app", .tags(.category))
    func categoryID_startWith_true() async throws {
        let response = try stub.getCategoryID_startWith()
        let event = ApplicationEvent(
            name: "Mobile.viewCategory",
            model: .init(viewProductCategory: .init(productCategory: .init(ids: [
                "System1C": "oots".uppercased(),
                "TestSite": "Button".uppercased()
            ])))
        )

        let result = await handleInapps(event: event, response: response)
        #expect(result?.inAppId == "1")
    }

    @Test("Category startsWith does not match returns nil", .tags(.category))
    func categoryID_startWith_false() async throws {
        let response = try stub.getCategoryID_startWith()
        let event = ApplicationEvent(
            name: "Mobile.viewCategory",
            model: .init(viewProductCategory: .init(productCategory: .init(ids: [
                "System1C": "Boots".uppercased(),
                "TestSite": "Button".uppercased()
            ])))
        )

        let result = await handleInapps(event: event, response: response)
        #expect(result == nil)
    }

    @Test("Category endsWith matches returns in-app", .tags(.category))
    func categoryID_endWith_true() async throws {
        let response = try stub.getCategoryID_endWith()
        let event = ApplicationEvent(
            name: "Mobile.viewCategory",
            model: .init(viewProductCategory: .init(productCategory: .init(ids: [
                "System1C": "Boots".uppercased(),
                "TestSite": "Button".uppercased()
            ])))
        )

        let result = await handleInapps(event: event, response: response)
        #expect(result?.inAppId == "1")
    }

    @Test("Category endsWith does not match returns nil", .tags(.category))
    func categoryID_endWith_false() async throws {
        let response = try stub.getCategoryID_endWith()
        let event = ApplicationEvent(
            name: "Mobile.viewCategory",
            model: .init(viewProductCategory: .init(productCategory: .init(ids: [
                "System1C": "Boats".uppercased(),
                "TestSite": "Button".uppercased()
            ])))
        )

        let result = await handleInapps(event: event, response: response)
        #expect(result == nil)
    }

    @Test("Category in(any) matches returns in-app", .tags(.category))
    func categoryID_in_any_true() async throws {
        let response = try stub.getCategoryIDIn_Any()
        let event = ApplicationEvent(
            name: "Mobile.viewCategory",
            model: .init(viewProductCategory: .init(productCategory: .init(ids: [
                "System1C": "testik2"
            ])))
        )

        let result = await handleInapps(event: event, response: response)
        #expect(result?.inAppId == "1")
    }

    @Test("Category in(any) does not match returns nil", .tags(.category))
    func categoryID_in_any_false() async throws {
        let response = try stub.getCategoryIDIn_Any()
        let event = ApplicationEvent(
            name: "Mobile.viewCategory",
            model: .init(viewProductCategory: .init(productCategory: .init(ids: [
                "System1C": "potato"
            ])))
        )

        let result = await handleInapps(event: event, response: response)
        #expect(result == nil)
    }

    @Test("Category in(none) matches returns in-app", .tags(.category))
    func categoryID_in_none_true() async throws {
        let response = try stub.getCategoryIDIn_None()
        let event = ApplicationEvent(
            name: "Mobile.viewCategory",
            model: .init(viewProductCategory: .init(productCategory: .init(ids: [
                "System1C": "potato"
            ])))
        )

        let result = await handleInapps(event: event, response: response)
        #expect(result?.inAppId == "1")
    }

    @Test("Category in(none) does not match returns nil", .tags(.category))
    func categoryID_in_none_false() async throws {
        let response = try stub.getCategoryIDIn_None()
        let event = ApplicationEvent(
            name: "Mobile.viewCategory",
            model: .init(viewProductCategory: .init(productCategory: .init(ids: [
                "System1C": "testik2"
            ])))
        )

        let result = await handleInapps(event: event, response: response)
        #expect(result == nil)
    }

    // MARK: - Product ID

    @Test("Empty product model returns nil", .tags(.product))
    func productID_emptyModel_returns_nil() async throws {
        let response = try stub.getProductID_substring()
        let event = ApplicationEvent(name: "Mobile.viewProduct", model: nil)

        let result = await handleInapps(event: event, response: response)
        #expect(result == nil)
    }

    @Test("Product substring matches returns in-app", .tags(.product))
    func productID_substring_true() async throws {
        let response = try stub.getProductID_substring()
        let event = ApplicationEvent(
            name: "Mobile.viewProduct",
            model: .init(viewProduct: .init(product: .init(ids: [
                "website": "Boots".uppercased(),
                "system1c": "81".uppercased()
            ])))
        )

        let result = await handleInapps(event: event, response: response)
        #expect(result?.inAppId == "1")
    }

    @Test("Product substring does not match returns nil", .tags(.product))
    func productID_substring_false() async throws {
        let response = try stub.getProductID_substring()
        let event = ApplicationEvent(
            name: "Mobile.viewProduct",
            model: .init(viewProduct: .init(product: .init(ids: [
                "website": "Bovts".uppercased(),
                "system1c": "81".uppercased()
            ])))
        )

        let result = await handleInapps(event: event, response: response)
        #expect(result == nil)
    }

    @Test("Product notSubstring matches returns in-app", .tags(.product))
    func productID_notSubstring_true() async throws {
        let response = try stub.getProductID_notSubstring()
        let event = ApplicationEvent(
            name: "Mobile.viewProduct",
            model: .init(viewProduct: .init(product: .init(ids: [
                "website": "Boots".uppercased(),
                "system1c": "81".uppercased()
            ])))
        )

        let result = await handleInapps(event: event, response: response)
        #expect(result?.inAppId == "1")
    }

    @Test("Product notSubstring does not match returns nil", .tags(.product))
    func productID_notSubstring_false() async throws {
        let response = try stub.getProductID_notSubstring()
        let event = ApplicationEvent(
            name: "Mobile.viewProduct",
            model: .init(viewProduct: .init(product: .init(ids: [
                "website": "Boots".uppercased(),
                "system1c": "Buttootn".uppercased()
            ])))
        )

        let result = await handleInapps(event: event, response: response)
        #expect(result == nil)
    }

    @Test("Product startsWith matches returns in-app", .tags(.product))
    func productID_startWith_true() async throws {
        let response = try stub.getProductID_startWith()
        let event = ApplicationEvent(
            name: "Mobile.viewProduct",
            model: .init(viewProduct: .init(product: .init(ids: [
                "website": "oots".uppercased(),
                "system1c": "Button".uppercased()
            ])))
        )

        let result = await handleInapps(event: event, response: response)
        #expect(result?.inAppId == "1")
    }

    @Test("Product startsWith does not match returns nil", .tags(.product))
    func productID_startWith_false() async throws {
        let response = try stub.getProductID_startWith()
        let event = ApplicationEvent(
            name: "Mobile.viewProduct",
            model: .init(viewProduct: .init(product: .init(ids: [
                "website": "Boots".uppercased(),
                "system1c": "Button".uppercased()
            ])))
        )

        let result = await handleInapps(event: event, response: response)
        #expect(result == nil)
    }

    @Test("Product endsWith matches returns in-app", .tags(.product))
    func productID_endWith_true() async throws {
        let response = try stub.getProductID_endWith()
        let event = ApplicationEvent(
            name: "Mobile.viewProduct",
            model: .init(viewProduct: .init(product: .init(ids: [
                "website": "Boots".uppercased(),
                "system1c": "Button".uppercased()
            ])))
        )

        let result = await handleInapps(event: event, response: response)
        #expect(result?.inAppId == "1")
    }

    @Test("Product endsWith does not match returns nil", .tags(.product))
    func productID_endWith_false() async throws {
        let response = try stub.getProductID_endWith()
        let event = ApplicationEvent(
            name: "Mobile.viewProduct",
            model: .init(viewProduct: .init(product: .init(ids: [
                "website": "Boats".uppercased(),
                "system1c": "Button".uppercased()
            ])))
        )

        let result = await handleInapps(event: event, response: response)
        #expect(result == nil)
    }

    // MARK: - Product segment

    @Test("Positive product segment matches returns in-app", .tags(.productSegment))
    func productSegment_positive_true() async throws {
        let response = try stub.getProductSegment_Positive()
        let event = ApplicationEvent(
            name: "Mobile.viewProduct",
            model: .init(viewProduct: .init(product: .init(ids: [
                "website": "49"
            ]))))
        
        let productSegments = InAppProductSegmentResponse(
            status: .success,
            products: [
                .init(
                    ids: ["website": "49"],
                    segmentations: [
                        .init(
                            ids: .init(externalId: "1"),
                            segment: .init(ids: .init(externalId: "3"))
                        )
                    ]
                )
            ]
        )

        if let segmentations = productSegments.products?.first?.segmentations {
            self.targetingChecker.checkedProductSegmentations = [
                .init(key: "website", value: "49"): segmentations
            ]
        }

        let result = await handleInapps(event: event, response: response)
        #expect(result?.inAppId == "1")
    }

    @Test("Positive product segment does not match returns nil", .tags(.productSegment))
    func productSegment_positive_false() async throws {
        let response = try stub.getProductSegment_Positive()
        let event = ApplicationEvent(
            name: "Mobile.viewProduct",
            model: .init(viewProduct: .init(product: .init(ids: [
                "website": "49"
            ]))))
        
        let result = await handleInapps(event: event, response: response)
        #expect(result == nil)
    }

    @Test("Negative product segment matches returns in-app", .tags(.productSegment))
    func productSegment_negative_true() async throws {
        let response = try stub.getProductSegment_Negative()
        let event = ApplicationEvent(
            name: "Mobile.viewProduct",
            model: .init(viewProduct: .init(product: .init(ids: [
                "website": "49"
            ]))))
        
        let segmentation = [
            InAppProductSegmentResponse.CustomerSegmentation(
                ids: .init(externalId: "1"),
                segment: .init(ids: .init(externalId: "4"))
            )
        ]

        self.targetingChecker.checkedProductSegmentations = [
            .init(key: "website", value: "49"): segmentation
        ]

        let result = await handleInapps(event: event, response: response)
        #expect(result?.inAppId == "1")
    }

    @Test("Negative product segment does not match returns nil", .tags(.productSegment))
    func productSegment_negative_false() async throws {
        let response = try stub.getProductSegment_Negative()
        let event = ApplicationEvent(
            name: "Mobile.viewProduct",
            model: .init(viewProduct: .init(product: .init(ids: [
                "website": "49"
            ]))))
        
        let result = await handleInapps(event: event, response: response)
        #expect(result == nil)
    }

    // MARK: - Helpers

    private func handleInapps(event: ApplicationEvent?, response: ConfigResponse) async -> InAppFormData? {
        await withCheckedContinuation { continuation in
            mapper.handleInapps(event, response) { formData in
                continuation.resume(returning: formData)
            }
        }
    }
}
