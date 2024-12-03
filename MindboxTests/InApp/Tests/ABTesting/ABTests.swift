////
////  ABTests.swift
////  MindboxTests
////
////  Created by vailence on 19.06.2023.
////  Copyright © 2023 Mindbox. All rights reserved.
////

// swiftlint:disable file_length

import Foundation
import XCTest
@testable import Mindbox

fileprivate enum InappConfig: String, Configurable {
    typealias DecodeType = ConfigResponse

    case configWithABTest = "ConfigWithAB_1"
    case configWithABTestTwo = "ConfigWithAB_2"
    case configWithABBrokenRange = "ConfigWithABBrokenRange"
    case configWithABNoSalt = "ConfigWithABNoSalt"
    case configWithABUnexpectedValue = "ConfigWithABUnexpectedValue"
    case configWithABCrossRange = "ConfigWithABCrossRange"
    case configWithABNoUpper = "ConfigWithABNoUpper"
    case configWithABLowerBiggerThanUpper = "ConfigWithABLowerBiggerThanUpper"
    case configWithABNormal = "ConfigWithABNormal"
    case configWithABTypeNotInapps = "ConfigWithABTypeNotInapps"
}
class ABTests: XCTestCase {

    private var inappFilter: InappFilterProtocol!
    private var variantsFilter: VariantFilterProtocol!
    private var persistenceStorage: PersistenceStorage!
    private var stub: ABTestsStub!

    override func setUp() {
        self.inappFilter = DI.injectOrFail(InappFilterProtocol.self)
        self.variantsFilter = DI.injectOrFail(VariantFilterProtocol.self)
        self.persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
        self.stub = ABTestsStub()
    }

    override func tearDown() {
        self.inappFilter = nil
        self.variantsFilter = nil
        self.persistenceStorage = nil
        self.stub = nil
    }

    func test_no_abtests() throws {
        let response = try InappConfig.configWithABTest.getConfig()

        let filteredInapps = filterValidInAppMessages(response.inapps?.elements ?? [])
        let expectedIds: Set = [
            "1",
            "2",
            "3"
        ]

        persistenceStorage.deviceUUID = "BBBC2BA1-0B5B-4C9E-AB0E-95C54775B4F1"
        let inapps = inappFilter.filterInappsByABTests(nil, responseInapps: filteredInapps)

        XCTAssertEqual(inapps.count, expectedIds.count, "Количество инапов не совпадает с ожидаемым")

        let inappIds = Set(inapps.map { $0.id })
        XCTAssertEqual(inappIds, expectedIds, "Идентификаторы инапов не совпадают с ожидаемыми")
    }

    func test_compare_inapps_with_cg() throws {
        let response = try InappConfig.configWithABTest.getConfig()

        let abTests: [ABTest]? = [
            stub.getABTest(variants: [
                stub.getVariantConcrete(id: "2", lower: 0, upper: 50),
                stub.getVariantAll(lower: 50, upper: 100)
            ])
        ]

        let filteredInapps = filterValidInAppMessages(response.inapps?.elements ?? [])
        persistenceStorage.deviceUUID = "4078E211-7C3F-C607-D35C-DC6B591EF355"
        let inappsFirstVariant = inappFilter.filterInappsByABTests(abTests, responseInapps: filteredInapps)
        XCTAssertEqual(inappsFirstVariant.count, 0, "Количество инапов не совпадает с ожидаемым")

        let expectedIdsForVariantTwo: Set = [
            "1",
            "2",
            "3"
        ]

        persistenceStorage.deviceUUID = "4D27710A-3F3A-FF6E-7764-375B1E06E05D"
        let inappsSecondVariant = inappFilter.filterInappsByABTests(abTests, responseInapps: filteredInapps)
        XCTAssertEqual(inappsSecondVariant.count, expectedIdsForVariantTwo.count, "Количество инапов не совпадает с ожидаемым")

        let inappIds = Set(inappsSecondVariant.map { $0.id })
        XCTAssertEqual(inappIds, expectedIdsForVariantTwo, "Идентификаторы инапов не совпадают с ожидаемыми")
    }

