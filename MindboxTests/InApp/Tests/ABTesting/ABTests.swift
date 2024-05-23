////
////  ABTests.swift
////  MindboxTests
////
////  Created by vailence on 19.06.2023.
////  Copyright © 2023 Mindbox. All rights reserved.
////
//
//import Foundation
//import XCTest
//@testable import Mindbox
//
//class ABTests: XCTestCase {
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
//    var sdkVersionValidator: SDKVersionValidator!
//
//    private var mapper: InAppConfigutationMapper!
//    private let configStub = InAppConfigStub()
//    private let targetingChecker: InAppTargetingCheckerProtocol = InAppTargetingChecker()
//    private var shownInAppsIds: Set<String>!
//
//    override func setUp() {
//        super.setUp()
//        sdkVersionValidator = SDKVersionValidator(sdkVersionNumeric: 6)
//        mapper = InAppConfigutationMapper(inappFilterService: container.inappFilterService,
//                                          geoService: container.geoService,
//                                          segmentationService: container.segmentationSevice,
//                                          customerSegmentsAPI: .live,
//                                          targetingChecker: targetingChecker,
//                                          sessionTemporaryStorage: sessionTemporaryStorage,
//                                          persistenceStorage: persistenceStorage,
//                                          sdkVersionValidator: sdkVersionValidator,
//                                          imageDownloadService: container.imageDownloadService,
//                                          urlExtractorService: container.urlExtractorService,
//                                          abTestDeviceMixer: container.abTestDeviceMixer)
//        shownInAppsIds = Set(persistenceStorage.shownInAppsIds ?? [])
//    }
//
//    func test_no_abtests() throws {
//        let response = try getConfig(name: "ConfigWithAB_1")
//        let abTests: [ABTest]? = nil
//        let inapps = mapper.filterInappsByABTests(abTests, responseInapps: response.inapps?.elements)
//        XCTAssertEqual(inapps.count, 3)
//        let expectedIds = [
//            "655f5ffa-de86-4224-a0bf-229fe208ed0d",
//            "6f93e2ef-0615-4e63-9c80-24bcb9e83b83",
//            "b33ca779-3c99-481f-ad46-91282b0caf04"
//        ]
//
//        runInAppTestForUUID("BBBC2BA1-0B5B-4C9E-AB0E-95C54775B4F1",
//                            abTests: abTests,
//                            responseInapps: response.inapps?.elements,
//                            expectedCount: 3, expectedIds: expectedIds)
//    }
//
//    func test_compare_inapps_with_cg() throws {
//        let response = try getConfig(name: "ConfigWithAB_1")
//        let abTests: [ABTest]? = [
//            ABTest(
//                id: "0ec6be6b-421f-464b-9ee4-348a5292a5fd",
//                sdkVersion: SdkVersion(min: 6, max: nil),
//                salt: "BBBC2BA1-0B5B-4C9E-AB0E-95C54775B4F1",
//                variants: [
//                    ABTest.ABTestVariant(
//                        id: "155f5ffa-de86-4224-a0bf-229fe208ed0d",
//                        modulus: ABTest.ABTestVariant.Modulus(lower: 0, upper: 50),
//                        objects: [
//                            ABTest.ABTestVariant.ABTestObject(
//                                type: .inapps,
//                                kind: .concrete,
//                                inapps: []
//                            )
//                        ]
//                    ),
//                    ABTest.ABTestVariant(
//                        id: "211f1c16-fa72-4456-bf87-af448eb84a32",
//                        modulus: ABTest.ABTestVariant.Modulus(lower: 50, upper: 100),
//                        objects: [
//                            ABTest.ABTestVariant.ABTestObject(
//                                type: .inapps,
//                                kind: .all,
//                                inapps: nil
//                            )
//                        ]
//                    )
//                ]
//            )
//        ]
//
//        runInAppTestForUUID("4078E211-7C3F-C607-D35C-DC6B591EF355", abTests: abTests, responseInapps: response.inapps?.elements, expectedCount: 0, expectedIds: []) // 25
//
//        let expectedIds = [
//            "655f5ffa-de86-4224-a0bf-229fe208ed0d",
//            "6f93e2ef-0615-4e63-9c80-24bcb9e83b83",
//            "b33ca779-3c99-481f-ad46-91282b0caf04"
//        ]
//
//        runInAppTestForUUID("4D27710A-3F3A-FF6E-7764-375B1E06E05D", abTests: abTests, responseInapps: response.inapps?.elements, expectedCount: 3, expectedIds: expectedIds) // 75
//    }
//
//    func test_compare_cg_and_concrete_inapps() throws {
//        let response = try getConfig(name: "ConfigWithAB_2")
//        let abTests: [ABTest]? = [
//            ABTest(
//                id: "0ec6be6b-421f-464b-9ee4-348a5292a5fd",
//                sdkVersion: SdkVersion(min: 6, max: nil),
//                salt: "BBBC2BA1-0B5B-4C9E-AB0E-95C54775B4F1",
//                variants: [
//                    ABTest.ABTestVariant(
//                        id: "155f5ffa-de86-4224-a0bf-229fe208ed0d",
//                        modulus: ABTest.ABTestVariant.Modulus(lower: 0, upper: 50),
//                        objects: [
//                            ABTest.ABTestVariant.ABTestObject(
//                                type: .inapps,
//                                kind: .concrete,
//                                inapps: []
//                            )
//                        ]
//                    ),
//                    ABTest.ABTestVariant(
//                        id: "211f1c16-fa72-4456-bf87-af448eb84a32",
//                        modulus: ABTest.ABTestVariant.Modulus(lower: 50, upper: 100),
//                        objects: [
//                            ABTest.ABTestVariant.ABTestObject(
//                                type: .inapps,
//                                kind: .concrete,
//                                inapps: [
//                                    "655f5ffa-de86-4224-a0bf-229fe208ed0d",
//                                    "b33ca779-3c99-481f-ad46-91282b0caf04"
//                                ]
//                            )
//                        ]
//                    )
//                ]
//            )
//        ]
//
//        // Test case for UUID "4078E211-7C3F-C607-D35C-DC6B591EF355" with expected inapp count of 2
//        let expectedIds1 = [
//            "6f93e2ef-0615-4e63-9c80-24bcb9e83b83",
//            "d1b312bd-aa5c-414c-a0d8-8126376a2a9b"
//        ]
//        runInAppTestForUUID("4078E211-7C3F-C607-D35C-DC6B591EF355", abTests: abTests, responseInapps: response.inapps?.elements, expectedCount: 2, expectedIds: expectedIds1)
//
//        // Test case for UUID "4D27710A-3F3A-FF6E-7764-375B1E06E05D" with expected inapp count of 4
//        let expectedIds2 = [
//            "655f5ffa-de86-4224-a0bf-229fe208ed0d",
//            "6f93e2ef-0615-4e63-9c80-24bcb9e83b83",
//            "b33ca779-3c99-481f-ad46-91282b0caf04",
//            "d1b312bd-aa5c-414c-a0d8-8126376a2a9b"
//        ]
//        runInAppTestForUUID("4D27710A-3F3A-FF6E-7764-375B1E06E05D", abTests: abTests, responseInapps: response.inapps?.elements, expectedCount: 4, expectedIds: expectedIds2)
//    }
//
//    func test_compare_cg_and_concrete_inapps_and_all_inapps() throws {
//        let response = try getConfig(name: "ConfigWithAB_1")
//        let abTests: [ABTest]? = [
//            ABTest(
//                id: "0ec6be6b-421f-464b-9ee4-348a5292a5fd",
//                sdkVersion: SdkVersion(min: 6, max: nil),
//                salt: "BBBC2BA1-0B5B-4C9E-AB0E-95C54775B4F1",
//                variants: [
//                    ABTest.ABTestVariant(
//                        id: "155f5ffa-de86-4224-a0bf-229fe208ed0d",
//                        modulus: ABTest.ABTestVariant.Modulus(lower: 0, upper: 30),
//                        objects: [
//                            ABTest.ABTestVariant.ABTestObject(
//                                type: .inapps,
//                                kind: .concrete,
//                                inapps: []
//                            )
//                        ]
//                    ),
//                    ABTest.ABTestVariant(
//                        id: "211f1c16-fa72-4456-bf87-af448eb84a32",
//                        modulus: ABTest.ABTestVariant.Modulus(lower: 30, upper: 65),
//                        objects: [
//                            ABTest.ABTestVariant.ABTestObject(
//                                type: .inapps,
//                                kind: .concrete,
//                                inapps: [
//                                    "655f5ffa-de86-4224-a0bf-229fe208ed0d",
//                                    "b33ca779-3c99-481f-ad46-91282b0caf04"
//                                ]
//                            )
//                        ]
//                    ),
//                    ABTest.ABTestVariant(
//                        id: "36e69720-8e73-447c-b172-7b17e2d73525",
//                        modulus: ABTest.ABTestVariant.Modulus(lower: 65, upper: 100),
//                        objects: [
//                            ABTest.ABTestVariant.ABTestObject(
//                                type: .inapps,
//                                kind: .all,
//                                inapps: nil
//                            )
//                        ]
//                    )
//                ]
//            )
//        ]
//
//        // Test case for UUID "4078E211-7C3F-C607-D35C-DC6B591EF355" with expected inapp count of 0
//        runInAppTestForUUID("4078E211-7C3F-C607-D35C-DC6B591EF355", abTests: abTests, responseInapps: response.inapps?.elements, expectedCount: 0, expectedIds: [])
//
//        // Test case for UUID "0809B0F8-8F21-18E8-2EF8-EC2D98938A84" with expected inapp count of 2
//        let expectedIds1 = [
//            "655f5ffa-de86-4224-a0bf-229fe208ed0d",
//            "b33ca779-3c99-481f-ad46-91282b0caf04"
//        ]
//        runInAppTestForUUID("0809B0F8-8F21-18E8-2EF8-EC2D98938A84", abTests: abTests, responseInapps: response.inapps?.elements, expectedCount: 2, expectedIds: expectedIds1)
//
//        // Test case for UUID "4D27710A-3F3A-FF6E-7764-375B1E06E05D" with expected inapp count of 3
//        let expectedIds2 = [
//            "655f5ffa-de86-4224-a0bf-229fe208ed0d",
//            "6f93e2ef-0615-4e63-9c80-24bcb9e83b83",
//            "b33ca779-3c99-481f-ad46-91282b0caf04"
//        ]
//        runInAppTestForUUID("4D27710A-3F3A-FF6E-7764-375B1E06E05D", abTests: abTests, responseInapps: response.inapps?.elements, expectedCount: 3, expectedIds: expectedIds2)
//    }
//
//    func test_compare_2branch_and_concrete_inapps_and_cg() throws {
//        let response = try getConfig(name: "ConfigWithAB_2")
//        let abTests: [ABTest]? = [
//            ABTest(
//                id: "0ec6be6b-421f-464b-9ee4-348a5292a5fd",
//                sdkVersion: SdkVersion(min: 6, max: nil),
//                salt: "BBBC2BA1-0B5B-4C9E-AB0E-95C54775B4F1",
//                variants: [
//                    ABTest.ABTestVariant(
//                        id: "155f5ffa-de86-4224-a0bf-229fe208ed0d",
//                        modulus: ABTest.ABTestVariant.Modulus(lower: 0, upper: 27),
//                        objects: [
//                            ABTest.ABTestVariant.ABTestObject(
//                                type: .inapps,
//                                kind: .concrete,
//                                inapps: []
//                            )
//                        ]
//                    ),
//                    ABTest.ABTestVariant(
//                        id: "211f1c16-fa72-4456-bf87-af448eb84a32",
//                        modulus: ABTest.ABTestVariant.Modulus(lower: 27, upper: 65),
//                        objects: [
//                            ABTest.ABTestVariant.ABTestObject(
//                                type: .inapps,
//                                kind: .concrete,
//                                inapps: [
//                                    "655f5ffa-de86-4224-a0bf-229fe208ed0d"
//                                ]
//                            )
//                        ]
//                    ),
//                    ABTest.ABTestVariant(
//                        id: "36e69720-8e73-447c-b172-7b17e2d73525",
//                        modulus: ABTest.ABTestVariant.Modulus(lower: 65, upper: 100),
//                        objects: [
//                            ABTest.ABTestVariant.ABTestObject(
//                                type: .inapps,
//                                kind: .concrete,
//                                inapps: [
//                                    "b33ca779-3c99-481f-ad46-91282b0caf04"
//                                ]
//                            )
//                        ]
//                    )
//                ]
//            )
//        ]
//
//        // Test case for UUID "4078E211-7C3F-C607-D35C-DC6B591EF355" with expected inapp count of 2
//        let expectedIds1 = [
//            "6f93e2ef-0615-4e63-9c80-24bcb9e83b83",
//            "d1b312bd-aa5c-414c-a0d8-8126376a2a9b"
//        ]
//        runInAppTestForUUID("4078E211-7C3F-C607-D35C-DC6B591EF355", abTests: abTests, responseInapps: response.inapps?.elements, expectedCount: expectedIds1.count, expectedIds: expectedIds1)
//
//        // Test case for UUID "0809B0F8-8F21-18E8-2EF8-EC2D98938A84" with expected inapp count of 3
//        let expectedIds2 = [
//            "6f93e2ef-0615-4e63-9c80-24bcb9e83b83",
//            "d1b312bd-aa5c-414c-a0d8-8126376a2a9b",
//            "655f5ffa-de86-4224-a0bf-229fe208ed0d"
//        ]
//        runInAppTestForUUID("0809B0F8-8F21-18E8-2EF8-EC2D98938A84", abTests: abTests, responseInapps: response.inapps?.elements, expectedCount: expectedIds2.count, expectedIds: expectedIds2)
//
//        // Test case for UUID "4D27710A-3F3A-FF6E-7764-375B1E06E05D" with expected inapp count of 3
//        let expectedIds3 = [
//            "6f93e2ef-0615-4e63-9c80-24bcb9e83b83",
//            "d1b312bd-aa5c-414c-a0d8-8126376a2a9b",
//            "b33ca779-3c99-481f-ad46-91282b0caf04"
//        ]
//        runInAppTestForUUID("4D27710A-3F3A-FF6E-7764-375B1E06E05D", abTests: abTests, responseInapps: response.inapps?.elements, expectedCount: expectedIds3.count, expectedIds: expectedIds3)
//    }
//
//    func test_compare_2branch_and_concrete_inapps() throws {
//        let response = try getConfig(name: "ConfigWithAB_1")
//        let abTests: [ABTest]? = [
//            ABTest(
//                id: "0ec6be6b-421f-464b-9ee4-348a5292a5fd",
//                sdkVersion: SdkVersion(min: 6, max: nil),
//                salt: "BBBC2BA1-0B5B-4C9E-AB0E-95C54775B4F1",
//                variants: [
//                    ABTest.ABTestVariant(
//                        id: "155f5ffa-de86-4224-a0bf-229fe208ed0d",
//                        modulus: ABTest.ABTestVariant.Modulus(lower: 0, upper: 99),
//                        objects: [
//                            ABTest.ABTestVariant.ABTestObject(
//                                type: .inapps,
//                                kind: .concrete,
//                                inapps: [
//                                    "655f5ffa-de86-4224-a0bf-229fe208ed0d",
//                                    "b33ca779-3c99-481f-ad46-91282b0caf04"
//                                ]
//                            )
//                        ]
//                    ),
//                    ABTest.ABTestVariant(
//                        id: "211f1c16-fa72-4456-bf87-af448eb84a32",
//                        modulus: ABTest.ABTestVariant.Modulus(lower: 99, upper: 100),
//                        objects: [
//                            ABTest.ABTestVariant.ABTestObject(
//                                type: .inapps,
//                                kind: .concrete,
//                                inapps: [
//                                    "6f93e2ef-0615-4e63-9c80-24bcb9e83b83"
//                                ]
//                            )
//                        ]
//                    )
//                ]
//            )
//        ]
//
//        // Test case for UUID "4078E211-7C3F-C607-D35C-DC6B591EF355" with expected inapp count of 2
//        let expectedIds1 = [
//            "655f5ffa-de86-4224-a0bf-229fe208ed0d",
//            "b33ca779-3c99-481f-ad46-91282b0caf04"
//        ]
//        runInAppTestForUUID("4078E211-7C3F-C607-D35C-DC6B591EF355", abTests: abTests, responseInapps: response.inapps?.elements, expectedCount: expectedIds1.count, expectedIds: expectedIds1)
//
//        // Test case for UUID "0809B0F8-8F21-18E8-2EF8-EC2D98938A84" with expected inapp count of 3
//        let expectedIds2 = [
//            "6f93e2ef-0615-4e63-9c80-24bcb9e83b83"
//        ]
//        runInAppTestForUUID("C9F84B44-01B9-A3C6-E85B-7FF816D3BA68", abTests: abTests, responseInapps: response.inapps?.elements, expectedCount: expectedIds2.count, expectedIds: expectedIds2)
//    }
//
//    func test_aab_show_inapps_in_cg_branch() throws {
//        let response = try getConfig(name: "ConfigWithAB_1")
//        let abTests: [ABTest]? = [
//            ABTest(
//                id: "0ec6be6b-421f-464b-9ee4-348a5292a5fd",
//                sdkVersion: SdkVersion(min: 6, max: nil),
//                salt: "BBBC2BA1-0B5B-4C9E-AB0E-95C54775B4F1",
//                variants: [
//                    ABTest.ABTestVariant(
//                        id: "155f5ffa-de86-4224-a0bf-229fe208ed0d",
//                        modulus: ABTest.ABTestVariant.Modulus(lower: 0, upper: 33),
//                        objects: [
//                            ABTest.ABTestVariant.ABTestObject(
//                                type: .inapps,
//                                kind: .concrete,
//                                inapps: []
//                            )
//                        ]
//                    ),
//                    ABTest.ABTestVariant(
//                        id: "211f1c16-fa72-4456-bf87-af448eb84a32",
//                        modulus: ABTest.ABTestVariant.Modulus(lower: 33, upper: 66),
//                        objects: [
//                            ABTest.ABTestVariant.ABTestObject(
//                                type: .inapps,
//                                kind: .concrete,
//                                inapps: []
//                            )
//                        ]
//                    ),
//                    ABTest.ABTestVariant(
//                        id: "36e69720-8e73-447c-b172-7b17e2d73525",
//                        modulus: ABTest.ABTestVariant.Modulus(lower: 66, upper: 100),
//                        objects: [
//                            ABTest.ABTestVariant.ABTestObject(
//                                type: .inapps,
//                                kind: .concrete,
//                                inapps: [
//                                    "655f5ffa-de86-4224-a0bf-229fe208ed0d",
//                                    "b33ca779-3c99-481f-ad46-91282b0caf04"
//                                ]
//                            )
//                        ]
//                    )
//                ]
//            )
//        ]
//
//        // Test case for UUID "4862ADF1-1392-9362-42A2-FF5A65629F50" with expected inapp count of 2
//        let expectedIds1 = [
//            "6f93e2ef-0615-4e63-9c80-24bcb9e83b83"
//        ]
//        runInAppTestForUUID("4862ADF1-1392-9362-42A2-FF5A65629F50", abTests: abTests, responseInapps: response.inapps?.elements, expectedCount: expectedIds1.count, expectedIds: expectedIds1) // 25
//
//        // Test case for UUID "0809B0F8-8F21-18E8-2EF8-EC2D98938A84" with expected inapp count of 3
//        runInAppTestForUUID("0809B0F8-8F21-18E8-2EF8-EC2D98938A84", abTests: abTests, responseInapps: response.inapps?.elements, expectedCount: expectedIds1.count, expectedIds: expectedIds1) // 45
//
//        let expectedIds2 = [
//            "6f93e2ef-0615-4e63-9c80-24bcb9e83b83",
//            "655f5ffa-de86-4224-a0bf-229fe208ed0d",
//            "b33ca779-3c99-481f-ad46-91282b0caf04"
//        ]
//        // Test case for UUID "4D27710A-3F3A-FF6E-7764-375B1E06E05D" with expected inapp count of 3
//        runInAppTestForUUID("4D27710A-3F3A-FF6E-7764-375B1E06E05D", abTests: abTests, responseInapps: response.inapps?.elements, expectedCount: expectedIds2.count, expectedIds: expectedIds2) // 75
//    }
//
//    func test_aab_not_show_inapps_in_cg_branch() throws {
//        let response = try getConfig(name: "ConfigWithAB_1")
//        let abTests: [ABTest]? = [
//            ABTest(
//                id: "c0e2682c-3d0f-4291-9308-9e48a16eb3c8",
//                sdkVersion: SdkVersion(min: 6, max: nil),
//                salt: "BBBC2BA1-0B5B-4C9E-AB0E-95C54775B4F1",
//                variants: [
//                    ABTest.ABTestVariant(
//                        id: "155f5ffa-de86-4224-a0bf-229fe208ed0d",
//                        modulus: ABTest.ABTestVariant.Modulus(lower: 0, upper: 33),
//                        objects: [
//                            ABTest.ABTestVariant.ABTestObject(
//                                type: .inapps,
//                                kind: .concrete,
//                                inapps: []
//                            )
//                        ]
//                    ),
//                    ABTest.ABTestVariant(
//                        id: "211f1c16-fa72-4456-bf87-af448eb84a32",
//                        modulus: ABTest.ABTestVariant.Modulus(lower: 33, upper: 66),
//                        objects: [
//                            ABTest.ABTestVariant.ABTestObject(
//                                type: .inapps,
//                                kind: .concrete,
//                                inapps: []
//                            )
//                        ]
//                    ),
//                    ABTest.ABTestVariant(
//                        id: "36e69720-8e73-447c-b172-7b17e2d73525",
//                        modulus: ABTest.ABTestVariant.Modulus(lower: 66, upper: 100),
//                        objects: [
//                            ABTest.ABTestVariant.ABTestObject(
//                                type: .inapps,
//                                kind: .concrete,
//                                inapps: [
//                                    "655f5ffa-de86-4224-a0bf-229fe208ed0d",
//                                    "b33ca779-3c99-481f-ad46-91282b0caf04",
//                                    "6f93e2ef-0615-4e63-9c80-24bcb9e83b83"
//                                ]
//                            )
//                        ]
//                    )
//                ]
//            )
//        ]
//
//        // Test case for UUID "4862ADF1-1392-9362-42A2-FF5A65629F50" with expected inapp count of 2
//        let expectedIds1 = [String]()
//        runInAppTestForUUID("4862ADF1-1392-9362-42A2-FF5A65629F50", abTests: abTests, responseInapps: response.inapps?.elements, expectedCount: expectedIds1.count, expectedIds: expectedIds1) // 25
//
//        // Test case for UUID "0809B0F8-8F21-18E8-2EF8-EC2D98938A84" with expected inapp count of 3
//        runInAppTestForUUID("0809B0F8-8F21-18E8-2EF8-EC2D98938A84", abTests: abTests, responseInapps: response.inapps?.elements, expectedCount: expectedIds1.count, expectedIds: expectedIds1) // 45
//
//        let expectedIds2 = [
//            "6f93e2ef-0615-4e63-9c80-24bcb9e83b83",
//            "655f5ffa-de86-4224-a0bf-229fe208ed0d",
//            "b33ca779-3c99-481f-ad46-91282b0caf04"
//        ]
//        // Test case for UUID "4D27710A-3F3A-FF6E-7764-375B1E06E05D" with expected inapp count of 3
//        runInAppTestForUUID("4D27710A-3F3A-FF6E-7764-375B1E06E05D", abTests: abTests, responseInapps: response.inapps?.elements, expectedCount: expectedIds2.count, expectedIds: expectedIds2) // 75
//    }
//
//    func test_ab_limit_value_check() throws {
//        let response = try getConfig(name: "ConfigWithAB_1")
//        let abTests: [ABTest]? = [
//            ABTest(
//                id: "0ec6be6b-421f-464b-9ee4-348a5292a5fd",
//                sdkVersion: SdkVersion(min: 6, max: nil),
//                salt: "BBBC2BA1-0B5B-4C9E-AB0E-95C54775B4F1",
//                variants: [
//                    ABTest.ABTestVariant(
//                        id: "155f5ffa-de86-4224-a0bf-229fe208ed0d",
//                        modulus: ABTest.ABTestVariant.Modulus(lower: 0, upper: 33),
//                        objects: [
//                            ABTest.ABTestVariant.ABTestObject(
//                                type: .inapps,
//                                kind: .concrete,
//                                inapps: []
//                            )
//                        ]
//                    ),
//                    ABTest.ABTestVariant(
//                        id: "211f1c16-fa72-4456-bf87-af448eb84a32",
//                        modulus: ABTest.ABTestVariant.Modulus(lower: 33, upper: 99),
//                        objects: [
//                            ABTest.ABTestVariant.ABTestObject(
//                                type: .inapps,
//                                kind: .concrete,
//                                inapps: [
//                                    "655f5ffa-de86-4224-a0bf-229fe208ed0d"
//                                ]
//                            )
//                        ]
//                    ),
//                    ABTest.ABTestVariant(
//                        id: "36e69720-8e73-447c-b172-7b17e2d73525",
//                        modulus: ABTest.ABTestVariant.Modulus(lower: 99, upper: 100),
//                        objects: [
//                            ABTest.ABTestVariant.ABTestObject(
//                                type: .inapps,
//                                kind: .concrete,
//                                inapps: [
//                                    "b33ca779-3c99-481f-ad46-91282b0caf04"
//                                ]
//                            )
//                        ]
//                    )
//                ]
//            )
//        ]
//
//        // Test case for UUID "F3AB8877-CB55-CE3D-1AB3-230D2EA8A220" with expected inapp count of 2
//        let expectedIds1 = ["6f93e2ef-0615-4e63-9c80-24bcb9e83b83"]
//        runInAppTestForUUID("F3AB8877-CB55-CE3D-1AB3-230D2EA8A220", abTests: abTests, responseInapps: response.inapps?.elements, expectedCount: expectedIds1.count, expectedIds: expectedIds1) // 0
//
//        let expectedIds2 = [
//            "6f93e2ef-0615-4e63-9c80-24bcb9e83b83",
//            "655f5ffa-de86-4224-a0bf-229fe208ed0d",
//        ]
//        // Test case for UUID "3A9F107E-9FBE-8D83-EFE9-5F093001CD54" with expected inapp count of 3
//        runInAppTestForUUID("3A9F107E-9FBE-8D83-EFE9-5F093001CD54", abTests: abTests, responseInapps: response.inapps?.elements, expectedCount: expectedIds2.count, expectedIds: expectedIds2) // 33
//
//        let expectedIds3 = [
//            "b33ca779-3c99-481f-ad46-91282b0caf04",
//            "6f93e2ef-0615-4e63-9c80-24bcb9e83b83",
//        ]
//        // Test case for UUID "59B675D6-9AF1-1805-2BB3-90C3CF11E5E0" with expected inapp count of 3
//        runInAppTestForUUID("59B675D6-9AF1-1805-2BB3-90C3CF11E5E0", abTests: abTests, responseInapps: response.inapps?.elements, expectedCount: expectedIds3.count, expectedIds: expectedIds3) // 99
//    }
//
//    func test_compare_5_ab_tests_in_one_branch() throws {
//        let response = try getConfig(name: "ConfigWithAB_2")
//        let abTests: [ABTest]? = [
//            ABTest(
//                id: "0ec6be6b-421f-464b-9ee4-348a5292a5fd",
//                sdkVersion: SdkVersion(min: 6, max: nil),
//                salt: "BBBC2BA1-0B5B-4C9E-AB0E-95C54775B4F1",
//                variants: [
//                    ABTest.ABTestVariant(
//                        id: "155f5ffa-de86-4224-a0bf-229fe208ed0d",
//                        modulus: ABTest.ABTestVariant.Modulus(lower: 0, upper: 10),
//                        objects: [
//                            ABTest.ABTestVariant.ABTestObject(
//                                type: .inapps,
//                                kind: .concrete,
//                                inapps: [
//                                    "655f5ffa-de86-4224-a0bf-229fe208ed0d"
//                                ]
//                            )
//                        ]
//                    ),
//                    ABTest.ABTestVariant(
//                        id: "211f1c16-fa72-4456-bf87-af448eb84a32",
//                        modulus: ABTest.ABTestVariant.Modulus(lower: 10, upper: 20),
//                        objects: [
//                            ABTest.ABTestVariant.ABTestObject(
//                                type: .inapps,
//                                kind: .concrete,
//                                inapps: [
//                                    "6f93e2ef-0615-4e63-9c80-24bcb9e83b83"
//                                ]
//                            )
//                        ]
//                    ),
//                    ABTest.ABTestVariant(
//                        id: "36e69720-8e73-447c-b172-7b17e2d73525",
//                        modulus: ABTest.ABTestVariant.Modulus(lower: 20, upper: 30),
//                        objects: [
//                            ABTest.ABTestVariant.ABTestObject(
//                                type: .inapps,
//                                kind: .concrete,
//                                inapps: [
//                                    "b33ca779-3c99-481f-ad46-91282b0caf04"
//                                ]
//                            )
//                        ]
//                    ),
//                    ABTest.ABTestVariant(
//                        id: "479b3748-747e-476f-afcd-7a9ce3f0ec71",
//                        modulus: ABTest.ABTestVariant.Modulus(lower: 30, upper: 70),
//                        objects: [
//                            ABTest.ABTestVariant.ABTestObject(
//                                type: .inapps,
//                                kind: .concrete,
//                                inapps: [
//                                    "d1b312bd-aa5c-414c-a0d8-8126376a2a9b"
//                                ]
//                            )
//                        ]
//                    ),
//                    ABTest.ABTestVariant(
//                        id: "5fb3e501-11c2-418d-b774-2ee26d31f556",
//                        modulus: ABTest.ABTestVariant.Modulus(lower: 70, upper: 100),
//                        objects: [
//                            ABTest.ABTestVariant.ABTestObject(
//                                type: .inapps,
//                                kind: .all,
//                                inapps: nil
//                            )
//                        ]
//                    )
//                ]
//            )
//        ]
//
//        // Test case for UUID "7544976E-FEA4-6A48-EB5D-85A6EEB4D306" with expected inapp count of 21
//        let expectedIds1 = ["655f5ffa-de86-4224-a0bf-229fe208ed0d"]
//        runInAppTestForUUID("7544976E-FEA4-6A48-EB5D-85A6EEB4D306", abTests: abTests, responseInapps: response.inapps?.elements, expectedCount: expectedIds1.count, expectedIds: expectedIds1) // 5
//
//        let expectedIds2 = ["6f93e2ef-0615-4e63-9c80-24bcb9e83b83"]
//        // Test case for UUID "618F8CA3-282D-5B18-7186-F2CF361ABD32" with expected inapp count of 1
//        runInAppTestForUUID("618F8CA3-282D-5B18-7186-F2CF361ABD32", abTests: abTests, responseInapps: response.inapps?.elements, expectedCount: expectedIds2.count, expectedIds: expectedIds2) // 15
//
//        let expectedIds3 = ["b33ca779-3c99-481f-ad46-91282b0caf04"]
//        runInAppTestForUUID("DC0F2330-785B-5D80-CD34-F2F520AD618F", abTests: abTests, responseInapps: response.inapps?.elements, expectedCount: expectedIds3.count, expectedIds: expectedIds3) // 25
//
//        let expectedIds4 = ["d1b312bd-aa5c-414c-a0d8-8126376a2a9b"]
//        runInAppTestForUUID("0809B0F8-8F21-18E8-2EF8-EC2D98938A84", abTests: abTests, responseInapps: response.inapps?.elements, expectedCount: expectedIds4.count, expectedIds: expectedIds4) // 45
//
//        let expectedIds5 = [
//            "655f5ffa-de86-4224-a0bf-229fe208ed0d",
//            "6f93e2ef-0615-4e63-9c80-24bcb9e83b83",
//            "b33ca779-3c99-481f-ad46-91282b0caf04",
//            "d1b312bd-aa5c-414c-a0d8-8126376a2a9b"]
//        runInAppTestForUUID("4D27710A-3F3A-FF6E-7764-375B1E06E05D", abTests: abTests, responseInapps: response.inapps?.elements, expectedCount: expectedIds5.count, expectedIds: expectedIds5) // 75
//    }
//
//    func test_2_different_ab_tests_one() throws {
//        let response = try getConfig(name: "ConfigWithAB_1")
//        let abtests: [ABTest]? = [
//            ABTest(
//                id: "0ec6be6b-421f-464b-9ee4-348a5292a5fd",
//                sdkVersion: SdkVersion(min: 6, max: nil),
//                salt: "c0e2682c-3d0f-4291-9308-9e48a16eb3c8",
//                variants: [
//                    ABTest.ABTestVariant(
//                        id: "155f5ffa-de86-4224-a0bf-229fe208ed0d",
//                        modulus: ABTest.ABTestVariant.Modulus(lower: 0, upper: 25),
//                        objects: [
//                            ABTest.ABTestVariant.ABTestObject(
//                                type: .inapps,
//                                kind: .concrete,
//                                inapps: []
//                            )
//                        ]
//                    ),
//                    ABTest.ABTestVariant(
//                        id: "211f1c16-fa72-4456-bf87-af448eb84a32",
//                        modulus: ABTest.ABTestVariant.Modulus(lower: 25, upper: 100),
//                        objects: [
//                            ABTest.ABTestVariant.ABTestObject(
//                                type: .inapps,
//                                kind: .all,
//                                inapps: nil
//                            )
//                        ]
//                    )
//                ]
//            ),
//            ABTest(
//                id: "1ec6be6b-421f-464b-9ee4-348a5292a5fd",
//                sdkVersion: SdkVersion(min: 6, max: nil),
//                salt: "b142ff09-68c4-41f9-985d-d220edfad4f",
//                variants: [
//                    ABTest.ABTestVariant(
//                        id: "36e69720-8e73-447c-b172-7b17e2d73525",
//                        modulus: ABTest.ABTestVariant.Modulus(lower: 0, upper: 75),
//                        objects: [
//                            ABTest.ABTestVariant.ABTestObject(
//                                type: .inapps,
//                                kind: .concrete,
//                                inapps: []
//                            )
//                        ]
//                    ),
//                    ABTest.ABTestVariant(
//                        id: "479b3748-747e-476f-afcd-7a9ce3f0ec71",
//                        modulus: ABTest.ABTestVariant.Modulus(lower: 75, upper: 100),
//                        objects: [
//                            ABTest.ABTestVariant.ABTestObject(
//                                type: .inapps,
//                                kind: .concrete,
//                                inapps: [
//                                    "655f5ffa-de86-4224-a0bf-229fe208ed0d",
//                                    "6f93e2ef-0615-4e63-9c80-24bcb9e83b83"
//                                ]
//                            )
//                        ]
//                    )
//                ]
//            )
//        ]
//
//        let expectedIds1 = [String]()
//        runInAppTestForUUID("9d7f8e6c-3a2b-4d9a-b1c0-1e1e3a4b5c6d", abTests: abtests, responseInapps: response.inapps?.elements, expectedCount: expectedIds1.count, expectedIds: expectedIds1) // 23 and 29
//
//        runInAppTestForUUID("284c10f7-4f4c-4a1b-92e0-2318f2ae13c9", abTests: abtests, responseInapps: response.inapps?.elements, expectedCount: expectedIds1.count, expectedIds: expectedIds1) // 1 and 91
//
//        let expectedIds2 = ["b33ca779-3c99-481f-ad46-91282b0caf04"]
//        runInAppTestForUUID("677a789d-9a98-4f03-9cb2-af2563fc1d07", abTests: abtests, responseInapps: response.inapps?.elements, expectedCount: expectedIds2.count, expectedIds: expectedIds2) // 88 and 5
//
//        let expectedIds3 = ["b33ca779-3c99-481f-ad46-91282b0caf04",
//                            "655f5ffa-de86-4224-a0bf-229fe208ed0d",
//                            "6f93e2ef-0615-4e63-9c80-24bcb9e83b83"]
//        runInAppTestForUUID("d35df6c2-9e20-4f7e-9e20-51894e2c4810", abTests: abtests, responseInapps: response.inapps?.elements, expectedCount: expectedIds3.count, expectedIds: expectedIds3) // 61 and 94
//    }
//
//    func test_2_different_ab_tests_two() throws {
////        XCTAssertTrue(false)
//    }
//
//    func test_concrete_inapps_and_all() throws {
//        let response = try getConfig(name: "ConfigWithAB_1")
//        let abtests: [ABTest]? = [
//            ABTest(
//                id: "0ec6be6b-421f-464b-9ee4-348a5292a5fd",
//                sdkVersion: SdkVersion(min: 6, max: nil),
//                salt: "BBBC2BA1-0B5B-4C9E-AB0E-95C54775B4F1",
//                variants: [
//                    ABTest.ABTestVariant(
//                        id: "155f5ffa-de86-4224-a0bf-229fe208ed0d",
//                        modulus: ABTest.ABTestVariant.Modulus(lower: 0, upper: 35),
//                        objects: [
//                            ABTest.ABTestVariant.ABTestObject(
//                                type: .inapps,
//                                kind: .concrete,
//                                inapps: [
//                                    "655f5ffa-de86-4224-a0bf-229fe208ed0d",
//                                    "b33ca779-3c99-481f-ad46-91282b0caf04"
//                                ]
//                            )
//                        ]
//                    ),
//                    ABTest.ABTestVariant(
//                        id: "211f1c16-fa72-4456-bf87-af448eb84a32",
//                        modulus: ABTest.ABTestVariant.Modulus(lower: 35, upper: 100),
//                        objects: [
//                            ABTest.ABTestVariant.ABTestObject(
//                                type: .inapps,
//                                kind: .all,
//                                inapps: nil
//                            )
//                        ]
//                    )
//                ]
//            )
//        ]
//
//        // Test case for UUID "F3AB8877-CB55-CE3D-1AB3-230D2EA8A220" with expected inapp count of 2
//        let expectedIds1 = [
//            "655f5ffa-de86-4224-a0bf-229fe208ed0d",
//            "b33ca779-3c99-481f-ad46-91282b0caf04"
//        ]
//
//        runInAppTestForUUID("4078E211-7C3F-C607-D35C-DC6B591EF355", abTests: abtests, responseInapps: response.inapps?.elements, expectedCount: expectedIds1.count, expectedIds: expectedIds1) // 25
//
//        let expectedIds2 = [
//            "655f5ffa-de86-4224-a0bf-229fe208ed0d",
//            "b33ca779-3c99-481f-ad46-91282b0caf04",
//            "6f93e2ef-0615-4e63-9c80-24bcb9e83b83"
//        ]
//
//        runInAppTestForUUID("4D27710A-3F3A-FF6E-7764-375B1E06E05D", abTests: abtests, responseInapps: response.inapps?.elements, expectedCount: expectedIds2.count, expectedIds: expectedIds2) // 75
//    }
//
//    func test_section_ab_broken_return_nil() throws {
//        let response = try getConfig(name: "ConfigWithABBrokenRange") // Отсутствует диапазон 33-66
//        XCTAssertNil(response.abtests)
//
//        let response2 = try getConfig(name: "ConfigWithABNoSalt") // Отсутствует соль
//        XCTAssertNil(response2.abtests)
//
//        let response3 = try getConfig(name: "ConfigWithABUnexpectedValue") // Неожиданное ключ-значение
//        XCTAssertNil(response3.abtests)
//
//        let response4 = try getConfig(name: "ConfigWithABCrossRange") // Неожиданное ключ-значение
//        XCTAssertNil(response4.abtests)
//
//        let response5 = try getConfig(name: "ConfigWithABNoUpper") // Отсутствует ключ upper в одном из вариантов
//        XCTAssertNil(response5.abtests)
//
//        let response6 = try getConfig(name: "ConfigWithABLowerBiggerThanUpper") // Lower больше, чем Upper
//        XCTAssertNil(response6.abtests)
//    }
//
//    func test_sdkversion_lower_than_ab_tests_version() throws {
//        let response = try getConfig(name: "ConfigWithABNormal")
//        XCTAssertNil(response.abtests)
//    }
//
//    func test_ab_test_type_not_inapps_return_nil() throws {
//        let response = try getConfig(name: "ConfigWithABTypeNotInapps")
//        XCTAssertNil(response.abtests)
//    }
//}
//
//private extension ABTests {
//    private func getConfig(name: String) throws -> ConfigResponse {
//        let bundle = Bundle(for: ABTests.self)
//        let fileURL = bundle.url(forResource: name, withExtension: "json")!
//        let data = try Data(contentsOf: fileURL)
//        return try JSONDecoder().decode(ConfigResponse.self, from: data)
//    }
//
//    private func runInAppTestForUUID(_ uuid: String, abTests: [ABTest]?, responseInapps: [InApp]?, expectedCount: Int, expectedIds: [String]) {
//        persistenceStorage.deviceUUID = uuid
//        let inapps = mapper.filterInappsByABTests(abTests, responseInapps: responseInapps)
//        XCTAssertEqual(inapps.count, expectedCount)
//        for inapp in inapps {
//            XCTAssertTrue(expectedIds.contains { $0 == inapp.id })
//        }
//    }
//}
