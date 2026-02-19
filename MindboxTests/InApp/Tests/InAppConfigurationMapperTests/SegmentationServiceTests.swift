//
//  SegmentationServiceTests.swift
//  MindboxTests
//
//  Created by vailence on 14.06.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

final class SegmentationServiceTests: XCTestCase {

    var sut: SegmentationService!
    var targetingChecker: InAppTargetingCheckerProtocol!

    override func setUp() {
        super.setUp()
        targetingChecker = DI.injectOrFail(InAppTargetingCheckerProtocol.self)

        sut = DI.injectOrFail(SegmentationServiceProtocol.self) as? SegmentationService
        let customerSegmentAPI = CustomerSegmentsAPI { _, completion in
            completion(.success(.init(status: .success, customerSegmentations: [.init(segmentation: .init(ids: .init(externalId: "1")),
                                                                                      segment: .init(ids: .init(externalId: "2")))])))
        } fetchProductSegments: { _, completion in
            completion(.success(.init(status: .success, products: [.init(ids: ["Hello": "World"],
                                                                         segmentations: [.init(ids: .init(externalId: "123"),
                                                                                               segment: .init(ids: .init(externalId: "456")))])])))
        }

        sut.customerSegmentsAPI = customerSegmentAPI
    }

    override func tearDown() {
        SessionTemporaryStorage.shared.erase()
        targetingChecker = nil
        sut = nil
        super.tearDown()
    }

    func test_checkSegmentation_requestCompleted() throws {
        targetingChecker.checkedSegmentations = [.init(segmentation: .init(ids: .init(externalId: "Completed")),
                                                       segment: .init(ids: .init(externalId: "Completed")))]

        SessionTemporaryStorage.shared.checkSegmentsRequestCompleted = true

        let expectations = expectation(description: "test_checkSegmentation_requestCompleted")
        var result: [SegmentationCheckResponse.CustomerSegmentation]?
        sut.checkSegmentationRequest { response in
            if case .success(let segmentations) = response {
                result = segmentations
            }
            expectations.fulfill()
        }

        let expectedModel: [SegmentationCheckResponse.CustomerSegmentation] = [.init(segmentation: .init(ids: .init(externalId: "Completed")),
                                                                                     segment: .init(ids: .init(externalId: "Completed")))]

        waitForExpectations(timeout: 1)

        XCTAssertEqual(result, expectedModel)
    }

    func test_checkSegmentation_segmentsEmpty_returnNil() throws {
        var result: [SegmentationCheckResponse.CustomerSegmentation]?
        let expectations = expectation(description: "test_checkSegmentation_segmentsEmpty_returnNil")
        sut.checkSegmentationRequest { response in
            if case .success(let segmentations) = response {
                result = segmentations
            }
            expectations.fulfill()
        }

        waitForExpectations(timeout: 1)

        XCTAssertNil(result)
    }

    func test_checkSegmentation_request_valid() throws {
        let expectedModel: [SegmentationCheckResponse.CustomerSegmentation] = [.init(segmentation: .init(ids: .init(externalId: "1")),
                                                                                     segment: .init(ids: .init(externalId: "2")))]

        var result: [SegmentationCheckResponse.CustomerSegmentation]?
        targetingChecker.context.segments.append("123")
        let expectations = expectation(description: "test_checkSegmentation_request_valid")

        sut.checkSegmentationRequest { response in
            if case .success(let segmentations) = response {
                result = segmentations
            }
            expectations.fulfill()
        }

        waitForExpectations(timeout: 1)

        XCTAssertEqual(result, expectedModel)
    }

    func test_checkProductSegmentation_isPresentingInAppMessage() throws {
        SessionTemporaryStorage.shared.isPresentingInAppMessage = true
        let expectations = expectation(description: "test_checkProductSegmentation_isPresentingInAppMessage")
        var result: [InAppProductSegmentResponse.CustomerSegmentation]?
        sut.checkProductSegmentationRequest(products: .init(ids: ["Hello": "World"])) { response in
            if case .success(let segmentations) = response {
                result = segmentations
            }
            expectations.fulfill()
        }

        waitForExpectations(timeout: 1)
        XCTAssertNil(result)
    }

    func test_checkProductSegmentation_segmentsEmpty_returnNil() throws {
        var result: [InAppProductSegmentResponse.CustomerSegmentation]?
        let expectations = expectation(description: "test_checkProductSegmentation_segmentsEmpty_returnNil")
        sut.checkProductSegmentationRequest(products: .init(ids: ["Hello": "World"])) { response in
            if case .success(let segmentations) = response {
                result = segmentations
            }
            expectations.fulfill()
        }

        waitForExpectations(timeout: 1)

        XCTAssertNil(result)
    }

    func test_checkProductSegmentation_request_valid() throws {
        let expectedModel: [InAppProductSegmentResponse.CustomerSegmentation] = [
            .init(ids: .init(externalId: "123"),
                  segment: .init(ids: .init(externalId: "456")))
        ]

        var result: [InAppProductSegmentResponse.CustomerSegmentation]?
        targetingChecker.context.productSegments.append("0000")
        let expectations = expectation(description: "test_geo_request")

        sut.checkProductSegmentationRequest(products: .init(ids: ["Hello": "World"])) { response in
            if case .success(let segmentations) = response {
                result = segmentations
            }
            expectations.fulfill()
        }

        waitForExpectations(timeout: 1)

        XCTAssertEqual(result, expectedModel)
    }

    func test_checkSegmentation_request_serverError_returnsFailure() {
        sut.customerSegmentsAPI = CustomerSegmentsAPI { _, completion in
            completion(.failure(.serverError(.init(
                status: .internalServerError,
                errorMessage: "Internal Server error",
                httpStatusCode: 500
            ))))
        } fetchProductSegments: { _, completion in
            completion(.success(.init(status: .success, products: nil)))
        }
        targetingChecker.context.segments.append("123")
        let expectation = expectation(description: "segmentation request should return server error")
        var receivedError: MindboxError?

        sut.checkSegmentationRequest { result in
            if case .failure(let error) = result {
                receivedError = error
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1)

        guard case .serverError(let protocolError) = receivedError else {
            XCTFail("Expected serverError")
            return
        }
        XCTAssertEqual(protocolError.httpStatusCode, 500)
    }

    func test_checkProductSegmentation_request_serverError_returnsFailure() {
        sut.customerSegmentsAPI = CustomerSegmentsAPI { _, completion in
            completion(.success(.init(status: .success, customerSegmentations: [])))
        } fetchProductSegments: { _, completion in
            completion(.failure(.serverError(.init(
                status: .internalServerError,
                errorMessage: "Internal Server error",
                httpStatusCode: 500
            ))))
        }
        targetingChecker.context.productSegments.append("0000")
        let expectation = expectation(description: "product segmentation request should return server error")
        var receivedError: MindboxError?

        sut.checkProductSegmentationRequest(products: .init(ids: ["Hello": "World"])) { result in
            if case .failure(let error) = result {
                receivedError = error
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1)

        guard case .serverError(let protocolError) = receivedError else {
            XCTFail("Expected serverError")
            return
        }
        XCTAssertEqual(protocolError.httpStatusCode, 500)
    }
}
