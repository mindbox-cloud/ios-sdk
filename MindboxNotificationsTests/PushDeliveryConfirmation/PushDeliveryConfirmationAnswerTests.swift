//
//  PushDeliveryConfirmationAnswerTests.swift
//  MindboxNotificationsTests
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
@_spi(Internal) @testable import MindboxNotifications

@Suite("Push delivery confirmation: the answer to a status code", .tags(.notifications, .pushDeliveryConfirmation))
struct PushDeliveryConfirmationAnswerTests {

    @Test("The status code decides the answer", arguments: [
        (200, PushDeliveryConfirmationAnswer.delivered), (204, .delivered),
        (300, .rejected), (302, .rejected), (400, .rejected), (404, .rejected), (499, .rejected),
        (429, .throttled),
        (500, .failed), (503, .failed)
    ])
    func answer(code: Int, expected: PushDeliveryConfirmationAnswer) {
        #expect(PushDeliveryConfirmationAnswer(statusCode: code) == expected)
    }

    @Test("No status code is a failure")
    func noStatusCode() {
        #expect(PushDeliveryConfirmationAnswer(statusCode: nil) == .failed)
    }
}
