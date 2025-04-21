//
//  InappConfigurationDataFacadeTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 21.04.2025.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

final class MockSegmentationService: SegmentationServiceProtocol {
    var stubResponse: [InAppProductSegmentResponse.CustomerSegmentation]?
    
    private(set) var requestedProducts: ProductCategory?
    
    init(stubResponse: [InAppProductSegmentResponse.CustomerSegmentation]? = nil) {
        self.stubResponse = stubResponse
    }
    
    func checkSegmentationRequest(completion: @escaping ([SegmentationCheckResponse.CustomerSegmentation]?) -> Void) {
        completion(nil)
    }
    
    func checkProductSegmentationRequest(
        products: ProductCategory,
        completion: @escaping ([InAppProductSegmentResponse.CustomerSegmentation]?) -> Void
    ) {
        // Запоминаем, что нас вызвали с этой моделью
        requestedProducts = products
        
        // Возвращаем текущий stubResponse (можно менять до вызова в тесте)
        completion(stubResponse)
    }
}

final class InAppConfigurationDataFacadeTests: XCTestCase {
    var mockSegmentation: MockSegmentationService!
    var dataFacade: InAppConfigurationDataFacade!
    
    override func setUp() {
        super.setUp()
        mockSegmentation = MockSegmentationService()
        let targetingChecker = DI.injectOrFail(InAppTargetingCheckerProtocol.self)
        let imageService = DI.injectOrFail(ImageDownloadServiceProtocol.self)
        let tracker = DI.injectOrFail(InAppMessagesTracker.self)
        dataFacade = InAppConfigurationDataFacade(
            segmentationService: mockSegmentation,
            targetingChecker: targetingChecker,
            imageService: imageService,
            tracker: tracker
        )
    }
    
    override func tearDown() {
        dataFacade.targetingChecker.eraseCache()
        dataFacade = nil
        mockSegmentation = nil
        SessionTemporaryStorage.shared.erase()
        
        super.tearDown()
    }
    
    func test_skipFetch_whenEventNameMismatch() {
        SessionTemporaryStorage.shared.viewProductOperation = "App.ViewProduct".lowercased()
        let model = decodeInAppOperationJSONModel(from: """
            { "viewProduct": { "product": { "ids": { "website": "100" } } } }
        """
        )
        dataFacade.targetingChecker.event = ApplicationEvent(
            name: "Other.Event".lowercased(), model: model
        )
        mockSegmentation.stubResponse = [
            InAppProductSegmentResponse.CustomerSegmentation(
                ids: .init(externalId: "1"),
                segment: .init(ids: .init(externalId: "2"))
            )
        ]
        dataFacade.fetchProductSegmentationIfNeeded(products: model?.viewProduct?.product)
        XCTAssertNil(mockSegmentation.requestedProducts)
        XCTAssertTrue(dataFacade.targetingChecker.checkedProductSegmentations.isEmpty)
    }
    
    func test_skipFetch_whenProductsNilOrEmpty() {
        SessionTemporaryStorage.shared.viewProductOperation = "App.ViewProduct".lowercased()
        dataFacade.targetingChecker.event = ApplicationEvent(name: "App.ViewProduct", model: nil)
        dataFacade.fetchProductSegmentationIfNeeded(products: nil)
        XCTAssertNil(mockSegmentation.requestedProducts)
        XCTAssertTrue(dataFacade.targetingChecker.checkedProductSegmentations.isEmpty)
        
        let emptyProducts = ProductCategory(ids: [:])
        dataFacade.targetingChecker.event = ApplicationEvent(
            name: "App.ViewProduct", model: decodeInAppOperationJSONModel(from: "{ }")
        )
        dataFacade.fetchProductSegmentationIfNeeded(products: emptyProducts)
        XCTAssertNil(mockSegmentation.requestedProducts)
        XCTAssertTrue(dataFacade.targetingChecker.checkedProductSegmentations.isEmpty)
    }
    
    func test_skipFetch_whenAlreadyChecked() {
        let model = decodeInAppOperationJSONModel(from: """
            { "viewProduct": { "product": { "ids": { "website": "100" } } } }
        """
        )
        let products = model!.viewProduct!.product
        dataFacade.targetingChecker.event = ApplicationEvent(name: "App.ViewProduct", model: model)
        let firstKey = products.firstProduct!
        dataFacade.targetingChecker.checkedProductSegmentations[firstKey] = [
            InAppProductSegmentResponse.CustomerSegmentation(
                ids: .init(externalId: "old"),
                segment: .init(ids: .init(externalId: "x"))
            )
        ]
        dataFacade.fetchProductSegmentationIfNeeded(products: products)
        XCTAssertNil(mockSegmentation.requestedProducts)
        XCTAssertEqual(
            dataFacade.targetingChecker.checkedProductSegmentations[firstKey]?.first?.ids.externalId,
            "old"
        )
    }
    
    func test_storeSegments_whenServiceReturnsData() {
        SessionTemporaryStorage.shared.viewProductOperation = "App.ViewProduct".lowercased()
        let model = decodeInAppOperationJSONModel(from: """
            { "viewProduct": { "product": { "ids": { "website": "100" } } } }
        """
        )
        let products = model!.viewProduct!.product
        dataFacade.targetingChecker.event = ApplicationEvent(name: "App.ViewProduct", model: model)
        let expectedSegments = [
            InAppProductSegmentResponse.CustomerSegmentation(
                ids: .init(externalId: "1"),
                segment: .init(ids: .init(externalId: "2"))
            )
        ]
        mockSegmentation.stubResponse = expectedSegments
        dataFacade.fetchProductSegmentationIfNeeded(products: products)
        XCTAssertEqual(mockSegmentation.requestedProducts, products)
        let key = products.firstProduct!
        XCTAssertEqual(dataFacade.targetingChecker.checkedProductSegmentations[key], expectedSegments)
    }
    
    func test_skipStore_whenServiceReturnsNil() {
        SessionTemporaryStorage.shared.viewProductOperation = "App.ViewProduct".lowercased()
        let model = decodeInAppOperationJSONModel(from: """
            { "viewProduct": { "product": { "ids": { "website": "100" } } } }
        """
        )
        let products = model!.viewProduct!.product
        dataFacade.targetingChecker.event = ApplicationEvent(name: "App.ViewProduct", model: model)
        mockSegmentation.stubResponse = nil
        dataFacade.fetchProductSegmentationIfNeeded(products: products)
        XCTAssertEqual(mockSegmentation.requestedProducts, products)
        XCTAssertNil(dataFacade.targetingChecker.checkedProductSegmentations[products.firstProduct!])
    }
    
    private func decodeInAppOperationJSONModel(from jsonString: String) -> InappOperationJSONModel? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(InappOperationJSONModel.self, from: data)
    }
}