    func test_compare_cg_and_concrete_inapps() throws {
        let response = try InappConfig.configWithABTestTwo.getConfig()
        let filteredInapps = filterValidInAppMessages(response.inapps?.elements ?? [])

        let abTests: [ABTest]? = [
            stub.getABTest(variants: [
                stub.getVariantConcrete(lower: 0, upper: 50),
                stub.getVariantConcrete(id: "2", lower: 50, upper: 100, inapps: [
                    "1",
                    "3"
                ])
            ])
        ]

        let expectedIds1: Set = [
            "2",
            "4"
        ]

        persistenceStorage.deviceUUID = "4078E211-7C3F-C607-D35C-DC6B591EF355"
        let inappsFirstVariant = inappFilter.filterInappsByABTests(abTests, responseInapps: filteredInapps)
        XCTAssertEqual(inappsFirstVariant.count, expectedIds1.count, "Количество инапов не совпадает с ожидаемым")
        let inappIdsOne = Set(inappsFirstVariant.map { $0.id })
        XCTAssertEqual(inappIdsOne, expectedIds1, "Идентификаторы инапов не совпадают с ожидаемыми")

        // Second variant

        // Test case for UUID "4D27710A-3F3A-FF6E-7764-375B1E06E05D" with expected inapp count of 4
        let expectedIds2: Set = [
            "1",
            "2",
            "3",
            "4"
        ]

        persistenceStorage.deviceUUID = "4D27710A-3F3A-FF6E-7764-375B1E06E05D"
        let inappsSecondVariant = inappFilter.filterInappsByABTests(abTests, responseInapps: filteredInapps)
        XCTAssertEqual(inappsSecondVariant.count, expectedIds2.count, "Количество инапов не совпадает с ожидаемым")
        let inappIdsTwo = Set(inappsSecondVariant.map { $0.id })
        XCTAssertEqual(inappIdsTwo, expectedIds2, "Идентификаторы инапов не совпадают с ожидаемыми")
    }

    func test_compare_cg_and_concrete_inapps_and_all_inapps() throws {
        let response = try InappConfig.configWithABTest.getConfig()
        let filteredInapps = filterValidInAppMessages(response.inapps?.elements ?? [])

        let abTests: [ABTest]? = [
            stub.getABTest(variants: [
                stub.getVariantConcrete(lower: 0, upper: 30, inapps: []),
                stub.getVariantConcrete(id: "211f1c16-fa72-4456-bf87-af448eb84a32", lower: 30, upper: 65, inapps: ["1", "3"]),
                stub.getVariantAll(lower: 65, upper: 100)
            ])
        ]

        // Test case for UUID "4078E211-7C3F-C607-D35C-DC6B591EF355" with expected inapp count of 0
        persistenceStorage.deviceUUID = "4078E211-7C3F-C607-D35C-DC6B591EF355"
        let inappsFirstVariant = inappFilter.filterInappsByABTests(abTests, responseInapps: filteredInapps)
        XCTAssertEqual(inappsFirstVariant.count, 0, "Количество инапов не совпадает с ожидаемым")
        XCTAssertTrue(inappsFirstVariant.isEmpty, "Инапы должны быть пустыми")

        // Test case for UUID "0809B0F8-8F21-18E8-2EF8-EC2D98938A84" with expected inapp count of 2
        persistenceStorage.deviceUUID = "0809B0F8-8F21-18E8-2EF8-EC2D98938A84"
        let inappsSecondVariant = inappFilter.filterInappsByABTests(abTests, responseInapps: filteredInapps)
        let expectedIdsForSecondVariant: Set = [
            "1",
            "3"
        ]
        XCTAssertEqual(inappsSecondVariant.count, expectedIdsForSecondVariant.count, "Количество инапов не совпадает с ожидаемым")
        XCTAssertEqual(Set(inappsSecondVariant.map { $0.id }), expectedIdsForSecondVariant, "Идентификаторы инапов не совпадают с ожидаемыми")

        // Test case for UUID "4D27710A-3F3A-FF6E-7764-375B1E06E05D" with expected inapp count of 3
        persistenceStorage.deviceUUID = "4D27710A-3F3A-FF6E-7764-375B1E06E05D"
        let inappsThirdVariant = inappFilter.filterInappsByABTests(abTests, responseInapps: filteredInapps)
        let expectedIdsForThirdVariant: Set = [
            "1",
            "2",
            "3"
        ]
        XCTAssertEqual(inappsThirdVariant.count, expectedIdsForThirdVariant.count, "Количество инапов не совпадает с ожидаемым")
        XCTAssertEqual(Set(inappsThirdVariant.map { $0.id }), expectedIdsForThirdVariant, "Идентификаторы инапов не совпадают с ожидаемыми")
    }

