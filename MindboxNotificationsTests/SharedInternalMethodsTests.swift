//
//  SharedInternalMethodsTests.swift
//  MindboxNotificationsTests
//
//  Created by Sergei Semko on 8/13/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import XCTest
@testable import MindboxNotifications

final class SharedInternalMethodsTests: XCTestCase {

    var service: MindboxNotificationService!
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
        mockNotificationRequest = UNNotificationRequest(identifier: "test", content: content, trigger: nil)
    }
    
    override func tearDown() {
        service = nil
        mockNotificationRequest = nil
        super.tearDown()
    }
    
    func testParseToPayload() {
        let payload = service.parse(request: mockNotificationRequest)
        XCTAssertNotNil(payload)
        XCTAssertNotNil(payload?.withButton)
        XCTAssertEqual(payload?.withButton?.buttons?.first?.uniqueKey, "1b112bcd-5eae-4914-8842-d77198466466")
        XCTAssertEqual(payload?.withButton?.buttons?.first?.text, "Documentation")
        XCTAssertEqual(payload?.withButton?.buttons?.last?.uniqueKey, "cff05f38-6df4-4a10-9859-ea3bf0a65068")
        XCTAssertEqual(payload?.withButton?.buttons?.last?.text, "Button #1")
        XCTAssertNotNil(payload?.withImageURL)
        XCTAssertEqual(payload?.withImageURL?.imageUrl, "https://mobpush-images.mindbox.ru/Mpush-test/63/5933f4cd-47e3-4317-9237-bc5aad291aa9.png")
    }
    
    func testGetUserInfo() {
        let result = service.getUserInfo(from: mockNotificationRequest)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?["uniqueKey"] as? String, "4cccb64d-ba46-41eb-9699-3a706f2b910b")
        XCTAssertEqual(result?["clickUrl"] as? String, "https://mindbox.ru/")
        
        let apsResult = result?["aps"] as? [AnyHashable: Any]
        XCTAssertNotNil(apsResult)
        XCTAssertEqual(apsResult?["mutable-content"] as? Int, 1)
        XCTAssertEqual(apsResult?["content-available"] as? Int, 1)
        XCTAssertEqual(apsResult?["sound"] as? String, "default")
        
        let alertResult = apsResult?["alert"] as? [String: String]
        XCTAssertNotNil(alertResult)
        XCTAssertEqual(alertResult?["title"], "Test title")
        XCTAssertEqual(alertResult?["body"], "Test description")
    }

    func testGetUserInfoLegacyPushFormat() {
        let aps: [AnyHashable: Any] = [
            "aps": [
                "mutable-content": 1,
                "alert": [
                    "title": "Test title",
                    "body": "Test description"
                ],
                "content-available": 1,
                "sound": "default",
                "clickUrl": "https://mindbox.ru/",
                "payload": "{\n  \"payload\": \"data\"\n}",
                "uniqueKey": "4cccb64d-ba46-41eb-9699-3a706f2b910b",
                "imageUrl": "https://mobpush-images.mindbox.ru/Mpush-test/63/5933f4cd-47e3-4317-9237-bc5aad291aa9.png",
                "buttons": [
                    [
                        "url": "https://developers.mindbox.ru/docs/mindbox-sdk",
                        "text": "Documentation",
                        "uniqueKey": "1b112bcd-5eae-4914-8842-d77198466466"
                    ]
                ],
            ]
        ]
        
        let userInfo: [AnyHashable: Any] = aps
        
        let content = UNMutableNotificationContent()
        content.userInfo = userInfo
        let request = UNNotificationRequest(identifier: "test", content: content, trigger: nil)
        
        let result = service.getUserInfo(from: request)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?["uniqueKey"] as? String, "4cccb64d-ba46-41eb-9699-3a706f2b910b")
        XCTAssertEqual(result?["clickUrl"] as? String, "https://mindbox.ru/")
        

        XCTAssertEqual(result?["mutable-content"] as? Int, 1)
        XCTAssertEqual(result?["content-available"] as? Int, 1)
        XCTAssertEqual(result?["sound"] as? String, "default")
        
        let alertResult = result?["alert"] as? [String: String]
        XCTAssertNotNil(alertResult)
        XCTAssertEqual(alertResult?["title"], "Test title")
        XCTAssertEqual(alertResult?["body"], "Test description")
    }
}
