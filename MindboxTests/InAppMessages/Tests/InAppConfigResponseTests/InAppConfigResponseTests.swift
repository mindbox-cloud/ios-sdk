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

class InAppConfigResponseTests: XCTestCase {

    var container = try! TestDependencyProvider()

    var sessionTemporaryStorage: SessionTemporaryStorage {
        container.sessionTemporaryStorage
    }

    var persistenceStorage: PersistenceStorage {
        container.persistenceStorage
    }

    var networkFetcher: NetworkFetcher {
        container.instanceFactory.makeNetworkFetcher()
    }

    private var mapper: InAppMapper!
    private let configStub = InAppConfigStub()
    private let targetingChecker: InAppTargetingCheckerProtocol = InAppTargetingChecker()
    private var shownInAppsIds: Set<String>!

    override func setUp() {
        super.setUp()
        mapper = InAppMapper(segmentationService: container.segmentationService,
                             geoService: container.geoService,
                             imageDownloadService: container.imageDownloaderService,
                             targetingChecker: targetingChecker,
                             persistenceStorage: persistenceStorage,
                             sessionTemporaryStorage: sessionTemporaryStorage,
                             customerAbMixer: container.customerAbMixer,
                             inAppsVersion: 1)
        shownInAppsIds = Set(persistenceStorage.shownInAppsIds ?? [])
    }
    
    func test_2InApps_oneFitsInAppsSdkVersion_andOneDoesnt() throws {
        let response = try getConfigWithTwoInapps()
        var output: InAppFormData?
        let expectations = expectation(description: "test_test")
        mapper.mapConfigResponse(nil, response) { result in
            output = result
            expectations.fulfill()
        }
        
        waitForExpectations(timeout: 1)
        
        let expected = InAppTransitionData(inAppId: "00000000-0000-0000-0000-000000000001",
                                           imageUrl: "https://s3-symbol-logo.tradingview.com/true-corporation-public-company-limited--600.png",
                                           redirectUrl: "", intentPayload: "")
        XCTAssertEqual(expected.inAppId, output?.inAppId)
        XCTAssertEqual(expected.intentPayload, output?.intentPayload)
        XCTAssertEqual(expected.redirectUrl, output?.redirectUrl)
    }

    func test_2InApps_bothFitInAppsSdkVersion() throws {
        let response = try getConfigWithTwoInapps()
        mapper.setInAppsVersion(3)
        var output: InAppFormData?
        let expectations = expectation(description: "test_2InApps_bothFitInAppsSdkVersion")
        mapper.mapConfigResponse(nil, response) { result in
            output = result
            expectations.fulfill()
        }
        
        waitForExpectations(timeout: 1)
        let expected = InAppTransitionData(inAppId: "00000000-0000-0000-0000-000000000001",
                                           imageUrl: "https://s3-symbol-logo.tradingview.com/true-corporation-public-company-limited--600.png",
                                           redirectUrl: "", intentPayload: "")

        XCTAssertEqual(expected.inAppId, output?.inAppId)
        XCTAssertEqual(expected.intentPayload, output?.intentPayload)
        XCTAssertEqual(expected.redirectUrl, output?.redirectUrl)
    }

    func test_2InApps_bothDontFitInAppsSdkVersion() throws {
        let response = try getConfigWithTwoInapps()
        mapper.setInAppsVersion(0)
        var output: InAppFormData?
        let expectations = expectation(description: "test_2InApps_bothDontFitInAppsSdkVersion")
        mapper.mapConfigResponse(nil, response) { result in
            output = result
            expectations.fulfill()
        }
        
        waitForExpectations(timeout: 1)
        
        XCTAssertNil(output)
    }

