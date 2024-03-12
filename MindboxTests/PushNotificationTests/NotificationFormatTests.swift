//
//  NotificationFormatTests.swift
//  MindboxTests
//
//  Created by vailence on 13.02.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox
//
//final class NotificationFormatTests: XCTestCase {
//
//    // MARK: - Legacy format
//    func test_legacy_format_return_model() {
//        let userInfo: [AnyHashable: Any] = [
//            "aps": [
//                "alert": [
//                    "title": "Пример заголовка",
//                    "body": "Текст уведомления"
//                ],
//                "sound": "default",
//                "mutable-content": 1,
//                "content-available": 1,
//                "clickUrl": "https://example.com/click",
//                "imageUrl": "https://example.com/image.jpg",
//                "payload": "Пример полезной нагрузки",
//                "buttons": [
//                    [
//                        "text": "Кнопка 1",
//                        "url": "https://example.com/button1",
//                        "uniqueKey": "button1Key"
//                    ]
//                ],
//                "uniqueKey": "uniqueNotificationKey"
//            ]
//        ]
//
//        guard let model = NotificationFormatter.formatNotification(userInfo) else {
//            XCTFail("MBPushNotification is nil")
//            return
//        }
//        
//        XCTAssertEqual(model.clickUrl, "https://example.com/click")
//        XCTAssertEqual(model.aps?.alert?.body, "Текст уведомления")
//        XCTAssertEqual(model.uniqueKey, "uniqueNotificationKey")
//    }
//    
//    func test_legacy_format_no_clickURL_return_nil() {
//        let userInfo: [AnyHashable: Any] = [
//            "aps": [
//                "alert": [
//                    "title": "Пример заголовка",
//                    "body": "Текст уведомления"
//                ],
//                "sound": "default",
//                "mutable-content": 1,
//                "content-available": 1,
//                "imageUrl": "https://example.com/image.jpg",
//                "payload": "Пример полезной нагрузки",
//                "buttons": [
//                    [
//                        "text": "Кнопка 1",
//                        "url": "https://example.com/button1",
//                        "uniqueKey": "button1Key"
//                    ]
//                ],
//                "uniqueKey": "uniqueNotificationKey"
//            ]
//        ]
//
//        
//        XCTAssertNil(NotificationFormatter.formatNotification(userInfo))
//    }
//
//    func test_legacy_format_no_uniqueKey_return_nil() {
//        let userInfo: [AnyHashable: Any] = [
//            "aps": [
//                "alert": [
//                    "title": "Пример заголовка",
//                    "body": "Текст уведомления"
//                ],
//                "sound": "default",
//                "mutable-content": 1,
//                "content-available": 1,
//                "clickUrl": "https://example.com/click",
//                "imageUrl": "https://example.com/image.jpg",
//                "payload": "Пример полезной нагрузки",
//                "buttons": [
//                    [
//                        "text": "Кнопка 1",
//                        "url": "https://example.com/button1",
//                        "uniqueKey": "button1Key"
//                    ]
//                ]
//            ]
//        ]
//
//        
//        XCTAssertNil(NotificationFormatter.formatNotification(userInfo))
//    }
//    
//    // MARK: - Current format
//    func test_current_format_return_model() {
//        let userInfo: [AnyHashable: Any] = [
//            "aps": [
//                "alert": [
//                    "title": "Пример заголовка",
//                    "body": "Текст уведомления"
//                ],
//                "sound": "default",
//                "mutable-content": 1,
//                "content-available": 1
//            ],
//            "clickUrl": "https://example.com/click",
//            "imageUrl": "https://example.com/image.jpg",
//            "payload": "Пример полезной нагрузки",
//            "buttons": [
//                [
//                    "text": "Кнопка 1",
//                    "url": "https://example.com/button1",
//                    "uniqueKey": "button1Key"
//                ]
//            ],
//            "uniqueKey": "uniqueNotificationKey"
//        ]
//        
//        guard let model = NotificationFormatter.formatNotification(userInfo) else {
//            XCTFail("MBPushNotification is nil")
//            return
//        }
//        
//        XCTAssertEqual(model.clickUrl, "https://example.com/click")
//        XCTAssertEqual(model.aps?.alert?.body, "Текст уведомления")
//        XCTAssertEqual(model.uniqueKey, "uniqueNotificationKey")
//    }
//
//    // MARK: - No user info
//    func test_empty_user_info_return_nil() {
//        let userInfo: [AnyHashable: Any] = [:]
//        XCTAssertNil(NotificationFormatter.formatNotification(userInfo))
//    }
//}
