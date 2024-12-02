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

@Suite("Inapp Mapper Tests")
class InappConfigurationTests {

    private var mapper: InappMapperProtocol
    private var targetingChecker: InAppTargetingCheckerProtocol

    init() {
        TestConfiguration.configure()
        self.mapper = DI.injectOrFail(InappMapperProtocol.self)
        self.targetingChecker = DI.injectOrFail(InAppTargetingCheckerProtocol.self)
    }

    @available(iOS 13.0, *)
    @Test("Первый инапп не подходит по версии SDK.", .tags(.sdkVersion))
    func first_inapp_doesnt_fit_sdk_return_second() async throws {
        let response = try InappConfig.configWithTwoInapps.getConfig()

        let sdkValidator = DI.injectOrFail(SDKVersionValidator.self)
        sdkValidator.sdkVersionNumeric = 9
        let result = await withCheckedContinuation { continuation in
            mapper.handleInapps(nil, response) { formData in
                continuation.resume(returning: formData)
            }
        }

        #expect(result?.inAppId == "2")
    }

    @available(iOS 13.0, *)
    @Test("Оба инаппа подходят по версии SDK.", .tags(.sdkVersion))
    func first_inapp_fit_sdk_return_first() async throws {
        let response = try InappConfig.configWithTwoInapps.getConfig()

        let sdkValidator = DI.injectOrFail(SDKVersionValidator.self)
        sdkValidator.sdkVersionNumeric = 5
        let result = await withCheckedContinuation { continuation in
            mapper.handleInapps(nil, response) { formData in
                continuation.resume(returning: formData)
            }
        }

        #expect(result?.inAppId == "1")
    }

    @available(iOS 13.0, *)
    @Test("Оба инаппа не подходят по версии SDK.", .tags(.sdkVersion))
    func both_inapps_doesnt_fit_sdk_return_nil() async throws {
        let response = try InappConfig.configWithTwoInapps.getConfig()

        let sdkValidator = DI.injectOrFail(SDKVersionValidator.self)
        sdkValidator.sdkVersionNumeric = 1
        let result = await withCheckedContinuation { continuation in
            mapper.handleInapps(nil, response) { formData in
                continuation.resume(returning: formData)
            }
        }

        #expect(result == nil)
    }

    @available(iOS 13.0, *)
    @Test("Пустое имя кастомной операции", .tags(.customOperations))
    func operation_empty_operatonName() async throws {
        let response = try InappConfig.configWithOperationInapp.getConfig()
        let event = ApplicationEvent(name: "", model: nil)
        let result = await withCheckedContinuation { continuation in
            mapper.handleInapps(event, response) { formData in
                continuation.resume(returning: formData)
            }
        }

        #expect(result == nil)
    }

    @available(iOS 13.0, *)
    @Test("Неправильное имя кастомной операции", .tags(.customOperations))
    func operation_wrong_operatonName() async throws {
        let response = try InappConfig.configWithOperationInapp.getConfig()
        let event = ApplicationEvent(name: "hello", model: nil)
        let result = await withCheckedContinuation { continuation in
            mapper.handleInapps(event, response) { formData in
                continuation.resume(returning: formData)
            }
        }

        #expect(result == nil)
    }

    @available(iOS 13.0, *)
    @Test("Правильное имя кастомной операции", .tags(.customOperations))
    func operation_right_operatonName() async throws {
        let response = try InappConfig.configWithOperationInapp.getConfig()
        let event = ApplicationEvent(name: "test", model: nil)
        let result = await withCheckedContinuation { continuation in
            mapper.handleInapps(event, response) { formData in
                continuation.resume(returning: formData)
            }
        }

        #expect(result?.inAppId == "1")
    }

    @available(iOS 13.0, *)
    @Test("Пустая модель в viewCategory", .tags(.categoryID))
    func categoryID_emptyModel_returnNil() async throws {
        let stub = InAppConfigStub()
        let response = try stub.getCategoryID_Substring()
        let event = ApplicationEvent(name: "viewCategory",
                                     model: nil)

        let result = await withCheckedContinuation { continuation in
            mapper.handleInapps(event, response) { formData in
                continuation.resume(returning: formData)
            }
        }

        #expect(result == nil)
    }

    @available(iOS 13.0, *)
    @Test("1.Правильный substring категории", .tags(.categoryID))
    func categoryID_substring_true() async throws {
        let stub = InAppConfigStub()
        let response = try stub.getCategoryID_Substring()
        let event = ApplicationEvent(name: "viewCategory",
                                     model: .init(viewProductCategory: .init(productCategory: .init(ids: [
                                        "System1C": "Boots".uppercased(),
                                        "TestSite": "81".uppercased()
                                     ]))))

        let result = await withCheckedContinuation { continuation in
            mapper.handleInapps(event, response) { formData in
                continuation.resume(returning: formData)
            }
        }

        #expect(result?.inAppId == "1")
    }