    func test_operation_happyFlow() throws {
        let response = try getConfigWithOperations()
        let event = ApplicationEvent(name: "TESTPushOK", model: nil)
        mapper.setInAppsVersion(4)

        var output: InAppFormData?
        let expectations = expectation(description: "test_operation_happyFlow")
        mapper.mapConfigResponse(event, response) { result in
            output = result
            expectations.fulfill()
        }
        
        waitForExpectations(timeout: 1)
        let expected = InAppTransitionData(inAppId: "00000000-0000-0000-0000-000000000001",
                                           imageUrl: "https://s3-symbol-logo.tradingview.com/true-corporation-public-company-limited--600.png",
                                           redirectUrl: "", intentPayload: "")

        XCTAssertEqual(expected.inAppId, output?.inAppId)
        XCTAssertEqual(expected.intentPayload, output?.intentPayload)
        XCTAssertEqual(expected.redirectUrl, output?.redirectUrl)
    }

    func test_operation_empty_operatonName() throws {
        let response = try getConfigWithOperations()
        let event = ApplicationEvent(name: "", model: nil)
        mapper.setInAppsVersion(4)
        
        var output: InAppFormData?
        let expectations = expectation(description: "test_operation_empty_operatonName")
        mapper.mapConfigResponse(event, response) { result in
            output = result
            expectations.fulfill()
        }
        
        waitForExpectations(timeout: 1)
        XCTAssertNil(output)
    }

    func test_operation_wrong_operatonName() throws {
        let response = try getConfigWithOperations()
        mapper.setInAppsVersion(4)
        let event = ApplicationEvent(name: "WrongOperationName", model: nil)
        var output: InAppFormData?
        let expectations = expectation(description: "test_operation_wrong_operatonName")
        mapper.mapConfigResponse(event, response) { result in
            output = result
            expectations.fulfill()
        }
        
        waitForExpectations(timeout: 1)
        XCTAssertNil(output)
    }

    func test_categoryID_emptyModel() {
        mapper.setInAppsVersion(5)
        let event = ApplicationEvent(name: "Hello", model: nil)
        var output: InAppFormData?
        let expectations = expectation(description: "test_categoryID_emptyModel")
        mapper.mapConfigResponse(event, configStub.getCategoryIDIn_Any()) { result in
            output = result
            expectations.fulfill()
        }
        
        waitForExpectations(timeout: 1)
        XCTAssertNil(output)
    }

    func test_categoryID_substring_true() {
        let response = configStub.getCategoryID_Substring()
        mapper.setInAppsVersion(5)
        let event = ApplicationEvent(name: "Hello",
                                     model: .init(viewProductCategory: .init(productCategory: .init(ids: [
                                        "System1C": "Boots".uppercased(),
                                        "TestSite": "81".uppercased()
                                     ]))))
        var output: InAppFormData?
        let expectations = expectation(description: "test_categoryID_substring_true")
        mapper.mapConfigResponse(event, configStub.getCategoryIDIn_Any()) { result in
            output = result
            expectations.fulfill()
        }
        
        waitForExpectations(timeout: 1)
        let expected = InAppTransitionData(inAppId: "0",
                                           imageUrl: "1",
                                           redirectUrl: "2", intentPayload: "3")

        XCTAssertEqual(expected.inAppId, output?.inAppId)
        XCTAssertEqual(expected.intentPayload, output?.intentPayload)
        XCTAssertEqual(expected.redirectUrl, output?.redirectUrl)
    }

    func test_categoryID_substring_false() {
        let event = ApplicationEvent(name: "Hello",
                                     model: .init(viewProductCategory: .init(productCategory: .init(ids: [
                                        "System1C": "Bovts".uppercased(),
                                        "TestSite": "81".uppercased()
                                     ]))))
        mapper.setInAppsVersion(5)
        var output: InAppFormData?
        let expectations = expectation(description: "test_categoryID_emptyModel")
        mapper.mapConfigResponse(event, configStub.getCategoryID_Substring()) { result in
            output = result
            expectations.fulfill()
        }
        
        waitForExpectations(timeout: 1)
        XCTAssertNil(output)
    }

