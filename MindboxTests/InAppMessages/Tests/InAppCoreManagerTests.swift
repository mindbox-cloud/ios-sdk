//
//  InAppCoreManagerTests.swift
//  MindboxTests
//
//  Created by Максим Казаков on 14.09.2022.
//  Copyright © 2022 Mikhail Barilov. All rights reserved.
//

import Foundation

import XCTest
@testable import Mindbox

class InAppCoreManagerTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    func test_startEvent_withSegmentation_happyFlow() throws {
        let configManager = InAppConfigurationManagerMock()
        let segmentationChecker = InAppSegmentationCheckerMock()
        let presentationManager = InAppPresentationManagerMock()
        let imagesStorage = InAppImagesStorageMock()
        let serialQueue = DispatchQueue(label: "core-manager-tests")

        let sut = InAppCoreManager(
            configManager: configManager,
            segmentationChecker: segmentationChecker,
            presentationManager: presentationManager,
            imagesStorage: imagesStorage,
            serialQueue: serialQueue
        )
        let triggerEvent = InAppMessageTriggerEvent.start
        let inAppsFromRequest: [InAppsCheckRequest.InAppInfo] = [
            .init(
                inAppId: "in-app-1",
                targeting: SegmentationTargeting(segmentation: "segmentation-id-1", segment: "segment-id-1")
            )
        ]
        configManager.buildInAppRequestResult = InAppsCheckRequest(triggerEvent: triggerEvent, possibleInApps: inAppsFromRequest)
        segmentationChecker.inAppToPresentResult = InAppResponse(triggerEvent: triggerEvent, inAppToShowId: "in-app-1")
        imagesStorage.imageResult = "image-data-bytes".data(using: .utf8)!
        configManager.inAppFormDataResult = InAppFormData(imageUrl: URL(string: "image-url")!)

        sut.start()
        configManager.delegate?.didPreparedConfiguration()
        let serialQueueFinishExpectation = self.expectation(description: "core manager queue finish")
        serialQueue.async {
            serialQueueFinishExpectation.fulfill()
        }

        self.wait(for: [serialQueueFinishExpectation], timeout: 0.1)
        XCTAssertEqual(presentationManager.receivedInAppUIModel?.imageData, "image-data-bytes".data(using: .utf8)!)
    }
}
