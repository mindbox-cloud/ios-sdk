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
    var presentationManager: InAppPresentationManagerMock!
    var persistenceStorage: MockPersistenceStorage!
    var serialQueue: DispatchQueue!
    var sessionStorage: SessionTemporaryStorage!
    var sut: InAppCoreManager!

    override func setUpWithError() throws {
        configManager = InAppConfigurationManagerMock()
        presentationManager = InAppPresentationManagerMock()
        persistenceStorage = MockPersistenceStorage()
        serialQueue = DispatchQueue(label: "core-manager-tests")
        sessionStorage = SessionTemporaryStorage()
        
        sut = InAppCoreManager(
            configManager: configManager,
            presentationManager: presentationManager,
            persistenceStorage: persistenceStorage,
            serialQueue: serialQueue,
            sessionStorage: sessionStorage
        )
    }

    func test_startEvent_withSegmentation_happyFlow() throws {
        let triggerEvent = InAppMessageTriggerEvent.start
        let inAppsFromRequest: [InAppsCheckRequest.InAppInfo] = [
            .init(
                inAppId: "in-app-1"
            )
        ]
        configManager.buildInAppRequestResult = InAppsCheckRequest(triggerEvent: triggerEvent, possibleInApps: inAppsFromRequest)
        configManager.inAppFormDataResult = InAppFormData(inAppId: "in-app-1", imageUrl: URL(string: "image-url")!, redirectUrl: "", intentPayload: "")

        sut.start()
        configManager.delegate?.didPreparedConfiguration()
        let serialQueueFinishExpectation = self.expectation(description: "core manager queue finish")
        serialQueue.async { serialQueueFinishExpectation.fulfill() }

        self.wait(for: [serialQueueFinishExpectation], timeout: 0.1)
        XCTAssertEqual(presentationManager.receivedInAppUIModel?.imageUrl, URL(string: "image-url")!)
    }

    func test_startEvent_withoutSegmentation_happyFlow() throws {
        let triggerEvent = InAppMessageTriggerEvent.start
        let inAppsFromRequest: [InAppsCheckRequest.InAppInfo] = [
            .init(
                inAppId: "in-app-without-segmentation"
            ),
            .init(
                inAppId: "in-app-with-segmentation"
            )
        ]
        configManager.buildInAppRequestResult = InAppsCheckRequest(triggerEvent: triggerEvent, possibleInApps: inAppsFromRequest)
        configManager.inAppFormDataResult = InAppFormData(inAppId: "in-app-without-segmentation", imageUrl: URL(string: "image-url")!, redirectUrl: "", intentPayload: "")

        sut.start()
        configManager.delegate?.didPreparedConfiguration()
        let serialQueueFinishExpectation = self.expectation(description: "core manager queue finish")
        serialQueue.async { serialQueueFinishExpectation.fulfill() }

        self.wait(for: [serialQueueFinishExpectation], timeout: 0.1)
        XCTAssertEqual(presentationManager.receivedInAppUIModel?.imageUrl, URL(string: "image-url")!)
    }

    func test_startEventAndFewOtherEvents_onlyOneInAppShouldBePresented() throws {
        let triggerEvent = InAppMessageTriggerEvent.start
        let inAppsFromRequest: [InAppsCheckRequest.InAppInfo] = [
            .init(inAppId: "in-app-without-segmentation"),
            .init(inAppId: "in-app-with-segmentation")
        ]
        configManager.buildInAppRequestResult = InAppsCheckRequest(triggerEvent: triggerEvent, possibleInApps: inAppsFromRequest)
        configManager.inAppFormDataResult = InAppFormData(inAppId: "in-app-with-segmentation",
                                                          imageUrl: URL(string: "image-url")!,
                                                          redirectUrl: "",
                                                          intentPayload: "")

        sut.start()
        sut.sendEvent(.start)
        sut.sendEvent(.start)

        configManager.delegate?.didPreparedConfiguration()
        let serialQueueFinishExpectation = self.expectation(description: "core manager queue finish")
        serialQueue.async { serialQueueFinishExpectation.fulfill() }

        self.wait(for: [serialQueueFinishExpectation], timeout: 2)
        XCTAssertEqual(presentationManager.presentCallsCount, 1)
    }

    func test_startEvent_whenHaveAlreadyShownOneOfTwoInApps() throws {
        let triggerEvent = InAppMessageTriggerEvent.start
        let inAppsFromRequest: [InAppsCheckRequest.InAppInfo] = [
            .init(inAppId: "in-app-1"),
            .init(inAppId: "in-app-2")
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
            .init(inAppId: "in-app-1"),
            .init(inAppId: "in-app-2")
        ]
        persistenceStorage.shownInAppsIds = ["in-app-1", "in-app-2"]
        configManager.buildInAppRequestResult = InAppsCheckRequest(triggerEvent: triggerEvent, possibleInApps: inAppsFromRequest)

        sut.start()
        configManager.delegate?.didPreparedConfiguration()

        waitForCoreManagerQueueFinished()

        XCTAssertNil(configManager.receivedInAppResponse)
    }

    private func waitForCoreManagerQueueFinished() {
        let serialQueueFinishExpectation = self.expectation(description: "core manager queue finish")
        serialQueue.async { serialQueueFinishExpectation.fulfill() }
        self.wait(for: [serialQueueFinishExpectation], timeout: 0.1)
    }
}
