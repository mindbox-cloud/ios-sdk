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
    var stubError: MindboxError?
    
    private(set) var requestedProducts: ProductCategory?
    
    init(stubResponse: [InAppProductSegmentResponse.CustomerSegmentation]? = nil) {
        self.stubResponse = stubResponse
    }
    
    func checkSegmentationRequest(
        completion: @escaping (Result<[SegmentationCheckResponse.CustomerSegmentation]?, MindboxError>) -> Void
    ) {
        if let stubError {
            completion(.failure(stubError))
            return
        }
        completion(.success(nil))
    }
    
    func checkProductSegmentationRequest(
        products: ProductCategory,
        completion: @escaping (Result<[InAppProductSegmentResponse.CustomerSegmentation]?, MindboxError>) -> Void
    ) {
        requestedProducts = products
        if let stubError {
            completion(.failure(stubError))
            return
        }
        completion(.success(stubResponse))
    }
}

final class MockInappShowFailureManager: InappShowFailureManagerProtocol {
    private(set) var failures: [(inappId: String, reason: InAppShowFailureReason, details: String?)] = []

    func addFailure(inappId: String, reason: InAppShowFailureReason, details: String?) {
        failures.append((inappId: inappId, reason: reason, details: details))
    }

    func clearFailures() {
        failures.removeAll()
    }

    func sendFailures() {}
}

final class InAppConfigurationDataFacadeTests: XCTestCase {
    var mockSegmentation: MockSegmentationService!
    var mockFailureManager: MockInappShowFailureManager!
    var dataFacade: InAppConfigurationDataFacade!
    
    override func setUp() {
        super.setUp()
        mockSegmentation = MockSegmentationService()
        mockFailureManager = MockInappShowFailureManager()
        let targetingChecker = DI.injectOrFail(InAppTargetingCheckerProtocol.self)
        let imageService = DI.injectOrFail(ImageDownloadServiceProtocol.self)
        let tracker = DI.injectOrFail(InAppMessagesTracker.self)
        dataFacade = InAppConfigurationDataFacade(
            segmentationService: mockSegmentation,
            targetingChecker: targetingChecker,
            imageService: imageService,
            tracker: tracker,
            failureManager: mockFailureManager
        )
    }
    
    override func tearDown() {
        dataFacade.targetingChecker.eraseCache()
        (DI.inject(NetworkFetcher.self) as? MockNetworkFetcher)?.error = nil
        dataFacade = nil
        mockSegmentation = nil
        mockFailureManager = nil
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

    func test_addFailure_whenProductSegmentationReturnsServerError() {
        SessionTemporaryStorage.shared.viewProductOperation = "App.ViewProduct".lowercased()
        let model = decodeInAppOperationJSONModel(from: """
            { "viewProduct": { "product": { "ids": { "website": "100" } } } }
        """
        )
        let products = model!.viewProduct!.product
        dataFacade.targetingChecker.event = ApplicationEvent(name: "App.ViewProduct", model: model)
        dataFacade.targetingChecker.context.productSegmentInapps = ["inapp-1", "inapp-2"]
        mockSegmentation.stubError = .serverError(.init(status: .internalServerError, errorMessage: "Internal Server error", httpStatusCode: 500))

        dataFacade.fetchProductSegmentationIfNeeded(products: products)

        XCTAssertEqual(mockFailureManager.failures.count, 2)
        XCTAssertEqual(Set(mockFailureManager.failures.map { $0.inappId }), Set(["inapp-1", "inapp-2"]))
        XCTAssertTrue(mockFailureManager.failures.allSatisfy { $0.reason == .productSegmentRequestFailed })
    }

    func test_doNotAddFailure_whenProductSegmentationReturnsNonServerError() {
        SessionTemporaryStorage.shared.viewProductOperation = "App.ViewProduct".lowercased()
        let model = decodeInAppOperationJSONModel(from: """
            { "viewProduct": { "product": { "ids": { "website": "100" } } } }
        """
        )
        let products = model!.viewProduct!.product
        dataFacade.targetingChecker.event = ApplicationEvent(name: "App.ViewProduct", model: model)
        dataFacade.targetingChecker.context.productSegmentInapps = ["inapp-1"]
        mockSegmentation.stubError = .protocolError(.init(status: .protocolError, errorMessage: "Bad request", httpStatusCode: 400))

        dataFacade.fetchProductSegmentationIfNeeded(products: products)

        XCTAssertTrue(mockFailureManager.failures.isEmpty)
    }

    func test_addFailure_whenSegmentationReturnsServerError() {
        dataFacade.targetingChecker.context.segmentInapps = ["inapp-segment-1", "inapp-segment-2"]
        dataFacade.targetingChecker.context.segments = ["segment-id"]
        mockSegmentation.stubError = .serverError(.init(status: .internalServerError, errorMessage: "Internal Server error", httpStatusCode: 500))
        let expectation = expectation(description: "fetch dependencies")

        dataFacade.fetchDependencies(model: nil) {
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1)

        XCTAssertEqual(mockFailureManager.failures.count, 2)
        XCTAssertEqual(Set(mockFailureManager.failures.map { $0.inappId }), Set(["inapp-segment-1", "inapp-segment-2"]))
        XCTAssertTrue(mockFailureManager.failures.allSatisfy { $0.reason == .customerSegmentRequestFailed })
    }

    func test_addFailure_whenGeoReturnsServerError() {
        let networkFetcher = DI.injectOrFail(NetworkFetcher.self) as? MockNetworkFetcher
        networkFetcher?.error = .serverError(.init(status: .internalServerError, errorMessage: "Internal Server error", httpStatusCode: 500))
        dataFacade.targetingChecker.context.geoInapps = ["inapp-geo"]
        dataFacade.targetingChecker.context.isNeedGeoRequest = true
        let expectation = expectation(description: "fetch dependencies")

        dataFacade.fetchDependencies(model: nil) {
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1)

        XCTAssertEqual(mockFailureManager.failures.count, 1)
        XCTAssertEqual(mockFailureManager.failures.first?.inappId, "inapp-geo")
        XCTAssertEqual(mockFailureManager.failures.first?.reason, .geoTargetingFailed)
    }

    func test_addFailure_whenGeoRequestFailedBefore_returnsCachedFailureOnNextFetch() {
        let networkFetcher = DI.injectOrFail(NetworkFetcher.self) as? MockNetworkFetcher
        networkFetcher?.error = .serverError(.init(status: .internalServerError, errorMessage: "Internal Server error", httpStatusCode: 500))
        dataFacade.targetingChecker.context.geoInapps = ["inapp-geo"]
        dataFacade.targetingChecker.context.isNeedGeoRequest = true

        let firstExpectation = expectation(description: "first fetch dependencies")
        dataFacade.fetchDependencies(model: nil) {
            firstExpectation.fulfill()
        }
        waitForExpectations(timeout: 1)

        networkFetcher?.error = nil
        let secondExpectation = expectation(description: "second fetch dependencies")
        dataFacade.fetchDependencies(model: nil) {
            secondExpectation.fulfill()
        }
        waitForExpectations(timeout: 1)

        XCTAssertEqual(mockFailureManager.failures.count, 2)
        XCTAssertTrue(mockFailureManager.failures.allSatisfy { $0.reason == .geoTargetingFailed })
        XCTAssertEqual(mockFailureManager.failures.map { $0.inappId }, ["inapp-geo", "inapp-geo"])
    }
    
    private func decodeInAppOperationJSONModel(from jsonString: String) -> InappOperationJSONModel? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(InappOperationJSONModel.self, from: data)
    }
}
