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
//    var imageDownloader: ImageDownloader {
//        container.imageDownloader
//    }
//
//    private var mapper: InAppConfigutationMapper!
//    private let configStub = InAppConfigStub()
//    private let targetingChecker: InAppTargetingCheckerProtocol = InAppTargetingChecker()
//    private var shownInAppsIds: Set<String>!
//
//    override func setUp() {
//        super.setUp()
//        mapper = InAppConfigutationMapper(customerSegmentsAPI: .live,
//                                          inAppsVersion: 1,
//                                          targetingChecker: targetingChecker,
//                                          networkFetcher: networkFetcher,
//                                          sessionTemporaryStorage: sessionTemporaryStorage,
//                                          persistenceStorage: persistenceStorage,
//                                          imageDownloader: imageDownloader)
//        shownInAppsIds = Set(persistenceStorage.shownInAppsIds ?? [])
//    }
//
//    func test_2InApps_oneFitsInAppsSdkVersion_andOneDoesnt() throws {
//        let response = try getConfigWithTwoInapps()
//        let responseInapps = mapper.filterByInappVersion(response.inapps, shownInAppsIds: shownInAppsIds)
//        mapper.filterByInappsEvents(inapps: responseInapps)
//        let inapp = mapper.filteredInAppsByEvent[.start]?.first
//
//        let expected = InAppTransitionData(inAppId: "00000000-0000-0000-0000-000000000001",
//                                           imageUrl: "https://s3-symbol-logo.tradingview.com/true-corporation-public-company-limited--600.png",
//                                           redirectUrl: "", intentPayload: "")
//
//        XCTAssertEqual(expected, inapp)
//    }
//
//    func test_2InApps_bothFitInAppsSdkVersion() throws {
//        let response = try getConfigWithTwoInapps()
//        mapper.setInAppsVersion(3)
//
//        let responseInapps = mapper.filterByInappVersion(response.inapps, shownInAppsIds: shownInAppsIds)
//        mapper.filterByInappsEvents(inapps: responseInapps)
//        let inapp = mapper.filteredInAppsByEvent[.start]?.first
//
//        let expected = InAppTransitionData(inAppId: "00000000-0000-0000-0000-000000000001",
//                                           imageUrl: "https://s3-symbol-logo.tradingview.com/true-corporation-public-company-limited--600.png",
//                                           redirectUrl: "", intentPayload: "")
//
//        XCTAssertEqual(expected, inapp)
//    }
//
//    func test_2InApps_bothDontFitInAppsSdkVersion() throws {
//        let response = try getConfigWithTwoInapps()
//        mapper.setInAppsVersion(0)
//        let responseInapps = mapper.filterByInappVersion(response.inapps, shownInAppsIds: shownInAppsIds)
//        mapper.filterByInappsEvents(inapps: responseInapps)
//        let inapp = mapper.filteredInAppsByEvent[.start]?.first
//
//        let expected: InAppTransitionData? = nil
//        XCTAssertEqual(expected, inapp)
//    }
//
//    func test_operation_happyFlow() throws {
//        let response = try getConfigWithOperations()
//        let event = ApplicationEvent(name: "TESTPushOK", model: nil)
//        mapper.setInAppsVersion(4)
//        mapper.targetingChecker.event = event
//
//        let responseInapps = mapper.filterByInappVersion(response.inapps, shownInAppsIds: shownInAppsIds)
//        mapper.filterByInappsEvents(inapps: responseInapps)
//        let inapp = mapper.filteredInAppsByEvent[.applicationEvent(event)]?.first
//
//        let expected = InAppTransitionData(inAppId: "00000000-0000-0000-0000-000000000001",
//                                           imageUrl: "https://s3-symbol-logo.tradingview.com/true-corporation-public-company-limited--600.png",
//                                           redirectUrl: "", intentPayload: "")
//
//        XCTAssertEqual(expected, inapp)
//    }
//
//    func test_operation_empty_operatonName() throws {
//        let response = try getConfigWithOperations()
//        let event = ApplicationEvent(name: "TESTPushOK", model: nil)
//        mapper.setInAppsVersion(4)
//
//        let responseInapps = mapper.filterByInappVersion(response.inapps, shownInAppsIds: shownInAppsIds)
//        mapper.filterByInappsEvents(inapps: responseInapps)
//        let inapp = mapper.filteredInAppsByEvent[.applicationEvent(event)]?.first
//
//        let expected: InAppTransitionData? = nil
//
//        XCTAssertEqual(expected, inapp)
//    }
//
//    func test_operation_wrong_operatonName() throws {
//        let response = try getConfigWithOperations()
//        mapper.setInAppsVersion(4)
//        let event = ApplicationEvent(name: "WrongOperationName", model: nil)
//        mapper.targetingChecker.event = event
//
//        let responseInapps = mapper.filterByInappVersion(response.inapps, shownInAppsIds: shownInAppsIds)
//        mapper.filterByInappsEvents(inapps: responseInapps)
//        let inapp = mapper.filteredInAppsByEvent[.applicationEvent(event)]?.first
//
//        let expected: InAppTransitionData? = nil
//
//        XCTAssertEqual(expected, inapp)
//    }
//
//    func test_categoryID_emptyModel() {
//        mapper.setInAppsVersion(5)
//        let event = ApplicationEvent(name: "Hello", model: nil)
//        mapper.targetingChecker.event = event
//
//        let responseInapps = mapper.filterByInappVersion([], shownInAppsIds: shownInAppsIds)
//        mapper.filterByInappsEvents(inapps: responseInapps)
//        let inapp = mapper.filteredInAppsByEvent[.applicationEvent(event)]?.first
//
//        let expected: InAppTransitionData? = nil
//        XCTAssertEqual(expected, inapp)
//    }
//
//    func test_categoryID_substring_true() {
//        let response = configStub.getCategoryID_Substring()
//        mapper.setInAppsVersion(5)
//        let event = ApplicationEvent(name: "Hello",
//                                     model: .init(viewProductCategory: .init(productCategory: .init(ids: [
//                                        "System1C": "Boots".uppercased(),
//                                        "TestSite": "81".uppercased()
//                                     ]))))
//        mapper.targetingChecker.event = event
//
//        let responseInapps = mapper.filterByInappVersion(response.inapps, shownInAppsIds: shownInAppsIds)
//        mapper.filterByInappsEvents(inapps: responseInapps)
//        let inapp = mapper.filteredInAppsByEvent[.applicationEvent(event)]?.first
//
//        let expected = InAppTransitionData(inAppId: "0",
//                                           imageUrl: "1",
//                                           redirectUrl: "2", intentPayload: "3")
//
//        XCTAssertEqual(expected, inapp)
//    }
//
//    func test_categoryID_substring_false() {
//        let event = ApplicationEvent(name: "Hello",
//                                     model: .init(viewProductCategory: .init(productCategory: .init(ids: [
//                                        "System1C": "Bovts".uppercased(),
//                                        "TestSite": "81".uppercased()
//                                     ]))))
//        let response = configStub.getCategoryID_Substring()
//        mapper.setInAppsVersion(5)
//        mapper.targetingChecker.event = event
//
//        let responseInapps = mapper.filterByInappVersion(response.inapps, shownInAppsIds: shownInAppsIds)
//        mapper.filterByInappsEvents(inapps: responseInapps)
//
//        let config = mapper.filteredInAppsByEvent[.applicationEvent(event)]?.first
//        let expected: InAppTransitionData? = nil
//
//        XCTAssertEqual(expected, config)
//    }
//
//    func test_categoryID_notSubstring_true() {
//        let event = ApplicationEvent(name: "Hello",
//                                     model: .init(viewProductCategory: .init(productCategory: .init(ids: [
//                                        "System1C": "Boots".uppercased(),
//                                        "TestSite": "Button".uppercased()
//                                     ]))))
//        let response = configStub.getCategoryID_notSubstring()
//        mapper.setInAppsVersion(5)
//        mapper.targetingChecker.event = event
//
//        let responseInapps = mapper.filterByInappVersion(response.inapps, shownInAppsIds: shownInAppsIds)
//        mapper.filterByInappsEvents(inapps: responseInapps)
//
//        let config: InAppTransitionData? = mapper.filteredInAppsByEvent[.applicationEvent(event)]?.first
//
//        let expected: InAppTransitionData? = InAppTransitionData(inAppId: "0",
//                                                                 imageUrl: "1",
//                                                                 redirectUrl: "2",
//                                                                 intentPayload: "3")
//
//        XCTAssertEqual(expected, config)
//    }
//
//    func test_categoryID_notSubstring_false() {
//        let event = ApplicationEvent(name: "Hello",
//                                     model: .init(viewProductCategory: .init(productCategory: .init(ids: [
//                                        "System1C": "Boots".uppercased(),
//                                        "TestSite": "Buttootn".uppercased()
//                                     ]))))
//        let response = configStub.getCategoryID_notSubstring()
//        mapper.setInAppsVersion(5)
//        mapper.targetingChecker.event = event
//
//        let responseInapps = mapper.filterByInappVersion(response.inapps, shownInAppsIds: shownInAppsIds)
//        mapper.filterByInappsEvents(inapps: responseInapps)
//
//        let config: InAppTransitionData? = mapper.filteredInAppsByEvent[.applicationEvent(event)]?.first
//
//        let expected: InAppTransitionData? = nil
//
//        XCTAssertEqual(expected, config)
//    }
//
//    func test_categoryID_startWith_true() {
//        let event = ApplicationEvent(name: "Hello",
//                                     model: .init(viewProductCategory: .init(productCategory: .init(ids: [
//                                        "System1C": "oots".uppercased(),
//                                        "TestSite": "Button".uppercased()
//                                     ]))))
//        let response = configStub.getCategoryID_startWith()
//        mapper.setInAppsVersion(5)
//        mapper.targetingChecker.event = event
//
//        let responseInapps = mapper.filterByInappVersion(response.inapps, shownInAppsIds: shownInAppsIds)
//        mapper.filterByInappsEvents(inapps: responseInapps)
//
//        let config: InAppTransitionData? = mapper.filteredInAppsByEvent[.applicationEvent(event)]?.first
//
//        let expected: InAppTransitionData? = InAppTransitionData(inAppId: "0",
//                                                                 imageUrl: "1",
//                                                                 redirectUrl: "2",
//                                                                 intentPayload: "3")
//
//        XCTAssertEqual(expected, config)
//    }
//
//    func test_categoryID_startWith_false() {
//        let event = ApplicationEvent(name: "Hello",
//                                     model: .init(viewProductCategory: .init(productCategory: .init(ids: [
//                                        "System1C": "Boots".uppercased(),
//                                        "TestSite": "Button".uppercased()
//                                     ]))))
//        let response = configStub.getCategoryID_startWith()
//        mapper.setInAppsVersion(5)
//        mapper.targetingChecker.event = event
//
//        let responseInapps = mapper.filterByInappVersion(response.inapps, shownInAppsIds: shownInAppsIds)
//        mapper.filterByInappsEvents(inapps: responseInapps)
//
//        let config: InAppTransitionData? = mapper.filteredInAppsByEvent[.applicationEvent(event)]?.first
//
//        let expected: InAppTransitionData? = nil
//
//        XCTAssertEqual(expected, config)
//    }
//
//    func test_categoryID_endWith_true() {
//        let event = ApplicationEvent(name: "Hello",
//                                     model: .init(viewProductCategory: .init(productCategory: .init(ids: [
//                                        "System1C": "Boots".uppercased(),
//                                        "TestSite": "Button".uppercased()
//                                     ]))))
//        let response = configStub.getCategoryID_endWith()
//        mapper.setInAppsVersion(5)
//        mapper.targetingChecker.event = event
//
//        let responseInapps = mapper.filterByInappVersion(response.inapps, shownInAppsIds: shownInAppsIds)
//        mapper.filterByInappsEvents(inapps: responseInapps)
//
//        let config: InAppTransitionData? = mapper.filteredInAppsByEvent[.applicationEvent(event)]?.first
//
//        let expected: InAppTransitionData? = InAppTransitionData(inAppId: "0",
//                                                                 imageUrl: "1",
//                                                                 redirectUrl: "2",
//                                                                 intentPayload: "3")
//
//        XCTAssertEqual(expected, config)
//    }
//
//    func test_categoryID_endWith_false() {
//        let event = ApplicationEvent(name: "Hello",
//                                     model: .init(viewProductCategory: .init(productCategory: .init(ids: [
//                                        "System1C": "Boats".uppercased(),
//                                        "TestSite": "Button".uppercased()
//                                     ]))))
//        let response = configStub.getCategoryID_endWith()
//        mapper.setInAppsVersion(5)
//        mapper.targetingChecker.event = event
//
//        let responseInapps = mapper.filterByInappVersion(response.inapps, shownInAppsIds: shownInAppsIds)
//        mapper.filterByInappsEvents(inapps: responseInapps)
//
//        let config: InAppTransitionData? = mapper.filteredInAppsByEvent[.applicationEvent(event)]?.first
//
//        let expected: InAppTransitionData? = nil
//
//        XCTAssertEqual(expected, config)
//    }
//
//    func test_categoryIDIn_any_true() {
//        let event = ApplicationEvent(name: "Hello", model: .init(viewProductCategory: .init(productCategory: .init(ids: ["System1C": "testik2"]))))
//        let response = configStub.getCategoryIDIn_Any()
//        mapper.setInAppsVersion(5)
//        mapper.targetingChecker.event = event
//
//        let responseInapps = mapper.filterByInappVersion(response.inapps, shownInAppsIds: shownInAppsIds)
//        mapper.filterByInappsEvents(inapps: responseInapps)
//
//        let config: InAppTransitionData? = mapper.filteredInAppsByEvent[.applicationEvent(event)]?.first
//
//        let expected: InAppTransitionData? = InAppTransitionData(inAppId: "0",
//                                                                 imageUrl: "1",
//                                                                 redirectUrl: "2",
//                                                                 intentPayload: "3")
//
//        XCTAssertEqual(expected, config)
//    }
//
//    func test_categoryIDIn_any_false() {
//        let event = ApplicationEvent(name: "Hello", model: .init(viewProductCategory: .init(productCategory: .init(ids: ["System1C": "potato"]))))
//        let response = configStub.getCategoryIDIn_Any()
//        mapper.setInAppsVersion(5)
//        mapper.targetingChecker.event = event
//
//        let responseInapps = mapper.filterByInappVersion(response.inapps, shownInAppsIds: shownInAppsIds)
//        mapper.filterByInappsEvents(inapps: responseInapps)
//
//        let config: InAppTransitionData? = mapper.filteredInAppsByEvent[.applicationEvent(event)]?.first
//
//        let expected: InAppTransitionData? = nil
//
//        XCTAssertEqual(expected, config)
//    }
//
//    func test_categoryIDIn_none_true() {
//        let event = ApplicationEvent(name: "Hello", model: .init(viewProductCategory: .init(productCategory: .init(ids: ["System1C": "potato"]))))
//        let response = configStub.getCategoryIDIn_None()
//        mapper.setInAppsVersion(5)
//        mapper.targetingChecker.event = event
//
//        let responseInapps = mapper.filterByInappVersion(response.inapps, shownInAppsIds: shownInAppsIds)
//        mapper.filterByInappsEvents(inapps: responseInapps)
//
//        let config: InAppTransitionData? = mapper.filteredInAppsByEvent[.applicationEvent(event)]?.first
//
//        let expected: InAppTransitionData? = InAppTransitionData(inAppId: "0",
//                                                                 imageUrl: "1",
//                                                                 redirectUrl: "2",
//                                                                 intentPayload: "3")
//
//        XCTAssertEqual(expected, config)
//    }
//
//    func test_categoryIDIn_none_false() {
//        let event = ApplicationEvent(name: "Hello", model: .init(viewProductCategory: .init(productCategory: .init(ids: ["System1C": "testik2"]))))
//        let response = configStub.getCategoryIDIn_None()
//        mapper.setInAppsVersion(5)
//        mapper.targetingChecker.event = event
//
//        let responseInapps = mapper.filterByInappVersion(response.inapps, shownInAppsIds: shownInAppsIds)
//        mapper.filterByInappsEvents(inapps: responseInapps)
//
//        let config: InAppTransitionData? = mapper.filteredInAppsByEvent[.applicationEvent(event)]?.first
//
//        let expected: InAppTransitionData? = nil
//
//        XCTAssertEqual(expected, config)
//    }
//
//    func test_productID_emptyModel() {
//        let event = ApplicationEvent(name: "Hello", model: nil)
//        let response = configStub.getProductID_Substring()
//        mapper.setInAppsVersion(5)
//        mapper.targetingChecker.event = event
//
//        let responseInapps = mapper.filterByInappVersion(response.inapps, shownInAppsIds: shownInAppsIds)
//        mapper.filterByInappsEvents(inapps: responseInapps)
//
//        let config: InAppTransitionData? = mapper.filteredInAppsByEvent[.applicationEvent(event)]?.first
//
//        let expected: InAppTransitionData? = nil
//
//        XCTAssertEqual(expected, config)
//    }
//
//    func test_productID_substring_true() {
//        let event = ApplicationEvent(name: "Hello", model: .init(viewProduct: .init(product: .init(ids:
//                                                                                                    ["website": "Boots".uppercased(),
//                                                                                                     "system1c": "81".uppercased()
//                                                                                                    ]))))
//        let response = configStub.getProductID_Substring()
//        mapper.setInAppsVersion(5)
//        mapper.targetingChecker.event = event
//
//        let responseInapps = mapper.filterByInappVersion(response.inapps, shownInAppsIds: shownInAppsIds)
//        mapper.filterByInappsEvents(inapps: responseInapps)
//
//        let config: InAppTransitionData? = mapper.filteredInAppsByEvent[.applicationEvent(event)]?.first
//
//        let expected: InAppTransitionData? = InAppTransitionData(inAppId: "0",
//                                                                 imageUrl: "1",
//                                                                 redirectUrl: "2",
//                                                                 intentPayload: "3")
//
//        XCTAssertEqual(expected, config)
//    }
//
//    func test_productID_substring_false() {
//        let event = ApplicationEvent(name: "Hello", model: .init(viewProduct: .init(product: .init(ids:
//                                                                                                    ["website": "Bovts".uppercased(),
//                                                                                                     "system1c": "81".uppercased()
//                                                                                                    ]))))
//        let response = configStub.getProductID_Substring()
//        mapper.setInAppsVersion(5)
//        mapper.targetingChecker.event = event
//
//        let responseInapps = mapper.filterByInappVersion(response.inapps, shownInAppsIds: shownInAppsIds)
//        mapper.filterByInappsEvents(inapps: responseInapps)
//
//        let config: InAppTransitionData? = mapper.filteredInAppsByEvent[.applicationEvent(event)]?.first
//
//        let expected: InAppTransitionData? = nil
//
//        XCTAssertEqual(expected, config)
//    }
//
//    func test_productID_notSubstring_true() {
//        let event = ApplicationEvent(name: "Hello", model: .init(viewProduct: .init(product: .init(ids:
//                                                                                                    ["website": "Boots".uppercased(),
//                                                                                                     "system1c": "81".uppercased()
//                                                                                                    ]))))
//        let response = configStub.getProductID_notSubstring()
//        mapper.setInAppsVersion(5)
//        mapper.targetingChecker.event = event
//
//        let responseInapps = mapper.filterByInappVersion(response.inapps, shownInAppsIds: shownInAppsIds)
//        mapper.filterByInappsEvents(inapps: responseInapps)
//
//        let config: InAppTransitionData? = mapper.filteredInAppsByEvent[.applicationEvent(event)]?.first
//
//        let expected: InAppTransitionData? = InAppTransitionData(inAppId: "0",
//                                                                 imageUrl: "1",
//                                                                 redirectUrl: "2",
//                                                                 intentPayload: "3")
//
//        XCTAssertEqual(expected, config)
//    }
//
//    func test_productID_notSubstring_false() {
//        let event = ApplicationEvent(name: "Hello", model: .init(viewProduct: .init(product: .init(ids:
//                                                                                                    ["website": "Boots".uppercased(),
//                                                                                                     "system1c": "Buttootn".uppercased()
//                                                                                                    ]))))
//        let response = configStub.getProductID_notSubstring()
//        mapper.setInAppsVersion(5)
//        mapper.targetingChecker.event = event
//
//        let responseInapps = mapper.filterByInappVersion(response.inapps, shownInAppsIds: shownInAppsIds)
//        mapper.filterByInappsEvents(inapps: responseInapps)
//
//        let config: InAppTransitionData? = mapper.filteredInAppsByEvent[.applicationEvent(event)]?.first
//
//        let expected: InAppTransitionData? = nil
//
//        XCTAssertEqual(expected, config)
//    }
//
//    func test_productID_startWith_true() {
//        let event = ApplicationEvent(name: "Hello", model: .init(viewProduct: .init(product: .init(ids:
//                                                                                                    ["website": "oots".uppercased(),
//                                                                                                     "system1c": "Button".uppercased()
//                                                                                                    ]))))
//        let response = configStub.getProductID_startsWith()
//        mapper.setInAppsVersion(5)
//        mapper.targetingChecker.event = event
//
//        let responseInapps = mapper.filterByInappVersion(response.inapps, shownInAppsIds: shownInAppsIds)
//        mapper.filterByInappsEvents(inapps: responseInapps)
//
//        let config: InAppTransitionData? = mapper.filteredInAppsByEvent[.applicationEvent(event)]?.first
//
//        let expected: InAppTransitionData? = InAppTransitionData(inAppId: "0",
//                                                                 imageUrl: "1",
//                                                                 redirectUrl: "2",
//                                                                 intentPayload: "3")
//
//        XCTAssertEqual(expected, config)
//    }
//
//    func test_productID_startWith_false() {
//        let event = ApplicationEvent(name: "Hello", model: .init(viewProduct: .init(product: .init(ids:
//                                                                                                    ["website": "Boots".uppercased(),
//                                                                                                     "system1c": "Button".uppercased()
//                                                                                                    ]))))
//        let response = configStub.getProductID_startsWith()
//        mapper.setInAppsVersion(5)
//        mapper.targetingChecker.event = event
//
//        let responseInapps = mapper.filterByInappVersion(response.inapps, shownInAppsIds: shownInAppsIds)
//        mapper.filterByInappsEvents(inapps: responseInapps)
//
//        let config: InAppTransitionData? = mapper.filteredInAppsByEvent[.applicationEvent(event)]?.first
//
//        let expected: InAppTransitionData? = nil
//
//        XCTAssertEqual(expected, config)
//    }
//
//    func test_productID_endWith_true() {
//        let event = ApplicationEvent(name: "Hello", model: .init(viewProduct: .init(product: .init(ids:
//                                                                                                    ["website": "Boots".uppercased(),
//                                                                                                     "system1c": "Button".uppercased()
//                                                                                                    ]))))
//        let response = configStub.getProductID_endsWith()
//        mapper.setInAppsVersion(5)
//        mapper.targetingChecker.event = event
//
//        let responseInapps = mapper.filterByInappVersion(response.inapps, shownInAppsIds: shownInAppsIds)
//        mapper.filterByInappsEvents(inapps: responseInapps)
//
//        let config: InAppTransitionData? = mapper.filteredInAppsByEvent[.applicationEvent(event)]?.first
//
//        let expected: InAppTransitionData? = InAppTransitionData(inAppId: "0",
//                                                                 imageUrl: "1",
//                                                                 redirectUrl: "2",
//                                                                 intentPayload: "3")
//
//        XCTAssertEqual(expected, config)
//    }
//
//    func test_productID_endWith_false() {
//        let event = ApplicationEvent(name: "Hello", model: .init(viewProduct: .init(product: .init(ids:
//                                                                                                    ["website": "Boats".uppercased(),
//                                                                                                     "system1c": "Button".uppercased()
//                                                                                                    ]))))
//        let response = configStub.getProductID_endsWith()
//        mapper.setInAppsVersion(5)
//        mapper.targetingChecker.event = event
//
//        let responseInapps = mapper.filterByInappVersion(response.inapps, shownInAppsIds: shownInAppsIds)
//        mapper.filterByInappsEvents(inapps: responseInapps)
//
//        let config: InAppTransitionData? = mapper.filteredInAppsByEvent[.applicationEvent(event)]?.first
//
//        let expected: InAppTransitionData? = nil
//
//        XCTAssertEqual(expected, config)
//    }
//
//    func test_productSegment_positive_true() throws {
//        let event = ApplicationEvent(name: "Hello", model: .init(viewProduct: .init(product: .init(ids: ["website": "49"]))))
//        let response = configStub.getProductSegment_Any()
//        mapper.setInAppsVersion(5)
//        mapper.targetingChecker.event = event
//        mapper.targetingChecker.checkedProductSegmentations = [.init(ids: .init(externalId: "1"),
//                                                                     segment: .init(ids: .init(externalId: "3")))]
//
//        let responseInapps = mapper.filterByInappVersion(response.inapps, shownInAppsIds: shownInAppsIds)
//        mapper.filterByInappsEvents(inapps: responseInapps)
//
//        let config: InAppTransitionData? = mapper.filteredInAppsByEvent[.applicationEvent(event)]?.first
//
//        let expected: InAppTransitionData? = InAppTransitionData(inAppId: "0",
//                                                                 imageUrl: "1",
//                                                                 redirectUrl: "2",
//                                                                 intentPayload: "3")
//
//        XCTAssertEqual(expected, config)
//    }
//
//    func test_productSegment_positive_false() throws {
//        let event = ApplicationEvent(name: "Hello", model: .init(viewProduct: .init(product: .init(ids: ["website": "49"]))))
//        let response = configStub.getProductSegment_Any()
//        mapper.setInAppsVersion(5)
//        mapper.targetingChecker.event = event
//        mapper.targetingChecker.checkedProductSegmentations = []
//
//        let responseInapps = mapper.filterByInappVersion(response.inapps, shownInAppsIds: shownInAppsIds)
//        mapper.filterByInappsEvents(inapps: responseInapps)
//
//        let config: InAppTransitionData? = mapper.filteredInAppsByEvent[.applicationEvent(event)]?.first
//
//        let expected: InAppTransitionData? = nil
//
//        XCTAssertEqual(expected, config)
//    }
//
//    func test_productSegment_negative_true() throws {
//        let event = ApplicationEvent(name: "Hello", model: .init(viewProduct: .init(product: .init(ids: ["website": "49"]))))
//        let response = configStub.getProductSegment_None()
//        mapper.setInAppsVersion(5)
//        mapper.targetingChecker.event = event
//        mapper.targetingChecker.checkedProductSegmentations = [.init(ids: .init(externalId: "1"), segment: .init(ids: .init(externalId: "4")))]
//
//        let responseInapps = mapper.filterByInappVersion(response.inapps, shownInAppsIds: shownInAppsIds)
//        mapper.filterByInappsEvents(inapps: responseInapps)
//
//        let config: InAppTransitionData? = mapper.filteredInAppsByEvent[.applicationEvent(event)]?.first
//
//        let expected: InAppTransitionData? = InAppTransitionData(inAppId: "0",
//                                                                 imageUrl: "1",
//                                                                 redirectUrl: "2",
//                                                                 intentPayload: "3")
//
//        XCTAssertEqual(expected, config)
//    }
//
//    func test_productSegment_negative_false() throws {
//        let event = ApplicationEvent(name: "Hello", model: .init(viewProduct: .init(product: .init(ids: ["website": "49"]))))
//        let response = configStub.getProductSegment_None()
//        mapper.setInAppsVersion(5)
//        mapper.targetingChecker.event = event
//        mapper.targetingChecker.checkedProductSegmentations = [.init(ids: .init(externalId: "1"), segment: .init(ids: .init(externalId: "3")))]
//
//        let responseInapps = mapper.filterByInappVersion(response.inapps, shownInAppsIds: shownInAppsIds)
//        mapper.filterByInappsEvents(inapps: responseInapps)
//
//        let config: InAppTransitionData? = mapper.filteredInAppsByEvent[.applicationEvent(event)]?.first
//
//        let expected: InAppTransitionData? = nil
//
//        XCTAssertEqual(expected, config)
//    }
//}
//
//private extension InAppConfigResponseTests {
//    private func getConfigWithTwoInapps() throws -> InAppConfigResponse {
//        let bundle = Bundle(for: InAppConfigResponseTests.self)
//        let fileURL = bundle.url(forResource: "InAppConfiguration", withExtension: "json")!
//        let data = try Data(contentsOf: fileURL)
//        return try JSONDecoder().decode(InAppConfigResponse.self, from: data)
//    }
//
//    private func getConfigWithInvalidInapps() throws -> InAppConfigResponse {
//        let bundle = Bundle(for: InAppConfigResponseTests.self)
//        let fileURL = bundle.url(forResource: "InAppConfigurationInvalid", withExtension: "json")!
//        let data = try Data(contentsOf: fileURL)
//        return try JSONDecoder().decode(InAppConfigResponse.self, from: data)
//    }
//
//    private func getConfigWithOperations() throws -> InAppConfigResponse {
//        let bundle = Bundle(for: InAppConfigResponseTests.self)
//        let fileURL = bundle.url(forResource: "InAppConfigurationWithOperations", withExtension: "json")!
//        let data = try Data(contentsOf: fileURL)
//        return try JSONDecoder().decode(InAppConfigResponse.self, from: data)
//    }
//}