    func test_compare_2branch_and_concrete_inapps_and_cg() throws {
        let response = try InappConfig.configWithABTestTwo.getConfig()
        let filteredInapps = filterValidInAppMessages(response.inapps?.elements ?? [])

        let abTests: [ABTest]? = [
            stub.getABTest(variants: [
                stub.getVariantConcrete(lower: 0, upper: 27, inapps: []),
                stub.getVariantConcrete(id: "2", lower: 27, upper: 65, inapps: [
                    "1"
                ]),
                stub.getVariantConcrete(lower: 65, upper: 100, inapps: [
                    "3"
                ])
            ])
        ]

        // Test case for UUID "4078E211-7C3F-C607-D35C-DC6B591EF355"
        persistenceStorage.deviceUUID = "4078E211-7C3F-C607-D35C-DC6B591EF355"
        let inappsFirstVariant = inappFilter.filterInappsByABTests(abTests, responseInapps: filteredInapps)
        let expectedIds1: Set = [
            "2",
            "4"
        ]
        XCTAssertEqual(inappsFirstVariant.count, expectedIds1.count, "Количество инапов не совпадает с ожидаемым")
        XCTAssertEqual(Set(inappsFirstVariant.map { $0.id }), expectedIds1, "Идентификаторы инапов не совпадают с ожидаемыми")

        // Test case for UUID "0809B0F8-8F21-18E8-2EF8-EC2D98938A84"
        persistenceStorage.deviceUUID = "0809B0F8-8F21-18E8-2EF8-EC2D98938A84"
        let inappsSecondVariant = inappFilter.filterInappsByABTests(abTests, responseInapps: filteredInapps)
        let expectedIds2: Set = [
            "1",
            "2",
            "4"
        ]
        XCTAssertEqual(inappsSecondVariant.count, expectedIds2.count, "Количество инапов не совпадает с ожидаемым")
        XCTAssertEqual(Set(inappsSecondVariant.map { $0.id }), expectedIds2, "Идентификаторы инапов не совпадают с ожидаемыми")

        // Test case for UUID "4D27710A-3F3A-FF6E-7764-375B1E06E05D"
        persistenceStorage.deviceUUID = "4D27710A-3F3A-FF6E-7764-375B1E06E05D"
        let inappsThirdVariant = inappFilter.filterInappsByABTests(abTests, responseInapps: filteredInapps)
        let expectedIds3: Set = [
            "2",
            "3",
            "4"
        ]
        XCTAssertEqual(inappsThirdVariant.count, expectedIds3.count, "Количество инапов не совпадает с ожидаемым")
        XCTAssertEqual(Set(inappsThirdVariant.map { $0.id }), expectedIds3, "Идентификаторы инапов не совпадают с ожидаемыми")
    }

