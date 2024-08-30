//
//  MindboxNotificationServiceTests.swift
//  MindboxNotificationsTests
//
//  Created by Sergei Semko on 8/13/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import XCTest
@testable import MindboxNotifications

final class MindboxNotificationServiceTests: XCTestCase {

    var service: MindboxNotificationServiceProtocol!
    var mockNotificationRequest: UNNotificationRequest!

    override func setUp() {
        super.setUp()
        service = MindboxNotificationService()
        
        let aps: [AnyHashable: Any] = [
            "mutable-content": 1,
            "alert": [
                "title": "Test title",
                "body": "Test description"
            ],
            "content-available": 1,
            "sound": "default"
        ]
        
        let userInfo: [AnyHashable: Any] = [
            "clickUrl": "https://mindbox.ru/",
            "payload": "{\n  \"payload\": \"data\"\n}",
            "uniqueKey": "4cccb64d-ba46-41eb-9699-3a706f2b910b",
            "imageUrl": "https://mobpush-images.mindbox.ru/Mpush-test/63/5933f4cd-47e3-4317-9237-bc5aad291aa9.png",
            "buttons": [
                [
                    "url": "https://developers.mindbox.ru/docs/mindbox-sdk",
                    "text": "Documentation",
                    "uniqueKey": "1b112bcd-5eae-4914-8842-d77198466466"
                ],
                [
                    "url": "https://google.com",
                    "text": "Button #1",
                    "uniqueKey": "cff05f38-6df4-4a10-9859-ea3bf0a65068"
                ]
            ],
            "aps": aps
        ]
        
        let content = UNMutableNotificationContent()
        content.userInfo = userInfo
        content.title = "Test title"
        content.body = "Test description"
        mockNotificationRequest = UNNotificationRequest(identifier: "test", content: content, trigger: nil)
    }
    
    override func tearDown() {
        service = nil
        mockNotificationRequest = nil
        super.tearDown()
    }

    func testDidReceiveWithContentHandler() {
        let expectation = self.expectation(description: "Content Handler Called")
        var receivedContent: UNNotificationContent?
        
        service.didReceive(mockNotificationRequest) { content in
            receivedContent = content
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertNotNil(service.contentHandler)
        XCTAssertNotNil(service.bestAttemptContent)
        XCTAssertEqual(service.bestAttemptContent?.userInfo["uniqueKey"] as? String, "4cccb64d-ba46-41eb-9699-3a706f2b910b")
        XCTAssertNotNil(receivedContent)
        
        XCTAssertEqual(service.bestAttemptContent?.title, "Test title")
        XCTAssertEqual(service.bestAttemptContent?.body, "Test description")
        XCTAssertFalse(service.bestAttemptContent!.attachments.isEmpty)
        XCTAssertTrue(service.bestAttemptContent!.attachments.count == 1)
    }

    func testServiceExtensionTimeWillExpire_CallsProceedFinalStage() {
        let expectation = self.expectation(description: "Content Handler Called")
        var receivedContent: UNNotificationContent?

        service.didReceive(mockNotificationRequest) { content in
            receivedContent = content
            expectation.fulfill()
        }

        service.serviceExtensionTimeWillExpire()

        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertNotNil(receivedContent)
        XCTAssertEqual(receivedContent?.categoryIdentifier, Constants.categoryIdentifier)
    }
}
