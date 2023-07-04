//
//  InAppMessagesDelegateTests.swift
//  MindboxTests
//
//  Created by vailence on 04.07.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

class InAppMessagesDelegateTests: XCTestCase {
    func testCopyInappMessageHandlerCopiesPayloadToPasteboard() {
        let fakePasteboard = MockPasteboard()
        let handler = CopyInappMessageHandler(pasteboard: fakePasteboard)

        let payload = "Test payload"
        handler.inAppMessageTapAction(id: "test", url: nil, payload: payload)

        XCTAssertEqual(fakePasteboard.copiedString, payload)
    }
}