    func test_categoryID_notSubstring_true() {
        let event = ApplicationEvent(name: "Hello",
                                     model: .init(viewProductCategory: .init(productCategory: .init(ids: [
                                        "System1C": "Boots".uppercased(),
                                        "TestSite": "Button".uppercased()
                                     ]))))
        mapper.setInAppsVersion(5)
        var output: InAppFormData?
        let expectations = expectation(description: "test_categoryID_emptyModel")
        mapper.mapConfigResponse(event, configStub.getCategoryID_notSubstring()) { result in
            output = result
            expectations.fulfill()
        }
        
        waitForExpectations(timeout: 1)
        let expected =  InAppTransitionData(inAppId: "0",
                                            imageUrl: "1",
                                            redirectUrl: "2",
                                            intentPayload: "3")

        XCTAssertEqual(expected.inAppId, output?.inAppId)
        XCTAssertEqual(expected.intentPayload, output?.intentPayload)
        XCTAssertEqual(expected.redirectUrl, output?.redirectUrl)
    }

    func test_categoryID_notSubstring_false() {
        let event = ApplicationEvent(name: "Hello",
                                     model: .init(viewProductCategory: .init(productCategory: .init(ids: [
                                        "System1C": "Boots".uppercased(),
                                        "TestSite": "Buttootn".uppercased()
                                     ]))))
        let response = configStub.getCategoryID_notSubstring()
        mapper.setInAppsVersion(5)
        var output: InAppFormData?
        let expectations = expectation(description: "test_categoryID_emptyModel")
        mapper.mapConfigResponse(event, response) { result in
            output = result
            expectations.fulfill()
        }
        
        waitForExpectations(timeout: 1)
        XCTAssertNil(output)
    }

    func test_categoryID_startWith_true() {
        let event = ApplicationEvent(name: "Hello",
                                     model: .init(viewProductCategory: .init(productCategory: .init(ids: [
                                        "System1C": "oots".uppercased(),
                                        "TestSite": "Button".uppercased()
                                     ]))))
        let response = configStub.getCategoryID_startWith()
        mapper.setInAppsVersion(5)
        var output: InAppFormData?
        let expectations = expectation(description: "test_categoryID_emptyModel")
        mapper.mapConfigResponse(event, response) { result in
            output = result
            expectations.fulfill()
        }
        
        waitForExpectations(timeout: 1)
        let expected =  InAppTransitionData(inAppId: "0",
                                            imageUrl: "1",
                                            redirectUrl: "2",
                                            intentPayload: "3")

        XCTAssertEqual(expected.inAppId, output?.inAppId)
        XCTAssertEqual(expected.intentPayload, output?.intentPayload)
        XCTAssertEqual(expected.redirectUrl, output?.redirectUrl)
    }

    func test_categoryID_startWith_false() {
        let event = ApplicationEvent(name: "Hello",
                                     model: .init(viewProductCategory: .init(productCategory: .init(ids: [
                                        "System1C": "Boots".uppercased(),
                                        "TestSite": "Button".uppercased()
                                     ]))))
        let response = configStub.getCategoryID_startWith()
        mapper.setInAppsVersion(5)
        var output: InAppFormData?
        let expectations = expectation(description: "test_categoryID_emptyModel")
        mapper.mapConfigResponse(event, response) { result in
            output = result
            expectations.fulfill()
        }
        
        waitForExpectations(timeout: 1)
        XCTAssertNil(output)
    }

    func test_categoryID_endWith_true() {
        let event = ApplicationEvent(name: "Hello",
                                     model: .init(viewProductCategory: .init(productCategory: .init(ids: [
                                        "System1C": "Boots".uppercased(),
                                        "TestSite": "Button".uppercased()
                                     ]))))
        let response = configStub.getCategoryID_endWith()
        mapper.setInAppsVersion(5)
        var output: InAppFormData?
        let expectations = expectation(description: "test_categoryID_emptyModel")
        mapper.mapConfigResponse(event, response) { result in
            output = result
            expectations.fulfill()
        }
        
        waitForExpectations(timeout: 1)
        let expected =  InAppTransitionData(inAppId: "0",
                                            imageUrl: "1",
                                            redirectUrl: "2",
                                            intentPayload: "3")

        XCTAssertEqual(expected.inAppId, output?.inAppId)
        XCTAssertEqual(expected.intentPayload, output?.intentPayload)
        XCTAssertEqual(expected.redirectUrl, output?.redirectUrl)
    }