    @available(iOS 13.0, *)
    @Test("1.Неправильный substring категории", .tags(.categoryID))
    func categoryID_substring_false() async throws {
        let stub = InAppConfigStub()
        let response = try stub.getCategoryID_Substring()
        let event = ApplicationEvent(name: "viewCategory",
                                     model: .init(viewProductCategory: .init(productCategory: .init(ids: [
                                        "System1C": "Bovts".uppercased(),
                                        "TestSite": "81".uppercased()
                                     ]))))

        let result = await withCheckedContinuation { continuation in
            mapper.handleInapps(event, response) { formData in
                continuation.resume(returning: formData)
            }
        }

        #expect(result == nil)
    }

    @available(iOS 13.0, *)
    @Test("2.Правильный notSubstring категории", .tags(.categoryID))
    func categoryID_notSubstring_true() async throws {
        let stub = InAppConfigStub()
        let response = try stub.getCategoryID_notSubstring()
        let event = ApplicationEvent(name: "viewCategory",
                                     model: .init(viewProductCategory: .init(productCategory: .init(ids: [
                                        "System1C": "Boots".uppercased(),
                                        "TestSite": "Button".uppercased()
                                     ]))))

        let result = await withCheckedContinuation { continuation in
            mapper.handleInapps(event, response) { formData in
                continuation.resume(returning: formData)
            }
        }

        #expect(result?.inAppId == "1")
    }

    @available(iOS 13.0, *)
    @Test("2.Неправильный notSubstring категории", .tags(.categoryID))
    func categoryID_notSubstring_false() async throws {
        let stub = InAppConfigStub()
        let response = try stub.getCategoryID_notSubstring()
        let event = ApplicationEvent(name: "viewCategory",
                                     model: .init(viewProductCategory: .init(productCategory: .init(ids: [
                                        "System1C": "Boots".uppercased(),
                                        "TestSite": "Buttootn".uppercased()
                                     ]))))

        let result = await withCheckedContinuation { continuation in
            mapper.handleInapps(event, response) { formData in
                continuation.resume(returning: formData)
            }
        }

        #expect(result == nil)
    }

    @available(iOS 13.0, *)
    @Test("3.Правильный startWith категории", .tags(.categoryID))
    func categoryID_startWith_true() async throws {
        let stub = InAppConfigStub()
        let response = try stub.getCategoryID_startWith()
        let event = ApplicationEvent(name: "viewCategory",
                                     model: .init(viewProductCategory: .init(productCategory: .init(ids: [
                                        "System1C": "oots".uppercased(),
                                        "TestSite": "Button".uppercased()
                                     ]))))

        let result = await withCheckedContinuation { continuation in
            mapper.handleInapps(event, response) { formData in
                continuation.resume(returning: formData)
            }
        }

        #expect(result?.inAppId == "1")
    }

    @available(iOS 13.0, *)
    @Test("3.Неправильный startWith категории", .tags(.categoryID))
    func categoryID_startWith_false() async throws {
        let stub = InAppConfigStub()
        let response = try stub.getCategoryID_startWith()
        let event = ApplicationEvent(name: "viewCategory",
                                     model: .init(viewProductCategory: .init(productCategory: .init(ids: [
                                        "System1C": "Boots".uppercased(),
                                        "TestSite": "Button".uppercased()
                                     ]))))

        let result = await withCheckedContinuation { continuation in
            mapper.handleInapps(event, response) { formData in
                continuation.resume(returning: formData)
            }
        }

        #expect(result == nil)
    }

    @available(iOS 13.0, *)
    @Test("4.Правильный endWith категории", .tags(.categoryID))
    func categoryID_endWith_true() async throws {
        let stub = InAppConfigStub()
        let response = try stub.getCategoryID_endWith()
        let event = ApplicationEvent(name: "viewCategory",
                                     model: .init(viewProductCategory: .init(productCategory: .init(ids: [
                                        "System1C": "Boots".uppercased(),
                                        "TestSite": "Button".uppercased()
                                     ]))))

        let result = await withCheckedContinuation { continuation in
            mapper.handleInapps(event, response) { formData in
                continuation.resume(returning: formData)
            }
        }

        #expect(result?.inAppId == "1")
    }

    @available(iOS 13.0, *)
    @Test("4.Неправильный endWith категории", .tags(.categoryID))
    func categoryID_endWith_false() async throws {
        let stub = InAppConfigStub()
        let response = try stub.getCategoryID_endWith()
        let event = ApplicationEvent(name: "viewCategory",
                                     model: .init(viewProductCategory: .init(productCategory: .init(ids: [
                                        "System1C": "Boats".uppercased(),
                                        "TestSite": "Button".uppercased()
                                     ]))))

        let result = await withCheckedContinuation { continuation in
            mapper.handleInapps(event, response) { formData in
                continuation.resume(returning: formData)
            }
        }

        #expect(result == nil)
    }