    func test_compare_2branch_and_concrete_inapps() throws {
        let response = try InappConfig.configWithABTest.getConfig()
        let filteredInapps = filterValidInAppMessages(response.inapps?.elements ?? [])

        let abTests: [ABTest]? = [
            stub.getABTest(variants: [
                stub.getVariantConcrete(lower: 0, upper: 99, inapps: [
                    "1",
                    "3"
                ]),
                stub.getVariantConcrete(lower: 99, upper: 100, inapps: [
                    "2"
                ])
            ])
        ]

        // Test case for UUID "4078E211-7C3F-C607-D35C-DC6B591EF355"
        persistenceStorage.deviceUUID = "4078E211-7C3F-C607-D35C-DC6B591EF355"
        let inappsFirstVariant = inappFilter.filterInappsByABTests(abTests, responseInapps: filteredInapps)
        let expectedIds1: Set = [
            "1",
            "3"
        ]
        XCTAssertEqual(inappsFirstVariant.count, expectedIds1.count, "Количество инапов не совпадает с ожидаемым")
        XCTAssertEqual(Set(inappsFirstVariant.map { $0.id }), expectedIds1, "Идентификаторы инапов не совпадают с ожидаемыми")

        // Test case for UUID "C9F84B44-01B9-A3C6-E85B-7FF816D3BA68"
        persistenceStorage.deviceUUID = "C9F84B44-01B9-A3C6-E85B-7FF816D3BA68"
        let inappsSecondVariant = inappFilter.filterInappsByABTests(abTests, responseInapps: filteredInapps)
        let expectedIds2: Set = [
            "2"
        ]
        XCTAssertEqual(inappsSecondVariant.count, expectedIds2.count, "Количество инапов не совпадает с ожидаемым")
        XCTAssertEqual(Set(inappsSecondVariant.map { $0.id }), expectedIds2, "Идентификаторы инапов не совпадают с ожидаемыми")
    }
    func test_aab_show_inapps_in_cg_branch() throws {
        let response = try InappConfig.configWithABTest.getConfig()
        let filteredInapps = filterValidInAppMessages(response.inapps?.elements ?? [])

        let abTests: [ABTest]? = [
            stub.getABTest(variants: [
                stub.getVariantConcrete(lower: 0, upper: 33, inapps: []),
                stub.getVariantConcrete(lower: 33, upper: 66, inapps: []),
                stub.getVariantConcrete(lower: 66, upper: 100, inapps: [
                    "1",
                    "3"
                ])
            ])
        ]

        // Test case for UUID "4862ADF1-1392-9362-42A2-FF5A65629F50"
        persistenceStorage.deviceUUID = "4862ADF1-1392-9362-42A2-FF5A65629F50"
        let inappsFirstVariant = inappFilter.filterInappsByABTests(abTests, responseInapps: filteredInapps)
        let expectedIds1: Set = [
            "2"
        ]
        XCTAssertEqual(inappsFirstVariant.count, expectedIds1.count, "Количество инапов не совпадает с ожидаемым")
        XCTAssertEqual(Set(inappsFirstVariant.map { $0.id }), expectedIds1, "Идентификаторы инапов не совпадают с ожидаемыми")

        // Test case for UUID "0809B0F8-8F21-18E8-2EF8-EC2D98938A84"
        persistenceStorage.deviceUUID = "0809B0F8-8F21-18E8-2EF8-EC2D98938A84"
        let inappsSecondVariant = inappFilter.filterInappsByABTests(abTests, responseInapps: filteredInapps)
        XCTAssertEqual(inappsSecondVariant.count, expectedIds1.count, "Количество инапов не совпадает с ожидаемым")
        XCTAssertEqual(Set(inappsSecondVariant.map { $0.id }), expectedIds1, "Идентификаторы инапов не совпадают с ожидаемыми")

        // Test case for UUID "4D27710A-3F3A-FF6E-7764-375B1E06E05D"
        persistenceStorage.deviceUUID = "4D27710A-3F3A-FF6E-7764-375B1E06E05D"
        let inappsThirdVariant = inappFilter.filterInappsByABTests(abTests, responseInapps: filteredInapps)
        let expectedIds2: Set = [
            "1",
            "2",
            "3"
        ]
        XCTAssertEqual(inappsThirdVariant.count, expectedIds2.count, "Количество инапов не совпадает с ожидаемым")
        XCTAssertEqual(Set(inappsThirdVariant.map { $0.id }), expectedIds2, "Идентификаторы инапов не совпадают с ожидаемыми")
    }