    func test_categoryID_endWith_false() {
        let event = ApplicationEvent(name: "Hello",
                                     model: .init(viewProductCategory: .init(productCategory: .init(ids: [
                                        "System1C": "Boats".uppercased(),
                                        "TestSite": "Button".uppercased()
                                     ]))))
        let response = configStub.getCategoryID_endWith()
        mapper.setInAppsVersion(5)
        testNil(event: event, response: response)
    }

    func test_categoryIDIn_any_true() {
        let event = ApplicationEvent(name: "Hello", model: .init(viewProductCategory: .init(productCategory: .init(ids: ["System1C": "testik2"]))))
        let response = configStub.getCategoryIDIn_Any()
        mapper.setInAppsVersion(5)
        testResponse(event: event, response: response)
    }

    func test_categoryIDIn_any_false() {
        let event = ApplicationEvent(name: "Hello", model: .init(viewProductCategory: .init(productCategory: .init(ids: ["System1C": "potato"]))))
        let response = configStub.getCategoryIDIn_Any()
        mapper.setInAppsVersion(5)
        testNil(event: event, response: response)
    }

    func test_categoryIDIn_none_true() {
        let event = ApplicationEvent(name: "Hello", model: .init(viewProductCategory: .init(productCategory: .init(ids: ["System1C": "potato"]))))
        let response = configStub.getCategoryIDIn_None()
        mapper.setInAppsVersion(5)
        testResponse(event: event, response: response)
    }

    func test_categoryIDIn_none_false() {
        let event = ApplicationEvent(name: "Hello", model: .init(viewProductCategory: .init(productCategory: .init(ids: ["System1C": "testik2"]))))
        let response = configStub.getCategoryIDIn_None()
        mapper.setInAppsVersion(5)
        testNil(event: event, response: response)
    }

    func test_productID_emptyModel() {
        let event = ApplicationEvent(name: "Hello", model: nil)
        let response = configStub.getProductID_Substring()
        mapper.setInAppsVersion(5)
        testNil(event: event, response: response)
    }

    func test_productID_substring_true() {
        let event = ApplicationEvent(name: "Hello", model: .init(viewProduct: .init(product: .init(ids:
                                                                                                    ["website": "Boots".uppercased(),
                                                                                                     "system1c": "81".uppercased()
                                                                                                    ]))))
        let response = configStub.getProductID_Substring()
        mapper.setInAppsVersion(5)
        testResponse(event: event, response: response)
    }

    func test_productID_substring_false() {
        let event = ApplicationEvent(name: "Hello", model: .init(viewProduct: .init(product: .init(ids:
                                                                                                    ["website": "Bovts".uppercased(),
                                                                                                     "system1c": "81".uppercased()
                                                                                                    ]))))
        let response = configStub.getProductID_Substring()
        mapper.setInAppsVersion(5)
        testNil(event: event, response: response)
    }

    func test_productID_notSubstring_true() {
        let event = ApplicationEvent(name: "Hello", model: .init(viewProduct: .init(product: .init(ids:
                                                                                                    ["website": "Boots".uppercased(),
                                                                                                     "system1c": "81".uppercased()
                                                                                                    ]))))
        let response = configStub.getProductID_notSubstring()
        mapper.setInAppsVersion(5)
        testResponse(event: event, response: response)
    }

