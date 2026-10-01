//
//  LifecycleActionHandlerTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import UIKit
import MindboxLogger
@_spi(Internal) @testable import Mindbox

@Suite("LifecycleActionHandler", .tags(.webView))
struct LifecycleActionHandlerTests {

    @Test("Owns the four lifecycle actions")
    func ownsLifecycleActions() {
        #expect(LifecycleActionHandler().actions == [.close, .`init`, .click, .hide])
    }

    @Test("Each action is answered first, then reaches its own callback", arguments: [
        (BridgeMessage.Action.`init`, "init"),
        (.close, "close"),
        (.hide, "hide"),
        (.click, "click")
    ])
    func actionIsAnsweredThenReachesItsCallback(action: BridgeMessage.Action, expected: String) {
        let host = LifecycleHostSpy()

        LifecycleActionHandler().handle(.request(action), host: host)

        #expect(host.events == ["answered", expected])
    }

    /// What a tap means is decided above the bridge, so the payload travels untouched.
    @Test("A click forwards its payload verbatim")
    func clickForwardsPayload() {
        let host = LifecycleHostSpy()
        let payload = #"{"$type":"redirectUrl","value":"https://example.com"}"#

        LifecycleActionHandler().handle(.request(.click, payload: .string(payload)), host: host)

        #expect(host.clickPayloads == [payload])
    }

    @Test("Answers exactly one success, whatever the action",
          arguments: [BridgeMessage.Action.`init`, .close, .hide, .click])
    func answersExactlyOneSuccess(action: BridgeMessage.Action) throws {
        let host = LifecycleHostSpy()
        let message = BridgeMessage.request(action)

        LifecycleActionHandler().handle(message, host: host)

        #expect(host.sent.count == 1)
        let response = try #require(host.sent.first)
        #expect(response.type == .response)
        #expect(response.id == message.id)
        #expect(response.payload == .object(["success": .bool(true)]))
    }

    @Test("A host without the capability is answered success instead of failing",
          arguments: [BridgeMessage.Action.`init`, .close, .hide, .click])
    func hostWithoutCapabilityIsAnsweredSuccess(action: BridgeMessage.Action) throws {
        let host = HostSpy()

        LifecycleActionHandler().handle(.request(action), host: host)

        #expect(host.sent.count == 1)
        let response = try #require(host.sent.first)
        #expect(response.type == .response)
        #expect(response.payload == .object(["success": .bool(true)]))
    }
}

// MARK: - Doubles

/// A page that also steers its own life.
private final class LifecycleHostSpy: WebBridgeHost, WebBridgeLifecycleHosting {

    var contentId = "test-content-id"
    var logCategory: LogCategory = .webViewInAppMessages
    var tags: [String: String]?
    var presentingViewController: UIViewController? { nil }
    var isUserPresent = true

    private(set) var sent: [BridgeMessage] = []
    private(set) var events: [String] = []
    private(set) var clickPayloads: [String] = []

    func send(_ message: BridgeMessage) {
        sent.append(message)
        events.append("answered")
    }

    func makeStartPayload(_ completion: @escaping (JSONValue) -> Void) {
        completion(.string("{}"))
    }

    func bridgeDidInit() {
        events.append("init")
    }

    func bridgeDidRequestClose() {
        events.append("close")
    }

    func bridgeDidRequestHide() {
        events.append("hide")
    }

    func bridgeDidClick(rawPayload: String) {
        events.append("click")
        clickPayloads.append(rawPayload)
    }
}