    func test_aab_not_show_inapps_in_cg_branch() throws {
        let response = try InappConfig.configWithABTest.getConfig()
        let filteredInapps = filterValidInAppMessages(response.inapps?.elements ?? [])

        let abTests: [ABTest]? = [
            stub.getABTest(
                id: "c0e2682c-3d0f-4291-9308-9e48a16eb3c8", // Custom ID
                variants: [
                    stub.getVariantConcrete(id: "1", lower: 0, upper: 33, inapps: []),
                    stub.getVariantConcrete(id: "2", lower: 33, upper: 66, inapps: []),
                    stub.getVariantConcrete(id: "3", lower: 66, upper: 100, inapps: [
                        "1",
                        "2",
                        "3"
                    ])
                ]
            )
        ]

        // Test case for UUID "4862ADF1-1392-9362-42A2-FF5A65629F50"
        persistenceStorage.deviceUUID = "4862ADF1-1392-9362-42A2-FF5A65629F50"
        let inappsFirstVariant = inappFilter.filterInappsByABTests(abTests, responseInapps: filteredInapps)
        XCTAssertEqual(inappsFirstVariant.count, 0, "Количество инапов не совпадает с ожидаемым")

        // Test case for UUID "0809B0F8-8F21-18E8-2EF8-EC2D98938A84"
        persistenceStorage.deviceUUID = "0809B0F8-8F21-18E8-2EF8-EC2D98938A84"
        let inappsSecondVariant = inappFilter.filterInappsByABTests(abTests, responseInapps: filteredInapps)
        XCTAssertEqual(inappsSecondVariant.count, 0, "Количество инапов не совпадает с ожидаемым")

        // Test case for UUID "4D27710A-3F3A-FF6E-7764-375B1E06E05D"
        persistenceStorage.deviceUUID = "4D27710A-3F3A-FF6E-7764-375B1E06E05D"
        let inappsThirdVariant = inappFilter.filterInappsByABTests(abTests, responseInapps: filteredInapps)
        let expectedIds3: Set = [
            "1",
            "2",
            "3"
        ]
        XCTAssertEqual(inappsThirdVariant.count, expectedIds3.count, "Количество инапов не совпадает с ожидаемым")
        XCTAssertEqual(Set(inappsThirdVariant.map { $0.id }), expectedIds3, "Идентификаторы инапов не совпадают с ожидаемыми")
    }

    func test_ab_limit_value_check() throws {
        let response = try InappConfig.configWithABTest.getConfig()
        let filteredInapps = filterValidInAppMessages(response.inapps?.elements ?? [])

        let abTests: [ABTest]? = [
            stub.getABTest(
                variants: [
                    stub.getVariantConcrete(lower: 0, upper: 33, inapps: []),
                    stub.getVariantConcrete(lower: 33, upper: 99, inapps: [
                        "1"
                    ]),
                    stub.getVariantConcrete(lower: 99, upper: 100, inapps: [
                        "3"
                    ])
                ]
            )
        ]

        // Test case for UUID "F3AB8877-CB55-CE3D-1AB3-230D2EA8A220"
        persistenceStorage.deviceUUID = "F3AB8877-CB55-CE3D-1AB3-230D2EA8A220"
        let inappsFirstVariant = inappFilter.filterInappsByABTests(abTests, responseInapps: filteredInapps)
        let expectedIds1: Set = [
            "2"
        ]
        XCTAssertEqual(inappsFirstVariant.count, expectedIds1.count, "Количество инапов не совпадает с ожидаемым")
        XCTAssertEqual(Set(inappsFirstVariant.map { $0.id }), expectedIds1, "Идентификаторы инапов не совпадают с ожидаемыми")

        // Test case for UUID "3A9F107E-9FBE-8D83-EFE9-5F093001CD54"
        persistenceStorage.deviceUUID = "3A9F107E-9FBE-8D83-EFE9-5F093001CD54"
        let inappsSecondVariant = inappFilter.filterInappsByABTests(abTests, responseInapps: filteredInapps)
        let expectedIds2: Set = [
            "1",
            "2"
        ]
        XCTAssertEqual(inappsSecondVariant.count, expectedIds2.count, "Количество инапов не совпадает с ожидаемым")
        XCTAssertEqual(Set(inappsSecondVariant.map { $0.id }), expectedIds2, "Идентификаторы инапов не совпадают с ожидаемыми")

        // Test case for UUID "59B675D6-9AF1-1805-2BB3-90C3CF11E5E0"
        persistenceStorage.deviceUUID = "59B675D6-9AF1-1805-2BB3-90C3CF11E5E0"
        let inappsThirdVariant = inappFilter.filterInappsByABTests(abTests, responseInapps: filteredInapps)
        let expectedIds3: Set = [
            "2",
            "3"
        ]
        XCTAssertEqual(inappsThirdVariant.count, expectedIds3.count, "Количество инапов не совпадает с ожидаемым")
        XCTAssertEqual(Set(inappsThirdVariant.map { $0.id }), expectedIds3, "Идентификаторы инапов не совпадают с ожидаемыми")
    }

