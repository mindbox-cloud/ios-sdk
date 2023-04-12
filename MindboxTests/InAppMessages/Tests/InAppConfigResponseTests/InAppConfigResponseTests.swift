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
    
    private let networkFetcher: NetworkFetcher = MockNetworkFetcher()
    private let targetingChecker: InAppTargetingCheckerProtocol = InAppTargetingChecker()
    private let sessionTemporaryStorage = SessionTemporaryStorage()
    private let configStub = InAppConfigStub()
    
    func test_2InApps_oneFitsInAppsSdkVersion_andOneDoesnt() throws {
        let response = try getConfigWithTwoInapps()
        var config: InAppConfig?
        let expectation = expectation(description: "test_2InApps_oneFitsInAppsSdkVersion_andOneDoesnt")
        let _ = InAppConfigutationMapper(customerSegmentsAPI: .live,
                                         inAppsVersion: 1,
                                         targetingChecker: targetingChecker,
                                         networkFetcher: networkFetcher,
                                         sessionTemporaryStorage: sessionTemporaryStorage)
            .mapConfigResponse(nil, response, { result in
                config = result
                expectation.fulfill()
            })
        
        waitForExpectations(timeout: 5)
        
        let expected = InAppConfig(inAppsByEvent: [
            .start: [
                .init(id: "00000000-0000-0000-0000-000000000001",
                      formDataVariants: [
                        .init(imageUrl: "https://s3-symbol-logo.tradingview.com/true-corporation-public-company-limited--600.png",
                              redirectUrl: "",
                              intentPayload: "")])]
        ])
        
        XCTAssertEqual(expected, config)
    }
    
    func test_2InApps_bothFitInAppsSdkVersion() throws {
        let response = try getConfigWithTwoInapps()
        var config: InAppConfig?
        let expectation = expectation(description: "test_2InApps_bothFitInAppsSdkVersion")
        let _ = InAppConfigutationMapper(customerSegmentsAPI: .live,
                                         inAppsVersion: 3,
                                         targetingChecker: targetingChecker,
                                         networkFetcher: networkFetcher,
                                         sessionTemporaryStorage: sessionTemporaryStorage)
            .mapConfigResponse(nil, response, { result in
                config = result
                expectation.fulfill()
            })
        
        waitForExpectations(timeout: 5)
        
        let expected = InAppConfig(inAppsByEvent: [
            .start: [
                .init(id: "00000000-0000-0000-0000-000000000001",
                      formDataVariants: [
                        .init(imageUrl: "https://s3-symbol-logo.tradingview.com/true-corporation-public-company-limited--600.png",
                              redirectUrl: "",
                              intentPayload: "")]),
                .init(id: "00000000-0000-0000-0000-000000000002",
                      formDataVariants: [
                        .init(imageUrl: "https://s3-symbol-logo.tradingview.com/true-corporation-public-company-limited--600.png",
                              redirectUrl: "",
                              intentPayload: "")])]
        ])
        
        XCTAssertEqual(expected, config)
    }
    
    func test_invalidInApps() throws {
        let response = try getConfigWithInvalidInapps()
        var config: InAppConfig?
        let expectation = self.expectation(description: "test_invalidInApps")
        let _ = InAppConfigutationMapper(customerSegmentsAPI: .live,
                                         inAppsVersion: 3,
                                         targetingChecker: targetingChecker,
                                         networkFetcher: networkFetcher,
                                         sessionTemporaryStorage: sessionTemporaryStorage)
            .mapConfigResponse(nil, response, { result in
                config = result
                expectation.fulfill()
            })
        
        waitForExpectations(timeout: 5)
        
        guard let config = config else { return }
        XCTAssertEqual(1, config.inAppsByEvent.count)
        let inappsForStartEvent = config.inAppsByEvent[.start]!
        XCTAssertEqual(1, inappsForStartEvent.count)
        let onlyValidInapp = inappsForStartEvent.first!
        XCTAssertEqual(onlyValidInapp.id, "00000000-0000-0000-0000-000000000002")
    }
    
    func test_2InApps_bothDontFitInAppsSdkVersion() throws {
        let response = try getConfigWithTwoInapps()
        var config: InAppConfig?
        let expectation = self.expectation(description: "test_2InApps_bothDontFitInAppsSdkVersion")
        let _ = InAppConfigutationMapper(customerSegmentsAPI: .live,
                                         inAppsVersion: 0,
                                         targetingChecker: targetingChecker,
                                         networkFetcher: networkFetcher,
                                         sessionTemporaryStorage: sessionTemporaryStorage)
            .mapConfigResponse(nil, response, { result in
                config = result
                expectation.fulfill()
            })
        
        let expected = InAppConfig(inAppsByEvent: [:])
        
        waitForExpectations(timeout: 5)
        XCTAssertEqual(expected, config)
    }
    
    func test_operation_happyFlow() throws {
        let response = try getConfigWithOperations()
        var config: InAppConfig?
        let expectation = self.expectation(description: "test_operations_happyFlow")
        let event = ApplicationEvent(name: "TESTPushOK", model: nil)
        let _ = InAppConfigutationMapper(customerSegmentsAPI: .live,
                                         inAppsVersion: 4,
                                         targetingChecker: targetingChecker,
                                         networkFetcher: networkFetcher,
                                         sessionTemporaryStorage: sessionTemporaryStorage)
            .mapConfigResponse(event, response) { result in
                config = result
                expectation.fulfill()
            }
        
        let expectedEvent = ApplicationEvent(name: "testpushok", model: nil)
        let expected = InAppConfig(inAppsByEvent: [
            .applicationEvent(expectedEvent): [
                .init(id: "00000000-0000-0000-0000-000000000001",
                      formDataVariants: [
                        .init(imageUrl: "https://s3-symbol-logo.tradingview.com/true-corporation-public-company-limited--600.png",
                              redirectUrl: "",
                              intentPayload: "")])]
        ])
        waitForExpectations(timeout: 5)
        XCTAssertEqual(expected, config)
    }
    
    func test_operation_empty_operatonName() throws {
        let response = try getConfigWithOperations()
        var config: InAppConfig?
        let expectation = self.expectation(description: "test_operations_happyFlow")
        let _ = InAppConfigutationMapper(customerSegmentsAPI: .live,
                                         inAppsVersion: 4,
                                         targetingChecker: targetingChecker,
                                         networkFetcher: networkFetcher,
                                         sessionTemporaryStorage: sessionTemporaryStorage)
            .mapConfigResponse(nil, response) { result in
                config = result
                expectation.fulfill()
            }
        
        let expected = InAppConfig(inAppsByEvent: [:])
        waitForExpectations(timeout: 5)
        
        XCTAssertEqual(expected, config)
    }
    
    func test_operation_wrong_operatonName() throws {
        let response = try getConfigWithOperations()
        var config: InAppConfig?
        let expectation = self.expectation(description: "test_operations_happyFlow")
        let event = ApplicationEvent(name: "WrongOperationName", model: nil)
        let _ = InAppConfigutationMapper(customerSegmentsAPI: .live, inAppsVersion: 4, targetingChecker: targetingChecker, networkFetcher: networkFetcher, sessionTemporaryStorage: sessionTemporaryStorage)
            .mapConfigResponse(event, response) { result in
                config = result
                expectation.fulfill()
            }
        
        let expected = InAppConfig(inAppsByEvent: [:])
        waitForExpectations(timeout: 5)
        
        XCTAssertEqual(expected, config)
    }
    
    func test_categoryID_emptyModel() {
        var config: InAppConfig?
        let expectation = self.expectation(description: "test_categoryID_emptyModel")
        let event = ApplicationEvent(name: "Hello", model: nil)
        
        let _ = InAppConfigutationMapper(customerSegmentsAPI: .live, inAppsVersion: 5, targetingChecker: targetingChecker, networkFetcher: networkFetcher, sessionTemporaryStorage: sessionTemporaryStorage)
            .mapConfigResponse(event, configStub.getCategoryID_Substring()) { result in
                config = result
                expectation.fulfill()
            }
        
        let expected = InAppConfig(inAppsByEvent: [:])
        waitForExpectations(timeout: 3)
        XCTAssertEqual(expected, config)
    }
    
    func test_categoryID_substring_true() {
        var config: InAppConfig?
        let expectation = self.expectation(description: "test_categoryID_substring_true")
        let event = ApplicationEvent(name: "Hello",
                                     model: .init(viewProductCategory: .init(productCategory: .init(ids: [
                                        "System1C": "Boots".uppercased(),
                                        "TestSite": "81".uppercased()
                                     ]))))
        let _ = InAppConfigutationMapper(customerSegmentsAPI: .live, inAppsVersion: 5, targetingChecker: targetingChecker, networkFetcher: networkFetcher, sessionTemporaryStorage: sessionTemporaryStorage)
            .mapConfigResponse(event, configStub.getCategoryID_Substring()) { result in
                config = result
                expectation.fulfill()
            }
        
        let expected = InAppConfig(inAppsByEvent: [
            .applicationEvent(event): [
                .init(id: "0",
                      formDataVariants: [
                        .init(imageUrl: "1",
                              redirectUrl: "2",
                              intentPayload: "3")])]
        ])
        waitForExpectations(timeout: 3)
        XCTAssertEqual(expected, config)
    }
    
    func test_categoryID_substring_false() {
        var config: InAppConfig?
        let expectation = self.expectation(description: "test_categoryID_substring_false")
        let event = ApplicationEvent(name: "Hello",
                                     model: .init(viewProductCategory: .init(productCategory: .init(ids: [
                                        "System1C": "Bovts".uppercased(),
                                        "TestSite": "81".uppercased()
                                     ]))))
        let _ = InAppConfigutationMapper(customerSegmentsAPI: .live, inAppsVersion: 5, targetingChecker: targetingChecker, networkFetcher: networkFetcher, sessionTemporaryStorage: sessionTemporaryStorage)
            .mapConfigResponse(event, configStub.getCategoryID_Substring()) { result in
                config = result
                expectation.fulfill()
            }
        
        let expected = InAppConfig(inAppsByEvent: [:])
        waitForExpectations(timeout: 3)
        XCTAssertEqual(expected, config)
    }
    
    func test_categoryID_notSubstring_true() {
        var config: InAppConfig?
        let expectation = self.expectation(description: "test_categoryID_notSubstring_true")
        let event = ApplicationEvent(name: "Hello",
                                     model: .init(viewProductCategory: .init(productCategory: .init(ids: [
                                        "System1C": "Boots".uppercased(),
                                        "TestSite": "Button".uppercased()
                                     ]))))
        let _ = InAppConfigutationMapper(customerSegmentsAPI: .live, inAppsVersion: 5, targetingChecker: targetingChecker, networkFetcher: networkFetcher, sessionTemporaryStorage: sessionTemporaryStorage)
            .mapConfigResponse(event, configStub.getCategoryID_notSubstring()) { result in
                config = result
                expectation.fulfill()
            }
        
        let expected = InAppConfig(inAppsByEvent: [
            .applicationEvent(event): [
                .init(id: "0",
                      formDataVariants: [
                        .init(imageUrl: "1",
                              redirectUrl: "2",
                              intentPayload: "3")])]
        ])
        waitForExpectations(timeout: 3)
        XCTAssertEqual(expected, config)
    }
    
    func test_categoryID_notSubstring_false() {
        var config: InAppConfig?
        let expectation = self.expectation(description: "test_categoryID_notSubstring_false")
        let event = ApplicationEvent(name: "Hello",
                                     model: .init(viewProductCategory: .init(productCategory: .init(ids: [
                                        "System1C": "Boots".uppercased(),
                                        "TestSite": "Buttootn".uppercased()
                                     ]))))
        let _ = InAppConfigutationMapper(customerSegmentsAPI: .live, inAppsVersion: 5, targetingChecker: targetingChecker, networkFetcher: networkFetcher, sessionTemporaryStorage: sessionTemporaryStorage)
            .mapConfigResponse(event, configStub.getCategoryID_notSubstring()) { result in
                config = result
                expectation.fulfill()
            }
        
        let expected = InAppConfig(inAppsByEvent: [:])
        waitForExpectations(timeout: 3)
        XCTAssertEqual(expected, config)
    }
    
    func test_categoryID_startWith_true() {
        var config: InAppConfig?
        let expectation = self.expectation(description: "test_categoryID_startWith_true")
        let event = ApplicationEvent(name: "Hello",
                                     model: .init(viewProductCategory: .init(productCategory: .init(ids: ["System1C": "oots".uppercased(),
                                                                                                          "TestSite": "Button".uppercased()]))))
        let _ = InAppConfigutationMapper(customerSegmentsAPI: .live, inAppsVersion: 5, targetingChecker: targetingChecker, networkFetcher: networkFetcher, sessionTemporaryStorage: sessionTemporaryStorage)
            .mapConfigResponse(event, configStub.getCategoryID_startWith()) { result in
                config = result
                expectation.fulfill()
            }
        
        let expected = InAppConfig(inAppsByEvent: [
            .applicationEvent(event): [
                .init(id: "0",
                      formDataVariants: [
                        .init(imageUrl: "1",
                              redirectUrl: "2",
                              intentPayload: "3")])]
        ])
        waitForExpectations(timeout: 3)
        XCTAssertEqual(expected, config)
    }
    
    func test_categoryID_startWith_false() {
        var config: InAppConfig?
        let expectation = self.expectation(description: "test_categoryID_startWith_false")
        let event = ApplicationEvent(name: "Hello",
                                     model: .init(viewProductCategory: .init(productCategory: .init(ids: ["System1C": "Boots".uppercased(),
                                                                                                          "TestSite": "Button".uppercased()]))))
        let _ = InAppConfigutationMapper(customerSegmentsAPI: .live, inAppsVersion: 5, targetingChecker: targetingChecker, networkFetcher: networkFetcher, sessionTemporaryStorage: sessionTemporaryStorage)
            .mapConfigResponse(event, configStub.getCategoryID_startWith()) { result in
                config = result
                expectation.fulfill()
            }
        
        let expected = InAppConfig(inAppsByEvent: [:])
        waitForExpectations(timeout: 3)
        XCTAssertEqual(expected, config)
    }
    
    func test_categoryID_endWith_true() {
        var config: InAppConfig?
        let expectation = self.expectation(description: "test_categoryID_endWith_true")
        let event = ApplicationEvent(name: "Hello",
                                     model: .init(viewProductCategory: .init(productCategory: .init(ids: ["System1C": "Boots".uppercased(),
                                                                                                          "TestSite": "Button".uppercased()]))))
        let _ = InAppConfigutationMapper(customerSegmentsAPI: .live, inAppsVersion: 5, targetingChecker: targetingChecker, networkFetcher: networkFetcher, sessionTemporaryStorage: sessionTemporaryStorage)
            .mapConfigResponse(event, configStub.getCategoryID_endWith()) { result in
                config = result
                expectation.fulfill()
            }
        
        let expected = InAppConfig(inAppsByEvent: [
            .applicationEvent(event): [
                .init(id: "0",
                      formDataVariants: [
                        .init(imageUrl: "1",
                              redirectUrl: "2",
                              intentPayload: "3")])]
        ])
        waitForExpectations(timeout: 3)
        XCTAssertEqual(expected, config)
    }
    
    func test_categoryID_endWith_false() {
        var config: InAppConfig?
        let expectation = self.expectation(description: "test_categoryID_endWith_false")
        let event = ApplicationEvent(name: "Hello",
                                     model: .init(viewProductCategory: .init(productCategory: .init(ids: ["System1C": "Boats".uppercased(),
                                                                                                          "TestSite": "Button".uppercased()]))))
        let _ = InAppConfigutationMapper(customerSegmentsAPI: .live, inAppsVersion: 5, targetingChecker: targetingChecker, networkFetcher: networkFetcher, sessionTemporaryStorage: sessionTemporaryStorage)
            .mapConfigResponse(event, configStub.getCategoryID_endWith()) { result in
                config = result
                expectation.fulfill()
            }
        
        let expected = InAppConfig(inAppsByEvent: [:])
        waitForExpectations(timeout: 3)
        XCTAssertEqual(expected, config)
    }
    
    func test_categoryIDIn_any_true() throws {
        var config: InAppConfig?
        let expectation = self.expectation(description: "test_categoryIDIn_any_true")
        let event = ApplicationEvent(name: "Hello", model: .init(viewProductCategory: .init(productCategory: .init(ids: ["System1C": "testik2"]))))
        let _ = InAppConfigutationMapper(customerSegmentsAPI: .live, inAppsVersion: 5, targetingChecker: targetingChecker, networkFetcher: networkFetcher, sessionTemporaryStorage: sessionTemporaryStorage)
            .mapConfigResponse(event, configStub.getCategoryIDIn_Any()) { result in
                config = result
                expectation.fulfill()
            }
        
        let expected = InAppConfig(inAppsByEvent: [
            .applicationEvent(event): [
                .init(id: "0",
                      formDataVariants: [
                        .init(imageUrl: "1",
                              redirectUrl: "2",
                              intentPayload: "3")])]
        ])
        waitForExpectations(timeout: 3)
        XCTAssertEqual(expected, config)
    }
    
    func test_categoryIDIn_any_false() throws {
        var config: InAppConfig?
        let expectation = self.expectation(description: "test_categoryIDIn_any_false")
        let event = ApplicationEvent(name: "Hello", model: .init(viewProductCategory: .init(productCategory: .init(ids: ["System1C": "potato"]))))
        let _ = InAppConfigutationMapper(customerSegmentsAPI: .live, inAppsVersion: 5, targetingChecker: targetingChecker, networkFetcher: networkFetcher, sessionTemporaryStorage: sessionTemporaryStorage)
            .mapConfigResponse(event, configStub.getCategoryIDIn_Any()) { result in
                config = result
                expectation.fulfill()
            }
        
        let expected = InAppConfig(inAppsByEvent: [:])
        waitForExpectations(timeout: 3)
        XCTAssertEqual(expected, config)
    }
    
    func test_categoryIDIn_none_true() throws {
        var config: InAppConfig?
        let expectation = self.expectation(description: "test_categoryIDIn_none_true")
        let event = ApplicationEvent(name: "Hello", model: .init(viewProductCategory: .init(productCategory: .init(ids: ["System1C": "potato"]))))
        let _ = InAppConfigutationMapper(customerSegmentsAPI: .live, inAppsVersion: 5, targetingChecker: targetingChecker, networkFetcher: networkFetcher, sessionTemporaryStorage: sessionTemporaryStorage)
            .mapConfigResponse(event, configStub.getCategoryIDIn_None()) { result in
                config = result
                expectation.fulfill()
            }
        
        let expected = InAppConfig(inAppsByEvent: [
            .applicationEvent(event): [
                .init(id: "0",
                      formDataVariants: [
                        .init(imageUrl: "1",
                              redirectUrl: "2",
                              intentPayload: "3")])]
        ])
        waitForExpectations(timeout: 3)
        XCTAssertEqual(expected, config)
    }
    
    func test_categoryIDIn_none_false() throws {
        var config: InAppConfig?
        let expectation = self.expectation(description: "test_categoryIDIn_none_false")
        let event = ApplicationEvent(name: "Hello", model: .init(viewProductCategory: .init(productCategory: .init(ids: ["System1C": "testik2"]))))
        let _ = InAppConfigutationMapper(customerSegmentsAPI: .live, inAppsVersion: 5, targetingChecker: targetingChecker, networkFetcher: networkFetcher, sessionTemporaryStorage: sessionTemporaryStorage)
            .mapConfigResponse(event, configStub.getCategoryIDIn_None()) { result in
                config = result
                expectation.fulfill()
            }
        
        let expected = InAppConfig(inAppsByEvent: [:])
        waitForExpectations(timeout: 3)
        XCTAssertEqual(expected, config)
    }

    func test_productID_emptyModel() {
        var config: InAppConfig?
        let expectation = self.expectation(description: "test_productID_emptyModel")
        let event = ApplicationEvent(name: "Hello", model: nil)

        let _ = InAppConfigutationMapper(customerSegmentsAPI: .live, inAppsVersion: 5, targetingChecker: targetingChecker, networkFetcher: networkFetcher, sessionTemporaryStorage: sessionTemporaryStorage)
            .mapConfigResponse(event, configStub.getProductID_Substring()) { result in
                config = result
                expectation.fulfill()
            }

        let expected = InAppConfig(inAppsByEvent: [:])
        waitForExpectations(timeout: 3)
        XCTAssertEqual(expected, config)
    }

    func test_productID_substring_true() {
        var config: InAppConfig?
        let expectation = self.expectation(description: "test_productID_substring_true")
        let event = ApplicationEvent(name: "Hello",
                                     model: .init(viewProduct: .init(product: .init(ids:
                                                                                        ["website": "Boots".uppercased(),
                                                                                         "system1c": "81".uppercased()
                                                                                        ]))))
        let _ = InAppConfigutationMapper(customerSegmentsAPI: .live, inAppsVersion: 5, targetingChecker: targetingChecker, networkFetcher: networkFetcher, sessionTemporaryStorage: sessionTemporaryStorage)
            .mapConfigResponse(event, configStub.getProductID_Substring()) { result in
                config = result
                expectation.fulfill()
            }

        let expected = InAppConfig(inAppsByEvent: [
            .applicationEvent(event): [
                .init(id: "0",
                      formDataVariants: [
                        .init(imageUrl: "1",
                              redirectUrl: "2",
                              intentPayload: "3")])]
        ])
        waitForExpectations(timeout: 3)
        XCTAssertEqual(expected, config)
    }

    func test_productID_substring_false() {
        var config: InAppConfig?
        let expectation = self.expectation(description: "test_productID_substring_false")
        let event = ApplicationEvent(name: "Hello",
                                     model: .init(viewProduct: .init(product: .init(ids:
                                                                                        ["website": "Bovts".uppercased(),
                                                                                         "system1c": "81".uppercased()
                                                                                        ]))))
        let _ = InAppConfigutationMapper(customerSegmentsAPI: .live, inAppsVersion: 5, targetingChecker: targetingChecker, networkFetcher: networkFetcher, sessionTemporaryStorage: sessionTemporaryStorage)
            .mapConfigResponse(event, configStub.getProductID_Substring()) { result in
                config = result
                expectation.fulfill()
            }

        let expected = InAppConfig(inAppsByEvent: [:])
        waitForExpectations(timeout: 3)
        XCTAssertEqual(expected, config)
    }

    func test_productID_notSubstring_true() {
        var config: InAppConfig?
        let expectation = self.expectation(description: "test_productID_notSubstring_true")
        let event = ApplicationEvent(name: "Hello",
                                     model: .init(viewProduct: .init(product: .init(ids:
                                                                                        ["website": "Boots".uppercased(),
                                                                                         "system1c": "81".uppercased()
                                                                                        ]))))
        let _ = InAppConfigutationMapper(customerSegmentsAPI: .live, inAppsVersion: 5, targetingChecker: targetingChecker, networkFetcher: networkFetcher, sessionTemporaryStorage: sessionTemporaryStorage)
            .mapConfigResponse(event, configStub.getProductID_notSubstring()) { result in
                config = result
                expectation.fulfill()
            }

        let expected = InAppConfig(inAppsByEvent: [
            .applicationEvent(event): [
                .init(id: "0",
                      formDataVariants: [
                        .init(imageUrl: "1",
                              redirectUrl: "2",
                              intentPayload: "3")])]
        ])
        waitForExpectations(timeout: 3)
        XCTAssertEqual(expected, config)
    }

    func test_productID_notSubstring_false() {
        var config: InAppConfig?
        let expectation = self.expectation(description: "test_productID_notSubstring_false")
        let event = ApplicationEvent(name: "Hello",
                                     model: .init(viewProduct: .init(product: .init(ids:
                                                                                        ["website": "Boots".uppercased(),
                                                                                         "system1c": "Buttootn".uppercased()
                                                                                        ]))))
        let _ = InAppConfigutationMapper(customerSegmentsAPI: .live, inAppsVersion: 5, targetingChecker: targetingChecker, networkFetcher: networkFetcher, sessionTemporaryStorage: sessionTemporaryStorage)
            .mapConfigResponse(event, configStub.getProductID_notSubstring()) { result in
                config = result
                expectation.fulfill()
            }

        let expected = InAppConfig(inAppsByEvent: [:])
        waitForExpectations(timeout: 3)
        XCTAssertEqual(expected, config)
    }

    func test_productID_startWith_true() {
        var config: InAppConfig?
        let expectation = self.expectation(description: "test_productID_startWith_true")
        let event = ApplicationEvent(name: "Hello",
                                     model: .init(viewProduct: .init(product: .init(ids:
                                                                                        ["website": "oots".uppercased(),
                                                                                         "system1c": "Button".uppercased()
                                                                                        ]))))
        let _ = InAppConfigutationMapper(customerSegmentsAPI: .live, inAppsVersion: 5, targetingChecker: targetingChecker, networkFetcher: networkFetcher, sessionTemporaryStorage: sessionTemporaryStorage)
            .mapConfigResponse(event, configStub.getProductID_startsWith()) { result in
                config = result
                expectation.fulfill()
            }

        let expected = InAppConfig(inAppsByEvent: [
            .applicationEvent(event): [
                .init(id: "0",
                      formDataVariants: [
                        .init(imageUrl: "1",
                              redirectUrl: "2",
                              intentPayload: "3")])]
        ])
        waitForExpectations(timeout: 3)
        XCTAssertEqual(expected, config)
    }

    func test_productID_startWith_false() {
        var config: InAppConfig?
        let expectation = self.expectation(description: "test_productID_startWith_false")
        let event = ApplicationEvent(name: "Hello",
                                     model: .init(viewProduct: .init(product: .init(ids:
                                                                                        ["website": "Boots".uppercased(),
                                                                                         "system1c": "Button".uppercased()
                                                                                        ]))))
        let _ = InAppConfigutationMapper(customerSegmentsAPI: .live, inAppsVersion: 5, targetingChecker: targetingChecker, networkFetcher: networkFetcher, sessionTemporaryStorage: sessionTemporaryStorage)
            .mapConfigResponse(event, configStub.getProductID_startsWith()) { result in
                config = result
                expectation.fulfill()
            }

        let expected = InAppConfig(inAppsByEvent: [:])
        waitForExpectations(timeout: 3)
        XCTAssertEqual(expected, config)
    }

    func test_productID_endWith_true() {
        var config: InAppConfig?
        let expectation = self.expectation(description: "test_productID_endWith_true")
        let event = ApplicationEvent(name: "Hello",
                                     model: .init(viewProduct: .init(product: .init(ids:
                                                                                        ["website": "Boots".uppercased(),
                                                                                         "system1c": "Button".uppercased()
                                                                                        ]))))
        let _ = InAppConfigutationMapper(customerSegmentsAPI: .live, inAppsVersion: 5, targetingChecker: targetingChecker, networkFetcher: networkFetcher, sessionTemporaryStorage: sessionTemporaryStorage)
            .mapConfigResponse(event, configStub.getProductID_endsWith()) { result in
                config = result
                expectation.fulfill()
            }

        let expected = InAppConfig(inAppsByEvent: [
            .applicationEvent(event): [
                .init(id: "0",
                      formDataVariants: [
                        .init(imageUrl: "1",
                              redirectUrl: "2",
                              intentPayload: "3")])]
        ])
        waitForExpectations(timeout: 3)
        XCTAssertEqual(expected, config)
    }

    func test_productID_endWith_false() {
        var config: InAppConfig?
        let expectation = self.expectation(description: "test_productID_endWith_false")
        let event = ApplicationEvent(name: "Hello",
                                     model: .init(viewProduct: .init(product: .init(ids:
                                                                                        ["website": "Boats".uppercased(),
                                                                                         "system1c": "Button".uppercased()
                                                                                        ]))))
        let _ = InAppConfigutationMapper(customerSegmentsAPI: .live, inAppsVersion: 5, targetingChecker: targetingChecker, networkFetcher: networkFetcher, sessionTemporaryStorage: sessionTemporaryStorage)
            .mapConfigResponse(event, configStub.getProductID_endsWith()) { result in
                config = result
                expectation.fulfill()
            }

        let expected = InAppConfig(inAppsByEvent: [:])
        waitForExpectations(timeout: 3)
        XCTAssertEqual(expected, config)
    }

    func test_productSegment_positive_true() throws {
        var config: InAppConfig?
        let expectation = self.expectation(description: "test_productSegment_positive_true")
        let event = ApplicationEvent(name: "Hello", model: .init(viewProduct: .init(product: .init(ids: ["website": "49"]))))
        let mapper: InAppConfigurationMapperProtocol = InAppConfigutationMapper(customerSegmentsAPI: .live, inAppsVersion: 5, targetingChecker: targetingChecker, networkFetcher: networkFetcher, sessionTemporaryStorage: sessionTemporaryStorage)

        mapper.mapConfigResponse(event, configStub.getProductSegment_Any()) { result in
            config = result
            expectation.fulfill()
        }

        mapper.targetingChecker.checkedProductSegmentations = [.init(ids: .init(externalId: "1"), segment: .init(ids: .init(externalId: "3")))]

        let expected = InAppConfig(inAppsByEvent: [
            .applicationEvent(event): [
                .init(id: "0",
                      formDataVariants: [
                        .init(imageUrl: "1",
                              redirectUrl: "2",
                              intentPayload: "3")])]
        ])
        waitForExpectations(timeout: 3)
        XCTAssertEqual(expected, config)
    }

    func test_productSegment_positive_false() throws {
        var config: InAppConfig?
        let expectation = self.expectation(description: "test_productSegment_positive_false")
        let event = ApplicationEvent(name: "Hello", model: .init(viewProduct: .init(product: .init(ids: ["website": "49"]))))
        let mapper: InAppConfigurationMapperProtocol = InAppConfigutationMapper(customerSegmentsAPI: .live, inAppsVersion: 5, targetingChecker: targetingChecker, networkFetcher: networkFetcher, sessionTemporaryStorage: sessionTemporaryStorage)

        mapper.mapConfigResponse(event, configStub.getProductSegment_Any()) { result in
            config = result
            expectation.fulfill()
        }

        mapper.targetingChecker.checkedProductSegmentations = []

        let expected = InAppConfig(inAppsByEvent: [:])
        waitForExpectations(timeout: 3)
        XCTAssertEqual(expected, config)
    }

    func test_productSegment_negative_true() throws {
        var config: InAppConfig?
        let expectation = self.expectation(description: "test_productSegment_negative_true")
        let event = ApplicationEvent(name: "Hello", model: .init(viewProduct: .init(product: .init(ids: ["website": "49"]))))
        let mapper: InAppConfigurationMapperProtocol = InAppConfigutationMapper(customerSegmentsAPI: .live, inAppsVersion: 5, targetingChecker: targetingChecker, networkFetcher: networkFetcher, sessionTemporaryStorage: sessionTemporaryStorage)

        mapper.mapConfigResponse(event, configStub.getProductSegment_None()) { result in
            config = result
            expectation.fulfill()
        }

        mapper.targetingChecker.checkedProductSegmentations = [.init(ids: .init(externalId: "1"), segment: .init(ids: .init(externalId: "4")))]

        let expected = InAppConfig(inAppsByEvent: [
            .applicationEvent(event): [
                .init(id: "0",
                      formDataVariants: [
                        .init(imageUrl: "1",
                              redirectUrl: "2",
                              intentPayload: "3")])]
        ])
        waitForExpectations(timeout: 3)
        XCTAssertEqual(expected, config)
    }

    func test_productSegment_negative_false() throws {
        var config: InAppConfig?
        let expectation = self.expectation(description: "test_productSegment_none_false")
        let event = ApplicationEvent(name: "Hello", model: .init(viewProduct: .init(product: .init(ids: ["website": "49"]))))
        let mapper: InAppConfigurationMapperProtocol = InAppConfigutationMapper(customerSegmentsAPI: .live, inAppsVersion: 5, targetingChecker: targetingChecker, networkFetcher: networkFetcher, sessionTemporaryStorage: sessionTemporaryStorage)

        mapper.mapConfigResponse(event, configStub.getProductSegment_None()) { result in
            config = result
            expectation.fulfill()
        }

        mapper.targetingChecker.checkedProductSegmentations = [.init(ids: .init(externalId: "1"), segment: .init(ids: .init(externalId: "3")))]

        let expected = InAppConfig(inAppsByEvent: [:])
        waitForExpectations(timeout: 3)
        XCTAssertEqual(expected, config)
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
}
