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

    func testExample() throws {
        let sut = InAppSegmentationChecker()

        let request = InAppsCheckRequest(
            triggerEvent: .start,
            possibleInApps: [
                .init(inAppId: "in_app_id_1", targeting: .init(segmentation: "segmentation_id", segment: "segment_id"))
            ]
        )

        var actualResponse: InAppResponse!
        let expectation = self.expectation(description: "Response")
        sut.getInAppToPresent(
            request: request,
            completionQueue: .main) { response in
                actualResponse = response
                expectation.fulfill()
            }

        self.wait(for: [expectation], timeout: 0.1)        
        XCTAssertEqual(actualResponse.inAppToShowId, "in_app_id_1")
    }

}
