//
//  MindboxPushValidatorTests.swift
//  MindboxTests
//
//  Created by vailence on 13.02.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

final class MindboxPushValidatorTests: XCTestCase {
    
    var validator: MindboxPushValidator!
    
    override func setUp() {
        super.setUp()
        validator = DI.injectOrFail(MindboxPushValidator.self)
    }
    
    override func tearDown() {
        super.tearDown()
        validator = nil
    }
    
    func testValidatorWithValidNotification() {
        let validNotification: [AnyHashable: Any] = [
            "aps": [
                "alert": [
                    "title": "Sample Message Title",
                    "body": "This is the message body content."
                ],
                "sound": "default",
                "mutable-content": 1,
                "content-available": 1
            ],
            "clickUrl": "https://example.com/click-here",
            "imageUrl": "https://example.com/image.jpg",
            "payload": "{\"key\":\"value\"}",
            "buttons": [
                [
                    "text": "Button 1",
                    "url": "https://example.com/button-1",
                    "uniqueKey": "guid-for-button-1"
                ]
            ],
            "uniqueKey": "guid-for-message"
        ]
        
        XCTAssertTrue(validator.isValid(item: validNotification), "Validator should return true for a valid notification")
    }
    
    func test_no_body_return_false() {
        let invalidNotification: [AnyHashable: Any] = [
            "aps": [
                "alert": [
                    "title": "Sample Message Title",
                ],
                "sound": "default",
                "mutable-content": 1,
                "content-available": 1
            ],
            "clickUrl": "https://example.com/click-here",
            "imageUrl": "https://example.com/image.jpg",
            "payload": "{\"key\":\"value\"}",
            "buttons": [
                [
                    "text": "Button 1",
                    "url": "https://example.com/button-1",
                    "uniqueKey": "guid-for-button-1"
                ]
            ],
            "uniqueKey": "guid-for-message"
        ]
        
        XCTAssertFalse(validator.isValid(item: invalidNotification), "Validator should return false for an invalid notification")
    }
    
    func test_no_clickUrl_return_false() {
        let invalidNotification: [AnyHashable: Any] = [
            "aps": [
                "alert": [
                    "title": "Sample Message Title",
                    "body": "Sample Message Body"
                ],
                "sound": "default",
                "mutable-content": 1,
                "content-available": 1
            ],
            "imageUrl": "https://example.com/image.jpg",
            "payload": "{\"key\":\"value\"}",
            "buttons": [
                [
                    "text": "Button 1",
                    "url": "https://example.com/button-1",
                    "uniqueKey": "guid-for-button-1"
                ]
            ],
            "uniqueKey": "guid-for-message"
        ]
        
        XCTAssertFalse(validator.isValid(item: invalidNotification), "Validator should return false for an invalid notification")
    }
}