    func test_compare_5_ab_tests_in_one_branch() throws {
        let response = try InappConfig.configWithABTestTwo.getConfig()
        let filteredInapps = filterValidInAppMessages(response.inapps?.elements ?? [])

        let abTests: [ABTest]? = [
            stub.getABTest(
                variants: [
                    stub.getVariantConcrete(lower: 0, upper: 10, inapps: [
                        "1"
                    ]),
                    stub.getVariantConcrete(lower: 10, upper: 20, inapps: [
                        "2"
                    ]),
                    stub.getVariantConcrete(lower: 20, upper: 30, inapps: [
                        "3"
                    ]),
                    stub.getVariantConcrete(lower: 30, upper: 70, inapps: [
                        "4"
                    ]),
                    stub.getVariantAll(lower: 70, upper: 100)
                ]
            )
        ]

        // Тест для UUID "7544976E-FEA4-6A48-EB5D-85A6EEB4D306"
        persistenceStorage.deviceUUID = "7544976E-FEA4-6A48-EB5D-85A6EEB4D306"
        let inappsFirstVariant = inappFilter.filterInappsByABTests(abTests, responseInapps: filteredInapps)
        let expectedIds1: Set = [
            "1"
        ]
        XCTAssertEqual(inappsFirstVariant.count, expectedIds1.count, "Количество инапов не совпадает с ожидаемым")
        XCTAssertEqual(Set(inappsFirstVariant.map { $0.id }), expectedIds1, "Идентификаторы инапов не совпадают с ожидаемыми")

        // Тест для UUID "618F8CA3-282D-5B18-7186-F2CF361ABD32"
        persistenceStorage.deviceUUID = "618F8CA3-282D-5B18-7186-F2CF361ABD32"
        let inappsSecondVariant = inappFilter.filterInappsByABTests(abTests, responseInapps: filteredInapps)
        let expectedIds2: Set = [
            "2"
        ]
        XCTAssertEqual(inappsSecondVariant.count, expectedIds2.count, "Количество инапов не совпадает с ожидаемым")
        XCTAssertEqual(Set(inappsSecondVariant.map { $0.id }), expectedIds2, "Идентификаторы инапов не совпадают с ожидаемыми")

        // Тест для UUID "DC0F2330-785B-5D80-CD34-F2F520AD618F"
        persistenceStorage.deviceUUID = "DC0F2330-785B-5D80-CD34-F2F520AD618F"
        let inappsThirdVariant = inappFilter.filterInappsByABTests(abTests, responseInapps: filteredInapps)
        let expectedIds3: Set = [
            "3"
        ]
        XCTAssertEqual(inappsThirdVariant.count, expectedIds3.count, "Количество инапов не совпадает с ожидаемым")
        XCTAssertEqual(Set(inappsThirdVariant.map { $0.id }), expectedIds3, "Идентификаторы инапов не совпадают с ожидаемыми")

        // Тест для UUID "0809B0F8-8F21-18E8-2EF8-EC2D98938A84"
        persistenceStorage.deviceUUID = "0809B0F8-8F21-18E8-2EF8-EC2D98938A84"
        let inappsFourthVariant = inappFilter.filterInappsByABTests(abTests, responseInapps: filteredInapps)
        let expectedIds4: Set = [
            "4"
        ]
        XCTAssertEqual(inappsFourthVariant.count, expectedIds4.count, "Количество инапов не совпадает с ожидаемым")
        XCTAssertEqual(Set(inappsFourthVariant.map { $0.id }), expectedIds4, "Идентификаторы инапов не совпадают с ожидаемыми")

        // Тест для UUID "4D27710A-3F3A-FF6E-7764-375B1E06E05D"
        persistenceStorage.deviceUUID = "4D27710A-3F3A-FF6E-7764-375B1E06E05D"
        let inappsFifthVariant = inappFilter.filterInappsByABTests(abTests, responseInapps: filteredInapps)
        let expectedIds5: Set = [
            "1",
            "2",
            "3",
            "4"
        ]
        XCTAssertEqual(inappsFifthVariant.count, expectedIds5.count, "Количество инапов не совпадает с ожидаемым")
        XCTAssertEqual(Set(inappsFifthVariant.map { $0.id }), expectedIds5, "Идентификаторы инапов не совпадают с ожидаемыми")
    }

