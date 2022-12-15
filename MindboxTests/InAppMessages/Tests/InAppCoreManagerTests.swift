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

    var configManager: InAppConfigurationManagerMock!
    var segmentationChecker: InAppSegmentationCheckerMock!
    var presentationManager: InAppPresentationManagerMock!
    var persistenceStorage: MockPersistenceStorage!
    var serialQueue: DispatchQueue!
    var sut: InAppCoreManager!

    override func setUpWithError() throws {
        configManager = InAppConfigurationManagerMock()
        segmentationChecker = InAppSegmentationCheckerMock()
        presentationManager = InAppPresentationManagerMock()
        persistenceStorage = MockPersistenceStorage()
        serialQueue = DispatchQueue(label: "core-manager-tests")

        sut = InAppCoreManager(
            configManager: configManager,
            segmentationChecker: segmentationChecker,
            presentationManager: presentationManager,
            persistenceStorage: persistenceStorage,
            serialQueue: serialQueue
        )
    }

    func test_startEvent_withSegmentation_happyFlow() throws {
        let triggerEvent = InAppMessageTriggerEvent.start
        let inAppsFromRequest: [InAppsCheckRequest.InAppInfo] = [
            .init(
                inAppId: "in-app-1",
                targeting: SegmentationTargeting(segmentation: "segmentation-id-1", segment: "segment-id-1")
            )
        ]
        let inAppCheckRequest = InAppsCheckRequest(triggerEvent: triggerEvent, possibleInApps: inAppsFromRequest)
        configManager.buildInAppRequestResult = InAppsCheckRequest(triggerEvent: triggerEvent, possibleInApps: inAppsFromRequest)
        segmentationChecker.inAppToPresentResult = InAppResponse(triggerEvent: triggerEvent, inAppToShowId: "in-app-1")
        configManager.inAppFormDataResult = InAppFormData(inAppId: "in-app-1", imageUrl: URL(string: "image-url")!, redirectUrl: "", intentPayload: "")

        sut.start()
        configManager.delegate?.didPreparedConfiguration()
        let serialQueueFinishExpectation = self.expectation(description: "core manager queue finish")
        serialQueue.async { serialQueueFinishExpectation.fulfill() }

        self.wait(for: [serialQueueFinishExpectation], timeout: 0.1)
        XCTAssertEqual(segmentationChecker.requestReceived, inAppCheckRequest)
        XCTAssertEqual(presentationManager.receivedInAppUIModel?.imageUrl, URL(string: "image-url")!)
    }

    func test_startEvent_withoutSegmentation_happyFlow() throws {
        let triggerEvent = InAppMessageTriggerEvent.start
        let inAppsFromRequest: [InAppsCheckRequest.InAppInfo] = [
            .init(
                inAppId: "in-app-without-segmentation",
                targeting: nil
            ),
            .init(
                inAppId: "in-app-with-segmentation",
                targeting: SegmentationTargeting(segmentation: "segmentation-id-1", segment: "segment-id-1")
            )
        ]
        configManager.buildInAppRequestResult = InAppsCheckRequest(triggerEvent: triggerEvent, possibleInApps: inAppsFromRequest)
        segmentationChecker.inAppToPresentResult = InAppResponse(triggerEvent: triggerEvent, inAppToShowId: "in-app-with-segmentation")
        configManager.inAppFormDataResult = InAppFormData(inAppId: "in-app-without-segmentation", imageUrl: URL(string: "image-url")!, redirectUrl: "", intentPayload: "")

        sut.start()
        configManager.delegate?.didPreparedConfiguration()
        let serialQueueFinishExpectation = self.expectation(description: "core manager queue finish")
        serialQueue.async { serialQueueFinishExpectation.fulfill() }

        self.wait(for: [serialQueueFinishExpectation], timeout: 0.1)
        XCTAssertNil(segmentationChecker.requestReceived)
        XCTAssertEqual(presentationManager.receivedInAppUIModel?.imageUrl, URL(string: "image-url")!)
    }

    func test_startEventAndFewOtherEvents_onlyOneInAppShouldBePresented() throws {
        let triggerEvent = InAppMessageTriggerEvent.start
        let inAppsFromRequest: [InAppsCheckRequest.InAppInfo] = [
            .init(
                inAppId: "in-app-without-segmentation",
                targeting: nil
            ),
            .init(
                inAppId: "in-app-with-segmentation",
                targeting: SegmentationTargeting(segmentation: "segmentation-id-1", segment: "segment-id-1")
            )
        ]
        configManager.buildInAppRequestResult = InAppsCheckRequest(triggerEvent: triggerEvent, possibleInApps: inAppsFromRequest)
        segmentationChecker.inAppToPresentResult = InAppResponse(triggerEvent: triggerEvent, inAppToShowId: "in-app-with-segmentation")
        configManager.inAppFormDataResult = InAppFormData(inAppId: "in-app-with-segmentation", imageUrl: URL(string: "image-url")!, redirectUrl: "", intentPayload: "")

        sut.start()
        sut.sendEvent(.start)
        sut.sendEvent(.start)

        configManager.delegate?.didPreparedConfiguration()
        let serialQueueFinishExpectation = self.expectation(description: "core manager queue finish")
        serialQueue.async { serialQueueFinishExpectation.fulfill() }

        self.wait(for: [serialQueueFinishExpectation], timeout: 0.1)
        XCTAssertNil(segmentationChecker.requestReceived)
        XCTAssertEqual(presentationManager.presentCallsCount, 1)
    }

    func test_startEvent_whenHaveAlreadyShownOneOfTwoInApps() throws {
        let triggerEvent = InAppMessageTriggerEvent.start
        let inAppsFromRequest: [InAppsCheckRequest.InAppInfo] = [
            .init(
                inAppId: "in-app-1",
                targeting: nil
            ),
            .init(
                inAppId: "in-app-2",
                targeting: nil
            )
        ]
        persistenceStorage.shownInAppsIds = ["in-app-1"]
        configManager.buildInAppRequestResult = InAppsCheckRequest(triggerEvent: triggerEvent, possibleInApps: inAppsFromRequest)
        configManager.inAppFormDataResult = InAppFormData(inAppId: "in-app-2", imageUrl: URL(string: "image-url")!, redirectUrl: "", intentPayload: "")

        sut.start()
        configManager.delegate?.didPreparedConfiguration()

        waitForCoreManagerQueueFinished()

        XCTAssertEqual(configManager.receivedInAppResponse?.inAppToShowId, "in-app-2")
        XCTAssertEqual(presentationManager.presentCallsCount, 1)
        XCTAssertNotNil(presentationManager.receivedOnPresent)

        presentationManager.receivedOnPresent!()
        waitForCoreManagerQueueFinished()

        XCTAssertEqual(persistenceStorage.shownInAppsIds?.count, 2)
        XCTAssertEqual(persistenceStorage.shownInAppsIds![1], "in-app-2")
    }

    func test_startEvent_whenHaveAlreadyShownAllInApps() throws {
        let triggerEvent = InAppMessageTriggerEvent.start
        let inAppsFromRequest: [InAppsCheckRequest.InAppInfo] = [
            .init(
                inAppId: "in-app-1",
                targeting: nil
            ),
            .init(
                inAppId: "in-app-2",
                targeting: SegmentationTargeting(segmentation: "segmentation-id-1", segment: "segment-id-1")
            )
        ]
        persistenceStorage.shownInAppsIds = ["in-app-1", "in-app-2"]
        configManager.buildInAppRequestResult = InAppsCheckRequest(triggerEvent: triggerEvent, possibleInApps: inAppsFromRequest)

        sut.start()
        configManager.delegate?.didPreparedConfiguration()

        waitForCoreManagerQueueFinished()

        XCTAssertNil(segmentationChecker.requestReceived)
        XCTAssertNil(configManager.receivedInAppResponse)
    }

    private func waitForCoreManagerQueueFinished() {
        let serialQueueFinishExpectation = self.expectation(description: "core manager queue finish")
        serialQueue.async { serialQueueFinishExpectation.fulfill() }
        self.wait(for: [serialQueueFinishExpectation], timeout: 0.1)
    }
}