    func test_productID_notSubstring_false() {
        let event = ApplicationEvent(name: "Hello", model: .init(viewProduct: .init(product: .init(ids:
                                                                                                    ["website": "Boots".uppercased(),
                                                                                                     "system1c": "Buttootn".uppercased()
                                                                                                    ]))))
        let response = configStub.getProductID_notSubstring()
        mapper.setInAppsVersion(5)
        testNil(event: event, response: response)
    }

    func test_productID_startWith_true() {
        let event = ApplicationEvent(name: "Hello", model: .init(viewProduct: .init(product: .init(ids:
                                                                                                    ["website": "oots".uppercased(),
                                                                                                     "system1c": "Button".uppercased()
                                                                                                    ]))))
        let response = configStub.getProductID_startsWith()
        mapper.setInAppsVersion(5)
        testResponse(event: event, response: response)
    }

    func test_productID_startWith_false() {
        let event = ApplicationEvent(name: "Hello", model: .init(viewProduct: .init(product: .init(ids:
                                                                                                    ["website": "Boots".uppercased(),
                                                                                                     "system1c": "Button".uppercased()
                                                                                                    ]))))
        let response = configStub.getProductID_startsWith()
        mapper.setInAppsVersion(5)
        testNil(event: event, response: response)
    }

    func test_productID_endWith_true() {
        let event = ApplicationEvent(name: "Hello", model: .init(viewProduct: .init(product: .init(ids:
                                                                                                    ["website": "Boots".uppercased(),
                                                                                                     "system1c": "Button".uppercased()
                                                                                                    ]))))
        let response = configStub.getProductID_endsWith()
        mapper.setInAppsVersion(5)
        testResponse(event: event, response: response)
    }

    func test_productID_endWith_false() {
        let event = ApplicationEvent(name: "Hello", model: .init(viewProduct: .init(product: .init(ids:
                                                                                                    ["website": "Boats".uppercased(),
                                                                                                     "system1c": "Button".uppercased()
                                                                                                    ]))))
        let response = configStub.getProductID_endsWith()
        mapper.setInAppsVersion(5)
        testNil(event: event, response: response)
    }

    func test_productSegment_positive_true() throws {
//        let event = ApplicationEvent(name: "Hello", model: .init(viewProduct: .init(product: .init(ids: ["website": "49"]))))
//        let response = configStub.getProductSegment_Any()
//        mapper.setInAppsVersion(5)
//        mapper.targetingChecker.event = event
//        mapper.targetingChecker.checkedProductSegmentations = [.init(ids: .init(externalId: "1"),
//                                                                     segment: .init(ids: .init(externalId: "3")))]
//        testResponse(event: event, response: response)
        // Change SegmentationService(customerSegmentsAPI: .live
    }

    func test_productSegment_positive_false() throws {
        let event = ApplicationEvent(name: "Hello", model: .init(viewProduct: .init(product: .init(ids: ["website": "49"]))))
        let response = configStub.getProductSegment_Any()
        mapper.setInAppsVersion(5)
        testNil(event: event, response: response)
    }

    func test_productSegment_negative_true() throws {
//        let event = ApplicationEvent(name: "Hello", model: .init(viewProduct: .init(product: .init(ids: ["website": "49"]))))
//        let response = configStub.getProductSegment_None()
//        mapper.setInAppsVersion(5)
//        mapper.targetingChecker.checkedProductSegmentations = [.init(ids: .init(externalId: "1"), segment: .init(ids: .init(externalId: "4")))]
//        testResponse(event: event, response: response)
        // Change SegmentationService(customerSegmentsAPI: .live
    }

    func test_productSegment_negative_false() throws {
        let event = ApplicationEvent(name: "Hello", model: .init(viewProduct: .init(product: .init(ids: ["website": "49"]))))
        let response = configStub.getProductSegment_None()
        mapper.setInAppsVersion(5)
        testNil(event: event, response: response)
    }
    
