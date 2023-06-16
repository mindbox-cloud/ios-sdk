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
    
    var imageDownloader: ImageDownloader {
        container.imageDownloader
    }
    
    private var mapper: InAppConfigurationMapperProtocol!
    private let configStub = InAppConfigStub()
    private let targetingChecker: InAppTargetingCheckerProtocol = InAppTargetingChecker()
    private var shownInAppsIds: Set<String>!
    
    override func setUp() {
        super.setUp()
        mapper = InAppConfigutationMapper(geoService: container.geoService,
                                          segmentationService: container.segmentationSevice,
                                          customerSegmentsAPI: .live,
                                          inAppsVersion: 1,
                                          targetingChecker: targetingChecker,
                                          sessionTemporaryStorage: sessionTemporaryStorage,
                                          persistenceStorage: persistenceStorage,
                                          imageDownloader: imageDownloader,
                                          sdkVersionValidator: container.sdkVersionValidator)
        shownInAppsIds = Set(persistenceStorage.shownInAppsIds ?? [])
    }
    
    func test_config_valid_to_parse() throws {
        let response = try getConfig(name: "InappConfigResponseValid")
        
        let inapps: [InApp]? = [.init(id: "6f93e2ef-0615-4e63-9c80-24bcb9e83b83",
                                      sdkVersion: SdkVersion(min: 4, max: nil),
                                      targeting: .and(AndTargeting(nodes: [.true(TrueTargeting())])),
                                      form: InApp.InAppFormVariants(variants: [.init(imageUrl: "1",
                                                                                     redirectUrl: "2",
                                                                                     intentPayload: "3",
                                                                                     type: "simpleImage")]))]
        
        let abTestObject1 = ABTest.ABTestVariant.ABTestObject(
            type: .inapps,
            kind: .all,
            inapps: ["inapp1", "inapp2"]
        )
        
        // Создаем структуры ABTestVariant
        let abTestVariant1 = ABTest.ABTestVariant(
            id: "1", modulus: ABTest.ABTestVariant.Modulus(lower: 0, upper: 50),
            objects: [abTestObject1]
        )
        
        let abTestVariant2 = ABTest.ABTestVariant(
            id: "2", modulus: ABTest.ABTestVariant.Modulus(lower: 50, upper: 100),
            objects: [abTestObject1]
        )
        let abtests: [ABTest]? = [.init(id: "id123",
                                        sdkVersion: .init(min: 1, max: nil),
                                        salt: "salt123",
                                        variants: [abTestVariant1,
                                                   abTestVariant2]),
        ]
        
        let monitoring = Monitoring(logs: [.init(requestId: "request1",
                                                 deviceUUID: "device1",
                                                 from: "source1",
                                                 to: "destination1"),
                                           .init(requestId: "request2",
                                                 deviceUUID: "device2",
                                                 from: "source2",
                                                 to: "destination2")])
        
        let settings = Settings(operations: .init(viewProduct: .init(systemName: "product"),
                                                  viewCategory: .init(systemName: "category"),
                                                  setCart: .init(systemName: "cart")))
        
        XCTAssertEqual(response.inapps, inapps)
        XCTAssertEqual(response.abtests, abtests)
        XCTAssertEqual(response.monitoring, monitoring)
        XCTAssertEqual(response.settings, settings)
    }
    
    func test_config_settings_invalid_to_parse() throws {
        let response = try getConfig(name: "InappConfigResponseSettingsInvalid")
        let inapps: [InApp]? = [.init(id: "6f93e2ef-0615-4e63-9c80-24bcb9e83b83",
                                      sdkVersion: SdkVersion(min: 4, max: nil),
                                      targeting: .and(AndTargeting(nodes: [.true(TrueTargeting())])),
                                      form: InApp.InAppFormVariants(variants: [.init(imageUrl: "1",
                                                                                     redirectUrl: "2",
                                                                                     intentPayload: "3",
                                                                                     type: "simpleImage")]))]
        
        XCTAssertEqual(response.inapps, inapps)
        // No systemName in Settings JSON
        XCTAssertNil(response.settings)
    }
    
    func test_config_monitoring_invalid_to_parse() throws {
        let response = try getConfig(name: "InappConfigResponseMonitoringInvalid")
        let inapps: [InApp]? = [.init(id: "6f93e2ef-0615-4e63-9c80-24bcb9e83b83",
                                      sdkVersion: SdkVersion(min: 4, max: nil),
                                      targeting: .and(AndTargeting(nodes: [.true(TrueTargeting())])),
                                      form: InApp.InAppFormVariants(variants: [.init(imageUrl: "1",
                                                                                     redirectUrl: "2",
                                                                                     intentPayload: "3",
                                                                                     type: "simpleImage")]))]
        
        XCTAssertEqual(response.inapps, inapps)
        // No id in Monitoring JSON
        XCTAssertNil(response.monitoring)
    }
    
    func test_config_abtests_invalid_to_parse() throws {
        let response = try getConfig(name: "InappConfigResponseAbtestsInvalid")
        let inapps: [InApp]? = [.init(id: "6f93e2ef-0615-4e63-9c80-24bcb9e83b83",
                                      sdkVersion: SdkVersion(min: 4, max: nil),
                                      targeting: .and(AndTargeting(nodes: [.true(TrueTargeting())])),
                                      form: InApp.InAppFormVariants(variants: [.init(imageUrl: "1",
                                                                                     redirectUrl: "2",
                                                                                     intentPayload: "3",
                                                                                     type: "simpleImage")]))]
        
        XCTAssertEqual(response.inapps, inapps)
        // No id in Abtest JSON
        XCTAssertNil(response.abtests)
    }
}

private extension InAppConfigResponseTests {
    private func getConfig(name: String) throws -> ConfigResponse {
        let bundle = Bundle(for: InAppConfigResponseTests.self)
        let fileURL = bundle.url(forResource: name, withExtension: "json")!
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(ConfigResponse.self, from: data)
    }
}

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
