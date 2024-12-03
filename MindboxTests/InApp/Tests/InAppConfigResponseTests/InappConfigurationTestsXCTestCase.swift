//
//  InappConfigurationTestsXCTestCase.swift
//  MindboxTests
//
//  Created by vailence on 03.12.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
import XCTest
@testable import Mindbox

fileprivate enum InappConfig: String, Configurable {
    typealias DecodeType = ConfigResponse

    case configWithTwoInapps = "InAppConfiguration"
    case configWithOperationInapp = "InAppConfigurationWithOperations"
}

// TODO: - Удалить тесты когда Github Actions станут поддерживать Swift Testing. Замена - InappConfigurationTests

final class InappConfigurationTestsXCTestCase: XCTestCase {

    private var mapper: InappMapperProtocol!
    private var targetingChecker: InAppTargetingCheckerProtocol!
    private var stub: InAppConfigStub!

    override func setUp() {
        super.setUp()
        TestConfiguration.configure()
        self.mapper = DI.injectOrFail(InappMapperProtocol.self)
        self.targetingChecker = DI.injectOrFail(InAppTargetingCheckerProtocol.self)
        self.stub = InAppConfigStub()
    }

    // Первый инапп не подходит по версии SDK.
    @available(iOS 13.0, *)
    func testFirstInappDoesntFitSDKReturnsSecond() async throws {
        let response = try InappConfig.configWithTwoInapps.getConfig()

        let sdkValidator = DI.injectOrFail(SDKVersionValidator.self)
        sdkValidator.sdkVersionNumeric = 9
        let result = await withCheckedContinuation { continuation in
            mapper.handleInapps(nil, response) { formData in
                continuation.resume(returning: formData)
            }
        }

        XCTAssertEqual(result?.inAppId, "2")
    }

    // Оба инаппа подходят по версии SDK.
    @available(iOS 13.0, *)
    func testFirstInappFitsSDKReturnsFirst() async throws {
        let response = try InappConfig.configWithTwoInapps.getConfig()

        let sdkValidator = DI.injectOrFail(SDKVersionValidator.self)
        sdkValidator.sdkVersionNumeric = 5
        let result = await withCheckedContinuation { continuation in
            mapper.handleInapps(nil, response) { formData in
                continuation.resume(returning: formData)
            }
        }

        XCTAssertEqual(result?.inAppId, "1")
    }

    // Оба инаппа не подходят по версии SDK.
    @available(iOS 13.0, *)
    func testBothInappsDontFitSDKReturnsNil() async throws {
        let response = try InappConfig.configWithTwoInapps.getConfig()

        let sdkValidator = DI.injectOrFail(SDKVersionValidator.self)
        sdkValidator.sdkVersionNumeric = 1
        let result = await withCheckedContinuation { continuation in
            mapper.handleInapps(nil, response) { formData in
                continuation.resume(returning: formData)
            }
        }

        XCTAssertNil(result)
    }

    // Пустое имя кастомной операции.
    @available(iOS 13.0, *)
    func testOperationEmptyOperationName() async throws {
        let response = try InappConfig.configWithOperationInapp.getConfig()
        let event = ApplicationEvent(name: "", model: nil)
        let result = await withCheckedContinuation { continuation in
            mapper.handleInapps(event, response) { formData in
                continuation.resume(returning: formData)
            }
        }

        XCTAssertNil(result)
    }

    // Правильное имя кастомной операции.
    @available(iOS 13.0, *)
    func testOperationRightOperationName() async throws {
        let response = try InappConfig.configWithOperationInapp.getConfig()
        let event = ApplicationEvent(name: "test", model: nil)
        let result = await withCheckedContinuation { continuation in
            mapper.handleInapps(event, response) { formData in
                continuation.resume(returning: formData)
            }
        }

        XCTAssertEqual(result?.inAppId, "1")
    }

    // Пример тестов с viewCategory.
    @available(iOS 13.0, *)
    func testCategoryIDEmptyModelReturnsNil() async throws {
        let response = try stub.getCategoryID_Substring()
        let event = ApplicationEvent(name: "viewCategory", model: nil)

        let result = await withCheckedContinuation { continuation in
            mapper.handleInapps(event, response) { formData in
                continuation.resume(returning: formData)
            }
        }

        XCTAssertNil(result)
    }

    @available(iOS 13.0, *)
    func testCategoryIDSubstringTrue() async throws {
        let response = try stub.getCategoryID_Substring()
        let event = ApplicationEvent(name: "viewCategory", model: .init(viewProductCategory: .init(productCategory: .init(ids: [
            "System1C": "Boots".uppercased(),
            "TestSite": "81".uppercased()
        ]))))

        let result = await withCheckedContinuation { continuation in
            mapper.handleInapps(event, response) { formData in
                continuation.resume(returning: formData)
            }
        }

        XCTAssertEqual(result?.inAppId, "1")
    }

    @available(iOS 13.0, *)
    func testProductIDSubstringTrue() async throws {
        let response = try stub.getProductID_substring()
        let event = ApplicationEvent(name: "viewProduct", model: .init(viewProduct: .init(product: .init(ids: [
            "website": "Boots".uppercased(),
            "system1c": "81".uppercased()
        ]))))

        let result = await withCheckedContinuation { continuation in
            mapper.handleInapps(event, response) { formData in
                continuation.resume(returning: formData)
            }
        }

        XCTAssertEqual(result?.inAppId, "1")
    }

    @available(iOS 13.0, *)
    func testProductSegmentPositiveTrue() async throws {
        let response = try stub.getProductSegment_Positive()
        let event = ApplicationEvent(name: "viewProduct", model: .init(viewProduct: .init(product: .init(ids: [
            "website": "49"
        ]))))

        let productSegments = InAppProductSegmentResponse(status: .success, products: [
            .init(ids: ["website": "49"],
                  segmentations: [
                    .init(ids: .init(externalId: "1"),
                          segment: .init(ids: .init(externalId: "3")))
                  ])
        ])

        self.targetingChecker.checkedProductSegmentations = productSegments.products?.first?.segmentations

        let result = await withCheckedContinuation { continuation in
            mapper.handleInapps(event, response) { formData in
                continuation.resume(returning: formData)
            }
        }

        XCTAssertEqual(result?.inAppId, "1")
    }

    @available(iOS 13.0, *)
    func testProductSegmentNegativeTrue() async throws {
        let response = try stub.getProductSegment_Negative()
        let event = ApplicationEvent(name: "viewProduct", model: .init(viewProduct: .init(product: .init(ids: [
            "website": "49"
        ]))))

        let segmentation = [InAppProductSegmentResponse.CustomerSegmentation(ids: .init(externalId: "1"),
                                                                             segment: .init(ids: .init(externalId: "4")))]
        self.targetingChecker.checkedProductSegmentations = segmentation

        let result = await withCheckedContinuation { continuation in
            mapper.handleInapps(event, response) { formData in
                continuation.resume(returning: formData)
            }
        }

        XCTAssertEqual(result?.inAppId, "1")
    }
}