    func test_AB_config1_case1() throws {
        let response = try getConfig(name: "ABCase1")
        
        let abTests: [InAppConfigResponse.ABTest] = [.init(id: "0ec6be6b-421f-464b-9ee4-348a5292a5fd",
                                                           sdkVersion: .init(min: 6, max: nil),
                                                           salt: "c0e2682c-3d0f-4291-9308-9e48a16eb3c8",
                                                           variants: [.init(modulus: .init(lower: 0, upper: 50),
                                                                            objects: [.init(type: "inapps",
                                                                                            kind: .concrete,
                                                                                            inapps: [])]),
                                                                      .init(modulus: .init(lower: 50, upper: 100),
                                                                            objects: [.init(type: "inapps",
                                                                                            kind: .all,
                                                                                            inapps: nil)])])]
        mapper.setInAppsVersion(6)
        persistenceStorage.deviceUUID = "BBBC2BA1-0B5B-4C9E-AB0E-95C54775B4F1"
        
        sessionTemporaryStorage.mockHashNumber = 25
        let inapps1 = mapper.filterInappsByABTests(abTests, responseInapps: response.inapps!)
        let inappIDs1 = inapps1.map { $0.id }
        XCTAssertTrue(inappIDs1.isEmpty)

        sessionTemporaryStorage.mockHashNumber = 75
        let inapps = mapper.filterInappsByABTests(abTests, responseInapps: response.inapps!)
        let expectedIDs = ["655f5ffa-de86-4224-a0bf-229fe208ed0d", "6f93e2ef-0615-4e63-9c80-24bcb9e83b83", "b33ca779-3c99-481f-ad46-91282b0caf04"]
        let inappIDs = inapps.map { $0.id }
        XCTAssertEqual(inappIDs, expectedIDs)
    }
    
    func test_AB_config2_case2() throws {
        
    }
}

private extension InAppConfigResponseTests {
    private func getConfigWithTwoInapps() throws -> InAppConfigResponse {
        let bundle = Bundle(for: InAppConfigResponseTests.self)
        let fileURL = bundle.url(forResource: "InAppConfiguration", withExtension: "json")!
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(InAppConfigResponse.self, from: data)
    }

    private func getConfigWithInvalidInapps() throws -> InAppConfigResponse {
        let bundle = Bundle(for: InAppConfigResponseTests.self)
        let fileURL = bundle.url(forResource: "InAppConfigurationInvalid", withExtension: "json")!
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(InAppConfigResponse.self, from: data)
    }

    private func getConfigWithOperations() throws -> InAppConfigResponse {
        let bundle = Bundle(for: InAppConfigResponseTests.self)
        let fileURL = bundle.url(forResource: "InAppConfigurationWithOperations", withExtension: "json")!
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(InAppConfigResponse.self, from: data)
    }
    
    private func getConfig(name: String) throws -> InAppConfigResponse {
        let bundle = Bundle(for: InAppConfigResponseTests.self)
        let fileURL = bundle.url(forResource: name, withExtension: "json")!
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(InAppConfigResponse.self, from: data)
    }
    
    private func testNil(event: ApplicationEvent?, response: InAppConfigResponse) {
        var output: InAppFormData?
        let expectations = expectation(description: "testNil")
        mapper.mapConfigResponse(event, response) { result in
            output = result
            expectations.fulfill()
        }
        
        waitForExpectations(timeout: 1)
        XCTAssertNil(output)
    }
    
    private func testResponse(event: ApplicationEvent?, response: InAppConfigResponse) {
        var output: InAppFormData?
        let expectations = expectation(description: "test_categoryID_emptyModel")
        mapper.mapConfigResponse(event, response) { result in
            output = result
            expectations.fulfill()
        }
        
        waitForExpectations(timeout: 1)
        let expected =  InAppTransitionData(inAppId: "0",
                                            imageUrl: "1",
                                            redirectUrl: "2",
                                            intentPayload: "3")

        XCTAssertEqual(expected.inAppId, output?.inAppId)
        XCTAssertEqual(expected.intentPayload, output?.intentPayload)
        XCTAssertEqual(expected.redirectUrl, output?.redirectUrl)
    }
}
