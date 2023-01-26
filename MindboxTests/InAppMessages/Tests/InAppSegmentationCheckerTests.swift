//
//  InAppSegmentationCheckerTests.swift
//  MindboxTests
//
//  Created by Максим Казаков on 13.09.2022.
//  Copyright © 2022 Mikhail Barilov. All rights reserved.
//

import XCTest
@testable import Mindbox

class InAppSegmentationCheckerTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func test_singleInApp_singleCustomerSegment_happyFlow() throws {
//        var segmentationCheckResponse: SegmentationCheckResponse!
//        let sut = InAppSegmentationChecker(
//            customerSegmentsAPI: CustomerSegmentsAPI(fetchSegments: { segmentationCheckRequest, completion in
//                completion(segmentationCheckResponse)
//            })
//        )
//
//        let request = InAppsCheckRequest(
//            triggerEvent: .start,
//            possibleInApps: [
//                .init(inAppId: "in_app_id_1", targeting: .init(segmentation: "segmentation_id", segment: "segment_id"))
//            ]
//        )
//        segmentationCheckResponse = SegmentationCheckResponse(status: .success, customerSegmentations: [
//            .init(
//                segmentation: .init(ids: .init(externalId: "segmentation_id")),
//                segment: .init(ids: .init(externalId: "segment_id"))
//            )
//        ])
//
//        var actualResponse: InAppResponse!
//        let expectation = self.expectation(description: "Response")
//        sut.getInAppToPresent(
//            request: request,
//            completionQueue: .main) { response in
//                actualResponse = response
//                expectation.fulfill()
//            }
//
//        self.wait(for: [expectation], timeout: 0.1)
//        XCTAssertEqual(actualResponse.inAppToShowId, "in_app_id_1")
    }

    func test_threeInApps_singleSegment_happyFlow() throws {
//        var segmentationCheckResponse: SegmentationCheckResponse!
//        let sut = InAppSegmentationChecker(
//            customerSegmentsAPI: CustomerSegmentsAPI(fetchSegments: { segmentationCheckRequest, completion in
//                completion(segmentationCheckResponse)
//            })
//        )
//
//        let request = InAppsCheckRequest(
//            triggerEvent: .start,
//            possibleInApps: [
//                .init(inAppId: "in_app_id_1", targeting: .init(segmentation: "segmentation_id_1", segment: "segment_id_1")),
//                .init(inAppId: "in_app_id_2", targeting: .init(segmentation: "segmentation_id_2", segment: "segment_id_2")),
//                .init(inAppId: "in_app_id_3", targeting: .init(segmentation: "segmentation_id_3", segment: "segment_id_3"))
//            ]
//        )
//        segmentationCheckResponse = SegmentationCheckResponse(status: .success, customerSegmentations: [
//            .init(
//                segmentation: .init(ids: .init(externalId: "segmentation_id_2")),
//                segment: .init(ids: .init(externalId: "segment_id_2"))
//            )
//        ])
//
//        var actualResponse: InAppResponse!
//        let expectation = self.expectation(description: "Response")
//        sut.getInAppToPresent(
//            request: request,
//            completionQueue: .main) { response in
//                actualResponse = response
//                expectation.fulfill()
//            }
//
//        self.wait(for: [expectation], timeout: 0.1)
//        XCTAssertEqual(actualResponse.inAppToShowId, "in_app_id_2")
    }

    func test_singleInApp_singleCustomerSegment_segmentsNotMatchedMFlow() throws {
//        var segmentationCheckResponse: SegmentationCheckResponse!
//        let sut = InAppSegmentationChecker(
//            customerSegmentsAPI: CustomerSegmentsAPI(fetchSegments: { segmentationCheckRequest, completion in
//                completion(segmentationCheckResponse)
//            })
//        )
//
//        let request = InAppsCheckRequest(
//            triggerEvent: .start,
//            possibleInApps: [
//                .init(inAppId: "in_app_id_1", targeting: .init(segmentation: "segmentation_id", segment: "segment_id"))
//            ]
//        )
//        segmentationCheckResponse = SegmentationCheckResponse(status: .success, customerSegmentations: [
//            .init(
//                segmentation: .init(ids: .init(externalId: "segmentation_id")),
//                segment: .init(ids: .init(externalId: "segment_id_other_than_inside_inapp"))
//            )
//        ])
//
//        var actualResponse: InAppResponse!
//        let expectation = self.expectation(description: "Response")
//        sut.getInAppToPresent(
//            request: request,
//            completionQueue: .main) { response in
//                actualResponse = response
//                expectation.fulfill()
//            }
//
//        self.wait(for: [expectation], timeout: 0.1)
//        XCTAssertNil(actualResponse)
    }

    func test_singleInApp_andApiReturnsNil() throws {
//        let sut = InAppSegmentationChecker(
//            customerSegmentsAPI: CustomerSegmentsAPI(fetchSegments: { segmentationCheckRequest, completion in
//                completion(nil)
//            })
//        )
//        let request = InAppsCheckRequest(
//            triggerEvent: .start,
//            possibleInApps: [
//                .init(inAppId: "in_app_id_1", targeting: .init(segmentation: "segmentation_id", segment: "segment_id"))
//            ]
//        )
//
//        var actualResponse: InAppResponse!
//        let expectation = self.expectation(description: "Response")
//        sut.getInAppToPresent(
//            request: request,
//            completionQueue: .main) { response in
//                actualResponse = response
//                expectation.fulfill()
//            }
//
//        self.wait(for: [expectation], timeout: 0.1)
//        XCTAssertNil(actualResponse)
    }

    func test_twoInApp_oneWithTargeting_secoundWithoutTargeting_andApiReturnsNil_thenReturnWithoutTargeting() throws {
//        let sut = InAppSegmentationChecker(
//            customerSegmentsAPI: CustomerSegmentsAPI(fetchSegments: { segmentationCheckRequest, completion in
//                completion(nil)
//            })
//        )
//        let request = InAppsCheckRequest(
//            triggerEvent: .start,
//            possibleInApps: [
//                .init(inAppId: "in_app_id_1", targeting: .init(segmentation: "segmentation_id", segment: "segment_id")),
//                .init(inAppId: "in_app_id_2", targeting: nil)
//            ]
//        )
//
//        var actualResponse: InAppResponse!
//        let expectation = self.expectation(description: "Response")
//        sut.getInAppToPresent(
//            request: request,
//            completionQueue: .main) { response in
//                actualResponse = response
//                expectation.fulfill()
//            }
//
//        self.wait(for: [expectation], timeout: 0.1)
//        XCTAssertEqual(actualResponse.inAppToShowId, "in_app_id_2")
    }

    func test_twoInApp_oneWithTargeting_secoundWithoutTargeting_andNoSegmentsMatch_thenReturnWithoutTargeting() throws {
//        var segmentationCheckResponse: SegmentationCheckResponse!
//        let sut = InAppSegmentationChecker(
//            customerSegmentsAPI: CustomerSegmentsAPI(fetchSegments: { segmentationCheckRequest, completion in
//                completion(segmentationCheckResponse)
//            })
//        )
//        let request = InAppsCheckRequest(
//            triggerEvent: .start,
//            possibleInApps: [
//                .init(inAppId: "in_app_id_1", targeting: .init(segmentation: "segmentation_id", segment: "segment_id")),
//                .init(inAppId: "in_app_id_2", targeting: nil)
//            ]
//        )
//        segmentationCheckResponse = SegmentationCheckResponse(status: .success, customerSegmentations: [
//            .init(
//                segmentation: .init(ids: .init(externalId: "segmentation_id_2")),
//                segment: .init(ids: .init(externalId: "segment_id_2"))
//            )
//        ])
//
//        var actualResponse: InAppResponse!
//        let expectation = self.expectation(description: "Response")
//        sut.getInAppToPresent(
//            request: request,
//            completionQueue: .main) { response in
//                actualResponse = response
//                expectation.fulfill()
//            }
//
//        self.wait(for: [expectation], timeout: 0.1)
//        XCTAssertEqual(actualResponse.inAppToShowId, "in_app_id_2")
    }
}