    func test_2_different_ab_tests_one() throws {
        let response = try InappConfig.configWithABTest.getConfig()
        let filteredInapps = filterValidInAppMessages(response.inapps?.elements ?? [])

        let abTests: [ABTest]? = [
            stub.getABTest(
                salt: "c0e2682c-3d0f-4291-9308-9e48a16eb3c8", // Custom salt
                variants: [
                    stub.getVariantConcrete(lower: 0, upper: 25, inapps: []),
                    stub.getVariantAll(lower: 25, upper: 100)
                ]
            ),
            stub.getABTest(
                id: "1ec6be6b-421f-464b-9ee4-348a5292a5fd", // Custom ID
                salt: "b142ff09-68c4-41f9-985d-d220edfad4f", // Custom salt
                variants: [
                    stub.getVariantConcrete(lower: 0, upper: 75, inapps: []),
                    stub.getVariantConcrete(lower: 75, upper: 100, inapps: [
                        "1",
                        "2"
                    ])
                ]
            )
        ]

        // Test case for UUID "9d7f8e6c-3a2b-4d9a-b1c0-1e1e3a4b5c6d"
        persistenceStorage.deviceUUID = "9d7f8e6c-3a2b-4d9a-b1c0-1e1e3a4b5c6d"
        let inappsFirstVariant = inappFilter.filterInappsByABTests(abTests, responseInapps: filteredInapps)
        XCTAssertEqual(inappsFirstVariant.count, 0, "Количество инапов не совпадает с ожидаемым")

        // Test case for UUID "284c10f7-4f4c-4a1b-92e0-2318f2ae13c9"
        persistenceStorage.deviceUUID = "284c10f7-4f4c-4a1b-92e0-2318f2ae13c9"
        let inappsSecondVariant = inappFilter.filterInappsByABTests(abTests, responseInapps: filteredInapps)
        XCTAssertEqual(inappsSecondVariant.count, 0, "Количество инапов не совпадает с ожидаемым")

        // Test case for UUID "677a789d-9a98-4f03-9cb2-af2563fc1d07"
        persistenceStorage.deviceUUID = "677a789d-9a98-4f03-9cb2-af2563fc1d07"
        let inappsThirdVariant = inappFilter.filterInappsByABTests(abTests, responseInapps: filteredInapps)
        let expectedIds2: Set = [
            "3"
        ]
        XCTAssertEqual(inappsThirdVariant.count, expectedIds2.count, "Количество инапов не совпадает с ожидаемым")
        XCTAssertEqual(Set(inappsThirdVariant.map { $0.id }), expectedIds2, "Идентификаторы инапов не совпадают с ожидаемыми")

        // Test case for UUID "d35df6c2-9e20-4f7e-9e20-51894e2c4810"
        persistenceStorage.deviceUUID = "d35df6c2-9e20-4f7e-9e20-51894e2c4810"
        let inappsFourthVariant = inappFilter.filterInappsByABTests(abTests, responseInapps: filteredInapps)
        let expectedIds3: Set = [
            "1",
            "2",
            "3"
        ]
        XCTAssertEqual(inappsFourthVariant.count, expectedIds3.count, "Количество инапов не совпадает с ожидаемым")
        XCTAssertEqual(Set(inappsFourthVariant.map { $0.id }), expectedIds3, "Идентификаторы инапов не совпадают с ожидаемыми")
    }

