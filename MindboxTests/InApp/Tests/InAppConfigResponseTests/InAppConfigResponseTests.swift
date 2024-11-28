//
//  InAppConfigResponseTests.swift
//  MindboxTests
//
//  Created by Максим Казаков on 12.10.2022.
//  Copyright © 2022 Mikhail Barilov. All rights reserved.
//

import Foundation
import XCTest
@testable import Mindbox

// swiftlint:disable comment_spacing
//
//class InAppConfigResponseTests: XCTestCase {
//
//    var container = try! TestDependencyProvider()
//
//    var sessionTemporaryStorage: SessionTemporaryStorage {
//        container.sessionTemporaryStorage
//    }
//
//    var persistenceStorage: PersistenceStorage {
//        container.persistenceStorage
//    }
//
//    var networkFetcher: NetworkFetcher {
//        container.instanceFactory.makeNetworkFetcher()
//    }
//
//    private var mapper: InAppConfigurationMapperProtocol!
//    private let configStub = InAppConfigStub()
//    private let targetingChecker: InAppTargetingCheckerProtocol = InAppTargetingChecker()
//    private var shownInAppsIds: Set<String>!
//
//    override func setUp() {
//        super.setUp()
//        mapper = InAppConfigutationMapper(geoService: container.geoService,
//                                          segmentationService: container.segmentationSevice,
//                                          customerSegmentsAPI: .live,
//                                          targetingChecker: targetingChecker,
//                                          sessionTemporaryStorage: sessionTemporaryStorage,
//                                          persistenceStorage: persistenceStorage,
//                                          sdkVersionValidator: container.sdkVersionValidator,
//                                          imageDownloadService: container.imageDownloadService,
//                                          abTestDeviceMixer: container.abTestDeviceMixer)
//        shownInAppsIds = Set(persistenceStorage.shownInAppsIds ?? [])
//    }
//
//    func test_2InApps_oneFitsInAppsSdkVersion_andOneDoesnt() throws {
//        let response = try getConfig(name: "InAppConfiguration")
//        var output: InAppFormData?
//        let expectations = expectation(description: "test_2InApps_oneFitsInAppsSdkVersion_andOneDoesnt")
//        mapper.mapConfigResponse(nil, response) { result in
//            output = result
//            expectations.fulfill()
//        }
//
//        waitForExpectations(timeout: 3)
//
//        let expected = InAppTransitionData(inAppId: "00000000-0000-0000-0000-000000000001",
//                                           imageUrl: "https://s3-symbol-logo.tradingview.com/true-corporation-public-company-limited--600.png",
//                                           redirectUrl: "", intentPayload: "")
//        XCTAssertEqual(expected.inAppId, output?.inAppId)
//        XCTAssertEqual(expected.intentPayload, output?.intentPayload)
//        XCTAssertEqual(expected.redirectUrl, output?.redirectUrl)
//    }
//
//    func test_2InApps_bothFitInAppsSdkVersion() throws {
//        let response = try getConfig(name: "InAppConfiguration")
//        var output: InAppFormData?
//        let expectations = expectation(description: "test_2InApps_bothFitInAppsSdkVersion")
//        mapper.mapConfigResponse(nil, response) { result in
//            output = result
//            expectations.fulfill()
//        }
//
//        waitForExpectations(timeout: 1)
//        let expected = InAppTransitionData(inAppId: "00000000-0000-0000-0000-000000000001",
//                                           imageUrl: "https://s3-symbol-logo.tradingview.com/true-corporation-public-company-limited--600.png",
//                                           redirectUrl: "", intentPayload: "")
//
//        XCTAssertEqual(expected.inAppId, output?.inAppId)
//        XCTAssertEqual(expected.intentPayload, output?.intentPayload)
//        XCTAssertEqual(expected.redirectUrl, output?.redirectUrl)
//    }
//
//    func test_2InApps_bothDontFitInAppsSdkVersion() throws {
//        let response = try getConfig(name: "InAppConfiguration")
//        var output: InAppFormData?
//        let expectations = expectation(description: "test_2InApps_bothDontFitInAppsSdkVersion")
//        mapper = getMapper(version: 0)
//        mapper.mapConfigResponse(nil, response) { result in
//            output = result
//            expectations.fulfill()
//        }
//
//        waitForExpectations(timeout: 1)
//
//        XCTAssertNil(output)
//    }
//
//    func test_operation_happyFlow() throws {
//        let response = try getConfig(name: "InAppConfigurationWithOperations")
//        let event = ApplicationEvent(name: "TESTPushOK", model: nil)
//        mapper = getMapper(version: 4)
//
//        var output: InAppFormData?
//        let expectations = expectation(description: "test_operation_happyFlow")
//        mapper.mapConfigResponse(event, response) { result in
//            output = result
//            expectations.fulfill()
//        }
//
//        waitForExpectations(timeout: 1)
//        let expected = InAppTransitionData(inAppId: "00000000-0000-0000-0000-000000000001",
//                                           imageUrl: "https://s3-symbol-logo.tradingview.com/true-corporation-public-company-limited--600.png",
//                                           redirectUrl: "", intentPayload: "")
//
//        XCTAssertEqual(expected.inAppId, output?.inAppId)
//        XCTAssertEqual(expected.intentPayload, output?.intentPayload)
//        XCTAssertEqual(expected.redirectUrl, output?.redirectUrl)
//    }
//
//    func test_operation_empty_operatonName() throws {
//        let response = try getConfig(name: "InAppConfigurationWithOperations")
//        let event = ApplicationEvent(name: "", model: nil)
//        mapper = getMapper(version: 4)
//
//        var output: InAppFormData?
//        let expectations = expectation(description: "test_operation_empty_operatonName")
//        mapper.mapConfigResponse(event, response) { result in
//            output = result
//            expectations.fulfill()
//        }
//
//        waitForExpectations(timeout: 1)
//        XCTAssertNil(output)
//    }
//
//    func test_operation_wrong_operatonName() throws {
//        let response = try getConfig(name: "InAppConfigurationWithOperations")
//        mapper = getMapper(version: 4)
//        let event = ApplicationEvent(name: "WrongOperationName", model: nil)
//        var output: InAppFormData?
//        let expectations = expectation(description: "test_operation_wrong_operatonName")
//        mapper.mapConfigResponse(event, response) { result in
//            output = result
//            expectations.fulfill()
//        }
//
//        waitForExpectations(timeout: 1)
//        XCTAssertNil(output)
//    }
//
//    func test_categoryID_emptyModel() {
//        mapper = getMapper(version: 5)
//        let event = ApplicationEvent(name: "Hello", model: nil)
//        var output: InAppFormData?
//        let expectations = expectation(description: "test_categoryID_emptyModel")
//        mapper.mapConfigResponse(event, configStub.getCategoryIDIn_Any()) { result in
//            output = result
//            expectations.fulfill()
//        }
//
//        waitForExpectations(timeout: 1)
//        XCTAssertNil(output)
//    }
//
//    func test_categoryID_substring_true() {
//        let response = configStub.getCategoryID_Substring()
//        mapper = getMapper(version: 5)
//        let event = ApplicationEvent(name: "Hello",
//                                     model: .init(viewProductCategory: .init(productCategory: .init(ids: [
//                                        "System1C": "Boots".uppercased(),
//                                        "TestSite": "81".uppercased()
//                                     ]))))
//        var output: InAppFormData?
//        let expectations = expectation(description: "test_categoryID_substring_true")
//        mapper.mapConfigResponse(event, configStub.getCategoryIDIn_Any()) { result in
//            output = result
//            expectations.fulfill()
//        }
//
//        waitForExpectations(timeout: 1)
//        let expected = InAppTransitionData(inAppId: "0",
//                                           imageUrl: "1",
//                                           redirectUrl: "2", intentPayload: "3")
//
//        XCTAssertEqual(expected.inAppId, output?.inAppId)
//        XCTAssertEqual(expected.intentPayload, output?.intentPayload)
//        XCTAssertEqual(expected.redirectUrl, output?.redirectUrl)
//    }
//
//    func test_categoryID_substring_false() {
//        let event = ApplicationEvent(name: "Hello",
//                                     model: .init(viewProductCategory: .init(productCategory: .init(ids: [
//                                        "System1C": "Bovts".uppercased(),
//                                        "TestSite": "81".uppercased()
//                                     ]))))
//        mapper = getMapper(version: 5)
//        var output: InAppFormData?
//        let expectations = expectation(description: "test_categoryID_emptyModel")
//        mapper.mapConfigResponse(event, configStub.getCategoryID_Substring()) { result in
//            output = result
//            expectations.fulfill()
//        }
//
//        waitForExpectations(timeout: 1)
//        XCTAssertNil(output)
//    }
//
//    func test_categoryID_notSubstring_true() {
//        let event = ApplicationEvent(name: "Hello",
//                                     model: .init(viewProductCategory: .init(productCategory: .init(ids: [
//                                        "System1C": "Boots".uppercased(),
//                                        "TestSite": "Button".uppercased()
//                                     ]))))
//        mapper = getMapper(version: 5)
//        var output: InAppFormData?
//        let expectations = expectation(description: "test_categoryID_emptyModel")
//        mapper.mapConfigResponse(event, configStub.getCategoryID_notSubstring()) { result in
//            output = result
//            expectations.fulfill()
//        }
//
//        waitForExpectations(timeout: 1)
//        let expected =  InAppTransitionData(inAppId: "0",
//                                            imageUrl: "https://example.com/image.jpg",
//                                            redirectUrl: "2",
//                                            intentPayload: "3")
//
//        XCTAssertEqual(expected.inAppId, output?.inAppId)
//        XCTAssertEqual(expected.intentPayload, output?.intentPayload)
//        XCTAssertEqual(expected.redirectUrl, output?.redirectUrl)
//    }
//
//    func test_categoryID_notSubstring_false() {
//        let event = ApplicationEvent(name: "Hello",
//                                     model: .init(viewProductCategory: .init(productCategory: .init(ids: [
//                                        "System1C": "Boots".uppercased(),
//                                        "TestSite": "Buttootn".uppercased()
//                                     ]))))
//        let response = configStub.getCategoryID_notSubstring()
//        mapper = getMapper(version: 5)
//        var output: InAppFormData?
//        let expectations = expectation(description: "test_categoryID_emptyModel")
//        mapper.mapConfigResponse(event, response) { result in
//            output = result
//            expectations.fulfill()
//        }
//
//        waitForExpectations(timeout: 1)
//        XCTAssertNil(output)
//    }
//
//
//    func test_categoryID_startWith_true() {
//        let event = ApplicationEvent(name: "Hello",
//                                     model: .init(viewProductCategory: .init(productCategory: .init(ids: [
//                                        "System1C": "oots".uppercased(),
//                                        "TestSite": "Button".uppercased()
//                                     ]))))
//        let response = configStub.getCategoryID_startWith()
//        mapper = getMapper(version: 5)
//        var output: InAppFormData?
//        let expectations = expectation(description: "test_categoryID_emptyModel")
//        mapper.mapConfigResponse(event, response) { result in
//            output = result
//            expectations.fulfill()
//        }
//
//        waitForExpectations(timeout: 1)
//        let expected =  InAppTransitionData(inAppId: "0",
//                                            imageUrl: "1",
//                                            redirectUrl: "2",
//                                            intentPayload: "3")
//
//        XCTAssertEqual(expected.inAppId, output?.inAppId)
//        XCTAssertEqual(expected.intentPayload, output?.intentPayload)
//        XCTAssertEqual(expected.redirectUrl, output?.redirectUrl)
//    }
//
//    func test_categoryID_startWith_false() {
//        let event = ApplicationEvent(name: "Hello",
//                                     model: .init(viewProductCategory: .init(productCategory: .init(ids: [
//                                        "System1C": "Boots".uppercased(),
//                                        "TestSite": "Button".uppercased()
//                                     ]))))
//        let response = configStub.getCategoryID_startWith()
//        mapper = getMapper(version: 5)
//        var output: InAppFormData?
//        let expectations = expectation(description: "test_categoryID_emptyModel")
//        mapper.mapConfigResponse(event, response) { result in
//            output = result
//            expectations.fulfill()
//        }
//
//        waitForExpectations(timeout: 1)
//        XCTAssertNil(output)
//    }
//
//    func test_categoryID_endWith_true() {
//        let event = ApplicationEvent(name: "Hello",
//                                     model: .init(viewProductCategory: .init(productCategory: .init(ids: [
//                                        "System1C": "Boots".uppercased(),
//                                        "TestSite": "Button".uppercased()
//                                     ]))))
//        let response = configStub.getCategoryID_endWith()
//        mapper = getMapper(version: 5)
//        var output: InAppFormData?
//        let expectations = expectation(description: "test_categoryID_emptyModel")
//        mapper.mapConfigResponse(event, response) { result in
//            output = result
//            expectations.fulfill()
//        }
//
//        waitForExpectations(timeout: 1)
//        let expected =  InAppTransitionData(inAppId: "0",
//                                            imageUrl: "1",
//                                            redirectUrl: "2",
//                                            intentPayload: "3")
//
//        XCTAssertEqual(expected.inAppId, output?.inAppId)
//        XCTAssertEqual(expected.intentPayload, output?.intentPayload)
//        XCTAssertEqual(expected.redirectUrl, output?.redirectUrl)
//    }
//
//    func test_categoryID_endWith_false() {
//        let event = ApplicationEvent(name: "Hello",
//                                     model: .init(viewProductCategory: .init(productCategory: .init(ids: [
//                                        "System1C": "Boats".uppercased(),
//                                        "TestSite": "Button".uppercased()
//                                     ]))))
//        let response = configStub.getCategoryID_endWith()
//        mapper = getMapper(version: 5)
//        testNil(event: event, response: response)
//    }
//
//    func test_categoryIDIn_any_true() {
//        let event = ApplicationEvent(name: "Hello", model: .init(viewProductCategory: .init(productCategory: .init(ids: ["System1C": "testik2"]))))
//        let response = configStub.getCategoryIDIn_Any()
//        mapper = getMapper(version: 5)
//        testResponse(event: event, response: response)
//    }
//
//    func test_categoryIDIn_any_false() {
//        let event = ApplicationEvent(name: "Hello", model: .init(viewProductCategory: .init(productCategory: .init(ids: ["System1C": "potato"]))))
//        let response = configStub.getCategoryIDIn_Any()
//        mapper = getMapper(version: 5)
//        testNil(event: event, response: response)
//    }
//
//    func test_categoryIDIn_none_true() {
//        let event = ApplicationEvent(name: "Hello", model: .init(viewProductCategory: .init(productCategory: .init(ids: ["System1C": "potato"]))))
//        let response = configStub.getCategoryIDIn_None()
//        mapper = getMapper(version: 5)
//        testResponse(event: event, response: response)
//    }
//
//    func test_categoryIDIn_none_false() {
//        let event = ApplicationEvent(name: "Hello", model: .init(viewProductCategory: .init(productCategory: .init(ids: ["System1C": "testik2"]))))
//        let response = configStub.getCategoryIDIn_None()
//        mapper = getMapper(version: 5)
//        testNil(event: event, response: response)
//    }
//
//    func test_productID_emptyModel() {
//        let event = ApplicationEvent(name: "Hello", model: nil)
//        let response = configStub.getProductID_Substring()
//        mapper = getMapper(version: 5)
//        testNil(event: event, response: response)
//    }
//
//    func test_productID_substring_true() {
//        let event = ApplicationEvent(name: "Hello", model: .init(viewProduct: .init(product: .init(ids:
//                                                                                                    ["website": "Boots".uppercased(),
//                                                                                                     "system1c": "81".uppercased()
//                                                                                                    ]))))
//        let response = configStub.getProductID_Substring()
//        mapper = getMapper(version: 5)
//        testResponse(event: event, response: response)
//    }
//
//    func test_productID_substring_false() {
//        let event = ApplicationEvent(name: "Hello", model: .init(viewProduct: .init(product: .init(ids:
//                                                                                                    ["website": "Bovts".uppercased(),
//                                                                                                     "system1c": "81".uppercased()
//                                                                                                    ]))))
//        let response = configStub.getProductID_Substring()
//        mapper = getMapper(version: 5)
//        testNil(event: event, response: response)
//    }
//
//    func test_productID_notSubstring_true() {
//        let event = ApplicationEvent(name: "Hello", model: .init(viewProduct: .init(product: .init(ids:
//                                                                                                    ["website": "Boots".uppercased(),
//                                                                                                     "system1c": "81".uppercased()
//                                                                                                    ]))))
//        let response = configStub.getProductID_notSubstring()
//        mapper = getMapper(version: 5)
//        testResponse(event: event, response: response)
//    }
//
//    func test_productID_notSubstring_false() {
//        let event = ApplicationEvent(name: "Hello", model: .init(viewProduct: .init(product: .init(ids:
//                                                                                                    ["website": "Boots".uppercased(),
//                                                                                                     "system1c": "Buttootn".uppercased()
//                                                                                                    ]))))
//        let response = configStub.getProductID_notSubstring()
//        mapper = getMapper(version: 5)
//        testNil(event: event, response: response)
//    }
//
//    func test_productID_startWith_true() {
//        let event = ApplicationEvent(name: "Hello", model: .init(viewProduct: .init(product: .init(ids:
//                                                                                                    ["website": "oots".uppercased(),
//                                                                                                     "system1c": "Button".uppercased()
//                                                                                                    ]))))
//        let response = configStub.getProductID_startsWith()
//        mapper = getMapper(version: 5)
//        testResponse(event: event, response: response)
//    }
//
//    func test_productID_startWith_false() {
//        let event = ApplicationEvent(name: "Hello", model: .init(viewProduct: .init(product: .init(ids:
//                                                                                                    ["website": "Boots".uppercased(),
//                                                                                                     "system1c": "Button".uppercased()
//                                                                                                    ]))))
//        let response = configStub.getProductID_startsWith()
//        mapper = getMapper(version: 5)
//        testNil(event: event, response: response)
//    }
//
//    func test_productID_endWith_true() {
//        let event = ApplicationEvent(name: "Hello", model: .init(viewProduct: .init(product: .init(ids:
//                                                                                                    ["website": "Boots".uppercased(),
//                                                                                                     "system1c": "Button".uppercased()
//                                                                                                    ]))))
//        let response = configStub.getProductID_endsWith()
//        mapper = getMapper(version: 5)
//        testResponse(event: event, response: response)
//    }
//
//    func test_productID_endWith_false() {
//        let event = ApplicationEvent(name: "Hello", model: .init(viewProduct: .init(product: .init(ids:
//                                                                                                    ["website": "Boats".uppercased(),
//                                                                                                     "system1c": "Button".uppercased()
//                                                                                                    ]))))
//        let response = configStub.getProductID_endsWith()
//        mapper = getMapper(version: 5)
//        testNil(event: event, response: response)
//    }
//
//    func test_productSegment_positive_true() throws {
//        let event = ApplicationEvent(name: "Hello", model: .init(viewProduct: .init(product: .init(ids: ["website": "49"]))))
//        let response = configStub.getProductSegment_Any()
//        let productSegments = InAppProductSegmentResponse(status: .success, products: [.init(ids: ["website": "49"],
//                                                                                             segmentations: [.init(ids: .init(externalId: "1"),
//                                                                                                                   segment: .init(ids: .init(externalId: "3")))])])
//        mapper = getMapper(version: 5, productSegments: productSegments)
//        mapper.targetingChecker.event = event
//        testResponse(event: event, response: response)
//    }
//
//    func test_productSegment_positive_false() throws {
//        let event = ApplicationEvent(name: "Hello", model: .init(viewProduct: .init(product: .init(ids: ["website": "49"]))))
//        let response = configStub.getProductSegment_Any()
//        mapper = getMapper(version: 5)
//        testNil(event: event, response: response)
//    }
//
//    func test_productSegment_negative_true() throws {
//        let event = ApplicationEvent(name: "Hello", model: .init(viewProduct: .init(product: .init(ids: ["website": "49"]))))
//        let response = configStub.getProductSegment_None()
//        let productSegments = InAppProductSegmentResponse(status: .success, products: [.init(ids: ["website": "49"],
//                                                                                             segmentations: [.init(ids: .init(externalId: "1"),
//                                                                                                                   segment: .init(ids: .init(externalId: "4")))])])
//        mapper = getMapper(version: 5, productSegments: productSegments)
//        mapper.targetingChecker.checkedProductSegmentations = [.init(ids: .init(externalId: "1"), segment: .init(ids: .init(externalId: "4")))]
//        testResponse(event: event, response: response)
//
//    }
//
//    func test_productSegment_negative_false() throws {
//        let event = ApplicationEvent(name: "Hello", model: .init(viewProduct: .init(product: .init(ids: ["website": "49"]))))
//        let response = configStub.getProductSegment_None()
//        mapper = getMapper(version: 5)
//        testNil(event: event, response: response)
//    }
//
//    func test_config_valid_to_parse() throws {
//        let response = try getConfig(name: "InappConfigResponseValid")
//
//        let inapps: [InApp]? = [.init(id: "6f93e2ef-0615-4e63-9c80-24bcb9e83b83",
//                                      sdkVersion: SdkVersion(min: 4, max: nil),
//                                      targeting: .and(AndTargeting(nodes: [.true(TrueTargeting())])),
//                                      form: InApp.InAppFormVariants(variants: [.init(imageUrl: "1",
//                                                                                     redirectUrl: "2",
//                                                                                     intentPayload: "3",
//                                                                                     type: "simpleImage")]))]
//
//        let abTestObject1 = ABTest.ABTestVariant.ABTestObject(
//            type: .inapps,
//            kind: .all,
//            inapps: ["inapp1", "inapp2"]
//        )
//
//        // Создаем структуры ABTestVariant
//        let abTestVariant1 = ABTest.ABTestVariant(
//            id: "1", modulus: ABTest.ABTestVariant.Modulus(lower: 0, upper: 50),
//            objects: [abTestObject1]
//        )
//
//        let abTestVariant2 = ABTest.ABTestVariant(
//            id: "2", modulus: ABTest.ABTestVariant.Modulus(lower: 50, upper: 100),
//            objects: [abTestObject1]
//        )
//        let abtests: [ABTest]? = [.init(id: "id123",
//                                        sdkVersion: .init(min: 1, max: nil),
//                                        salt: "salt123",
//                                        variants: [abTestVariant1,
//                                                   abTestVariant2]),
//        ]
//
//        let monitoring = Monitoring(logs: [.init(requestId: "request1",
//                                                 deviceUUID: "device1",
//                                                 from: "source1",
//                                                 to: "destination1"),
//                                           .init(requestId: "request2",
//                                                 deviceUUID: "device2",
//                                                 from: "source2",
//                                                 to: "destination2")])
//
//        let settings = Settings(operations: .init(viewProduct: .init(systemName: "product"),
//                                                  viewCategory: .init(systemName: "category"),
//                                                  setCart: .init(systemName: "cart")))
//
//        XCTAssertEqual(response.inapps, inapps)
//        XCTAssertEqual(response.abtests, abtests)
//        XCTAssertEqual(response.monitoring, monitoring)
//        XCTAssertEqual(response.settings, settings)
//    }
//}
//
//private extension InAppConfigResponseTests {
//    private func getConfig(name: String) throws -> ConfigResponse {
//        let bundle = Bundle(for: InAppConfigResponseTests.self)
//        let fileURL = bundle.url(forResource: name, withExtension: "json")!
//        let data = try Data(contentsOf: fileURL)
//        return try JSONDecoder().decode(ConfigResponse.self, from: data)
//    }
//
//    private func getMapper(version: Int, segments: SegmentationCheckResponse? = nil, productSegments: InAppProductSegmentResponse? = nil) -> InAppConfigutationMapper {
//        let sdkVersionValidator = SDKVersionValidator(sdkVersionNumeric: version)
//        let segmentationService = SegmentationService(customerSegmentsAPI: .init(fetchSegments: { segmentationCheckRequest, completion in
//            completion(segments)
//        }, fetchProductSegments: { segmentationCheckRequest, completion in
//            completion(productSegments)
//        }),
//                                                      sessionTemporaryStorage: sessionTemporaryStorage,
//                                                      targetingChecker: targetingChecker)
//        return InAppConfigutationMapper(geoService: container.geoService,
//                                        segmentationService: segmentationService,
//                                        customerSegmentsAPI: .live,
//                                        targetingChecker: targetingChecker,
//                                        sessionTemporaryStorage: sessionTemporaryStorage,
//                                        persistenceStorage: persistenceStorage,
//                                        sdkVersionValidator: sdkVersionValidator,
//                                        imageDownloadService: container.imageDownloadService,
//                                        abTestDeviceMixer: container.abTestDeviceMixer)
//    }
//
//    private func testNil(event: ApplicationEvent?, response: ConfigResponse) {
//        var output: InAppFormData?
//        let expectations = expectation(description: "testNil")
//        mapper.mapConfigResponse(event, response) { result in
//            output = result
//            expectations.fulfill()
//        }
//
//        waitForExpectations(timeout: 1)
//        XCTAssertNil(output)
//    }
//
//    private func testResponse(event: ApplicationEvent?, response: ConfigResponse) {
//        var output: InAppFormData?
//        let expectations = expectation(description: "test_categoryID_emptyModel")
//        mapper.mapConfigResponse(event, response) { result in
//            output = result
//            expectations.fulfill()
//        }
//
//        waitForExpectations(timeout: 1)
//        let expected =  InAppTransitionData(inAppId: "0",
//                                            imageUrl: "1",
//                                            redirectUrl: "2",
//                                            intentPayload: "3")
//
//        XCTAssertEqual(expected.inAppId, output?.inAppId)
//        XCTAssertEqual(expected.intentPayload, output?.intentPayload)
//        XCTAssertEqual(expected.redirectUrl, output?.redirectUrl)
//    }
//}