    @available(iOS 13.0, *)
    @Test("1.Правильная categoryID_In any", .tags(.categoryID_In))
    func categoryID_In_any_true() async throws {
        let stub = InAppConfigStub()
        let response = try stub.getCategoryIDIn_Any()
        let event = ApplicationEvent(name: "viewCategory",
                                     model: .init(viewProductCategory: .init(productCategory: .init(ids: [
                                        "System1C": "testik2"]))))

        let result = await withCheckedContinuation { continuation in
            mapper.handleInapps(event, response) { formData in
                continuation.resume(returning: formData)
            }
        }

        #expect(result?.inAppId == "1")
    }

    @available(iOS 13.0, *)
    @Test("1.Неправильная categoryID_In any", .tags(.categoryID_In))
    func categoryID_In_any_false() async throws {
        let stub = InAppConfigStub()
        let response = try stub.getCategoryIDIn_Any()
        let event = ApplicationEvent(name: "viewCategory",
                                     model: .init(viewProductCategory: .init(productCategory: .init(ids: [
            "System1C": "potato"]))))

        let result = await withCheckedContinuation { continuation in
            mapper.handleInapps(event, response) { formData in
                continuation.resume(returning: formData)
            }
        }

        #expect(result == nil)
    }

    @available(iOS 13.0, *)
    @Test("2.Правильная categoryID_In none", .tags(.categoryID_In))
    func categoryID_In_none_true() async throws {
        let stub = InAppConfigStub()
        let response = try stub.getCategoryIDIn_None()
        let event = ApplicationEvent(name: "viewCategory",
                                     model: .init(viewProductCategory: .init(productCategory: .init(ids: [
                                        "System1C": "potato"]))))

        let result = await withCheckedContinuation { continuation in
            mapper.handleInapps(event, response) { formData in
                continuation.resume(returning: formData)
            }
        }

        #expect(result?.inAppId == "1")
    }

    @available(iOS 13.0, *)
    @Test("2.Неправильная categoryID_In none", .tags(.categoryID_In))
    func categoryID_In_none_false() async throws {
        let stub = InAppConfigStub()
        let response = try stub.getCategoryIDIn_None()
        let event = ApplicationEvent(name: "viewCategory",
                                     model: .init(viewProductCategory: .init(productCategory: .init(ids: [
                                        "System1C": "testik2"]))))

        let result = await withCheckedContinuation { continuation in
            mapper.handleInapps(event, response) { formData in
                continuation.resume(returning: formData)
            }
        }

        #expect(result == nil)
    }

    @available(iOS 13.0, *)
    @Test("Пустая модель productID", .tags(.productID))
    func productID_emptyModel_nil() async throws {
        let stub = InAppConfigStub()
        let response = try stub.getProductID_substring()
        let event = ApplicationEvent(name: "viewProduct", model: nil)

        let result = await withCheckedContinuation { continuation in
            mapper.handleInapps(event, response) { formData in
                continuation.resume(returning: formData)
            }
        }

        #expect(result == nil)
    }

    @available(iOS 13.0, *)
    @Test("1.Правильный productID substring", .tags(.productID))
    func productID_substring_true() async throws {
        let stub = InAppConfigStub()
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

        #expect(result?.inAppId == "1")
    }

    @available(iOS 13.0, *)
    @Test("1.Неправильный productID substring", .tags(.productID))
    func productID_substring_false() async throws {
        let stub = InAppConfigStub()
        let response = try stub.getProductID_substring()
        let event = ApplicationEvent(name: "viewProduct", model: .init(viewProduct: .init(product: .init(ids: [
            "website": "Bovts".uppercased(),
            "system1c": "81".uppercased()
        ]))))

        let result = await withCheckedContinuation { continuation in
            mapper.handleInapps(event, response) { formData in
                continuation.resume(returning: formData)
            }
        }

        #expect(result == nil)
    }

    @available(iOS 13.0, *)
    @Test("2.Правильный productID notSubstring", .tags(.productID))
    func productID_notSubstring_true() async throws {
        let stub = InAppConfigStub()
        let response = try stub.getProductID_notSubstring()
        let event = ApplicationEvent(name: "viewProduct", model: .init(viewProduct: .init(product: .init(ids: [
            "website": "Boots".uppercased(),
            "system1c": "81".uppercased()
        ]))))

        let result = await withCheckedContinuation { continuation in
            mapper.handleInapps(event, response) { formData in
                continuation.resume(returning: formData)
            }
        }

        #expect(result?.inAppId == "1")
    }