    func test_concrete_inapps_and_all() throws {
        let response = try InappConfig.configWithABTest.getConfig()
        let filteredInapps = filterValidInAppMessages(response.inapps?.elements ?? [])

        let abTests: [ABTest]? = [
            stub.getABTest(
                variants: [
                    stub.getVariantConcrete(lower: 0, upper: 35, inapps: [
                        "1",
                        "3"
                    ]),
                    stub.getVariantAll(lower: 35, upper: 100)
                ]
            )
        ]

        // Test case for UUID "4078E211-7C3F-C607-D35C-DC6B591EF355"
        persistenceStorage.deviceUUID = "4078E211-7C3F-C607-D35C-DC6B591EF355"
        let inappsFirstVariant = inappFilter.filterInappsByABTests(abTests, responseInapps: filteredInapps)
        let expectedIds1: Set = [
            "1",
            "3"
        ]
        XCTAssertEqual(inappsFirstVariant.count, expectedIds1.count, "Количество инапов не совпадает с ожидаемым")
        XCTAssertEqual(Set(inappsFirstVariant.map { $0.id }), expectedIds1, "Идентификаторы инапов не совпадают с ожидаемыми")

        // Test case for UUID "4D27710A-3F3A-FF6E-7764-375B1E06E05D"
        persistenceStorage.deviceUUID = "4D27710A-3F3A-FF6E-7764-375B1E06E05D"
        let inappsSecondVariant = inappFilter.filterInappsByABTests(abTests, responseInapps: filteredInapps)
        let expectedIds2: Set = [
            "1",
            "2",
            "3"
        ]
        XCTAssertEqual(inappsSecondVariant.count, expectedIds2.count, "Количество инапов не совпадает с ожидаемым")
        XCTAssertEqual(Set(inappsSecondVariant.map { $0.id }), expectedIds2, "Идентификаторы инапов не совпадают с ожидаемыми")
    }

    func test_abtests_broken_range_should_return_nil() throws {
        let response = try InappConfig.configWithABBrokenRange.getConfig() // Отсутствует диапазон 33-66
        XCTAssertNil(response.abtests, "AB-тесты с нарушенным диапазоном должны возвращать nil")
    }

    func test_abtests_missing_salt_should_return_nil() throws {
        let response = try InappConfig.configWithABNoSalt.getConfig() // Отсутствует соль
        XCTAssertNil(response.abtests, "AB-тесты без соли должны возвращать nil")
    }

    func test_abtests_unexpected_key_value_should_return_nil() throws {
        let response = try InappConfig.configWithABUnexpectedValue.getConfig() // Неожиданное ключ-значение
        XCTAssertNil(response.abtests, "AB-тесты с неожиданным ключом/значением должны возвращать nil")
    }

    func test_abtests_cross_range_should_return_nil() throws {
        let response = try InappConfig.configWithABCrossRange.getConfig() // Пересечение диапазонов
        XCTAssertNil(response.abtests, "AB-тесты с пересечением диапазонов должны возвращать nil")
    }

    func test_abtests_missing_upper_key_should_return_nil() throws {
        let response = try InappConfig.configWithABNoUpper.getConfig() // Отсутствует ключ upper
        XCTAssertNil(response.abtests, "AB-тесты без ключа upper должны возвращать nil")
    }

    func test_abtests_lower_bigger_than_upper_should_return_nil() throws {
        let response = try InappConfig.configWithABLowerBiggerThanUpper.getConfig() // Lower больше, чем Upper
        XCTAssertNil(response.abtests, "AB-тесты, где lower больше upper, должны возвращать nil")
    }

    func test_abtests_sdk_version_lower_than_required_should_return_nil() throws {
        let response = try InappConfig.configWithABNormal.getConfig()
        XCTAssertNil(response.abtests, "AB-тесты с минимальной SDK-версией, превышающей текущую, должны возвращать nil")
    }

    func test_abtests_type_not_inapps_should_return_nil() throws {
        let response = try InappConfig.configWithABTypeNotInapps.getConfig()
        XCTAssertNil(response.abtests, "AB-тесты с типом, отличным от инапов, должны возвращать nil")
    }
}

private extension ABTests {
    func filterValidInAppMessages(_ inapps: [InAppDTO]) -> [InApp] {
        var filteredInapps: [InApp] = []
        for inapp in inapps {
            do {
                let variants = try variantsFilter.filter(inapp.form.variants)
                if !variants.isEmpty {
                    let formModel = InAppForm(variants: variants)
                    let inappModel = InApp(id: inapp.id,
                                           sdkVersion: inapp.sdkVersion,
                                           targeting: inapp.targeting,
                                           frequency: inapp.frequency,
                                           form: formModel)
                    filteredInapps.append(inappModel)
                }
            } catch {
            }
        }
        return filteredInapps
    }
}
