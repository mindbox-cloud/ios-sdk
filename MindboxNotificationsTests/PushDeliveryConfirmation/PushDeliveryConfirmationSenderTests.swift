//
//  PushDeliveryConfirmationSenderTests.swift
//  MindboxNotificationsTests
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
@_spi(Internal) @testable import MindboxNotifications

@Suite("Push delivery confirmation: sending", .tags(.notifications, .deliveryConfirmation))
struct PushDeliveryConfirmationSenderTests {

    private static let receivedAt = Date(timeIntervalSince1970: 1_800_000_000)

    private static func confirmation(host: String) -> PushDeliveryConfirmation {
        PushDeliveryConfirmation(url: URL(string: "https://\(host)/delivered?token=abc")!, receivedAt: receivedAt)
    }

    private func send(
        answer: PushDeliveryConfirmationStub.Answer,
        timeout: TimeInterval = 5
    ) async -> (outcome: PushDeliveryConfirmationOutcome, host: String) {
        let host = PushDeliveryConfirmationStub.makeHost(answer: answer)
        let outcome = await PushDeliveryConfirmationStub.sender(timeout: timeout)
            .send(Self.confirmation(host: host), sentAt: Self.receivedAt.addingTimeInterval(2))
        return (outcome, host)
    }

    @Test("2xx means delivered", arguments: [200, 201, 204])
    func successIsDelivered(code: Int) async {
        #expect(await send(answer: .status(code)).outcome == .delivered)
    }

    @Test("4xx other than 429 means refused", arguments: [400, 401, 403, 404, 410])
    func clientErrorIsRejected(code: Int) async {
        #expect(await send(answer: .status(code)).outcome == .rejected(statusCode: code))
    }

    @Test("429 means throttled")
    func tooManyRequestsIsThrottled() async {
        #expect(await send(answer: .status(429)).outcome == .throttled)
    }

    @Test("5xx means failed", arguments: [500, 502, 503, 504])
    func serverErrorIsFailed(code: Int) async {
        #expect(await send(answer: .status(code)).outcome == .failed(statusCode: code))
    }

    @Test("No connection means failed without a status")
    func connectionErrorIsFailed() async {
        #expect(await send(answer: .failure(URLError(.notConnectedToInternet))).outcome == .failed(statusCode: nil))
    }

    @Test("No answer within the timeout means failed without a status")
    func timeoutIsFailed() async {
        let started = Date()
        #expect(await send(answer: .silence, timeout: 0.5).outcome == .failed(statusCode: nil))
        #expect(Date().timeIntervalSince(started) < 4)
    }

    @Test("A redirect is not followed and counts as failed")
    func redirectIsNotFollowed() async {
        let other = PushDeliveryConfirmationStub.makeHost(answer: .status(200))
        let result = await send(answer: .status(302, headers: ["Location": "https://\(other)/"]))

        #expect(result.outcome == .failed(statusCode: 302))
        #expect(PushDeliveryConfirmationStub.requests(to: result.host).count == 1)
        #expect(PushDeliveryConfirmationStub.requests(to: other).isEmpty)
    }

    @Test("One POST goes to the URL from the push with dateTimeOffset")
    func sendsOnePost() async throws {
        let host = await send(answer: .status(500)).host

        let requests = PushDeliveryConfirmationStub.requests(to: host)
        #expect(requests.count == 1)
        let request = try #require(requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://\(host)/delivered?token=abc&dateTimeOffset=2000")
    }

    @Test("Only a delivery or a refusal ends the confirmation")
    func finalOutcomes() {
        #expect(PushDeliveryConfirmationOutcome.delivered.isFinal)
        #expect(PushDeliveryConfirmationOutcome.rejected(statusCode: 404).isFinal)
        #expect(!PushDeliveryConfirmationOutcome.throttled.isFinal)
        #expect(!PushDeliveryConfirmationOutcome.failed(statusCode: 500).isFinal)
        #expect(!PushDeliveryConfirmationOutcome.failed(statusCode: nil).isFinal)
    }
}