    @available(iOS 13.0, *)
    @Test("2.Неправильный productID notSubstring", .tags(.productID))
    func productID_notSubstring_false() async throws {
        let stub = InAppConfigStub()
        let response = try stub.getProductID_notSubstring()
        let event = ApplicationEvent(name: "viewProduct", model: .init(viewProduct: .init(product: .init(ids: [
            "website": "Boots".uppercased(),
            "system1c": "Buttootn".uppercased()
        ]))))

        let result = await withCheckedContinuation { continuation in
            mapper.handleInapps(event, response) { formData in
                continuation.resume(returning: formData)
            }
        }

        #expect(result == nil)
    }

    @available(iOS 13.0, *)
    @Test("3.Правильный productID startWith", .tags(.productID))
    func productID_startWith_true() async throws {
        let stub = InAppConfigStub()
        let response = try stub.getProductID_startWith()
        let event = ApplicationEvent(name: "viewProduct", model: .init(viewProduct: .init(product: .init(ids: [
            "website": "oots".uppercased(),
            "system1c": "Button".uppercased()
        ]))))

        let result = await withCheckedContinuation { continuation in
            mapper.handleInapps(event, response) { formData in
                continuation.resume(returning: formData)
            }
        }

        #expect(result?.inAppId == "1")
    }

    @available(iOS 13.0, *)
    @Test("3.Неправильный productID startWith", .tags(.productID))
    func productID_startWith_false() async throws {
        let stub = InAppConfigStub()
        let response = try stub.getProductID_startWith()
        let event = ApplicationEvent(name: "viewProduct", model: .init(viewProduct: .init(product: .init(ids: [
            "website": "Boots".uppercased(),
            "system1c": "Button".uppercased()
        ]))))

        let result = await withCheckedContinuation { continuation in
            mapper.handleInapps(event, response) { formData in
                continuation.resume(returning: formData)
            }
        }

        #expect(result == nil)
    }

    @available(iOS 13.0, *)
    @Test("4.Правильный productID endWith", .tags(.productID))
    func productID_endWith_true() async throws {
        let stub = InAppConfigStub()
        let response = try stub.getProductID_endWith()
        let event = ApplicationEvent(name: "viewProduct", model: .init(viewProduct: .init(product: .init(ids: [
            "website": "Boots".uppercased(),
            "system1c": "Button".uppercased()
        ]))))

        let result = await withCheckedContinuation { continuation in
            mapper.handleInapps(event, response) { formData in
                continuation.resume(returning: formData)
            }
        }

        #expect(result?.inAppId == "1")
    }

    @available(iOS 13.0, *)
    @Test("4.Неправильный productID endWith", .tags(.productID))
    func productID_endWith_false() async throws {
        let stub = InAppConfigStub()
        let response = try stub.getProductID_endWith()
        let event = ApplicationEvent(name: "viewProduct", model: .init(viewProduct: .init(product: .init(ids: [
            "website": "Boats".uppercased(),
            "system1c": "Button".uppercased()
        ]))))

        let result = await withCheckedContinuation { continuation in
            mapper.handleInapps(event, response) { formData in
                continuation.resume(returning: formData)
            }
        }

        #expect(result == nil)
    }

    @available(iOS 13.0, *)
    @Test("1.Правильный productSegment positive", .tags(.productSegment))
    func productSegment_positive_true() async throws {
        let stub = InAppConfigStub()
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

        #expect(result?.inAppId == "1")
    }

    @available(iOS 13.0, *)
    @Test("1.Неправильный productSegment positive", .tags(.productSegment))
    func productSegment_positive_false() async throws {
        let stub = InAppConfigStub()
        let response = try stub.getProductSegment_Positive()
        let event = ApplicationEvent(name: "viewProduct", model: .init(viewProduct: .init(product: .init(ids: [
            "website": "49"
        ]))))

        let result = await withCheckedContinuation { continuation in
            mapper.handleInapps(event, response) { formData in
                continuation.resume(returning: formData)
            }
        }

        #expect(result == nil)
    }

    @available(iOS 13.0, *)
    @Test("2.Неправильный productSegment negative", .tags(.productSegment))
    func productSegment_negative_true() async throws {
        let stub = InAppConfigStub()
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

        #expect(result?.inAppId == "1")
    }

    @available(iOS 13.0, *)
    @Test("2.Неправильный productSegment negative", .tags(.productSegment))
    func productSegment_negateive_false() async throws {
        let stub = InAppConfigStub()
        let response = try stub.getProductSegment_Negative()
        let event = ApplicationEvent(name: "viewProduct", model: .init(viewProduct: .init(product: .init(ids: [
            "website": "49"
        ]))))

        let result = await withCheckedContinuation { continuation in
            mapper.handleInapps(event, response) { formData in
                continuation.resume(returning: formData)
            }
        }

        #expect(result == nil)
    }
}
