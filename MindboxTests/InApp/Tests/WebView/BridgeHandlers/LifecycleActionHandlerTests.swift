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

    @Test("Each action reaches its own callback", arguments: [
        (BridgeMessage.Action.`init`, "init"),
        (.close, "close"),
        (.hide, "hide")
    ])
    func actionReachesItsCallback(action: BridgeMessage.Action, expected: String) {
        let host = LifecycleHostSpy()

        LifecycleActionHandler().handle(.request(action), host: host)

        #expect(host.events == [expected])
    }

    /// What a tap means is decided above the bridge, so the payload travels untouched.
    @Test("A click forwards its payload verbatim")
    func clickForwardsPayload() {
        let host = LifecycleHostSpy()
        let payload = #"{"$type":"redirectUrl","value":"https://example.com"}"#

        LifecycleActionHandler().handle(.request(.click, payload: .string(payload)), host: host)

        #expect(host.events == ["click"])
        #expect(host.clickPayloads == [payload])
    }

    /// None of the four is deferred, so the dispatcher has already answered. Answering again
    /// would arrive against an id JS has closed.
    @Test("Never answers, whatever the action")
    func neverAnswers() {
        let host = LifecycleHostSpy()

        for action in [BridgeMessage.Action.`init`, .close, .hide, .click] {
            LifecycleActionHandler().handle(.request(action), host: host)
        }

        #expect(host.sent.isEmpty)
    }

    /// The point of the capability design: a page may speak the whole vocabulary wherever it
    /// lives, and a surface with no window to close simply does not listen. Not an error —
    /// the day such a surface wants these, it conforms and nothing else changes.
    @Test("A host without the capability drops the action instead of failing")
    func hostWithoutCapabilityIgnoresAction() {
        let host = HostSpy()

        LifecycleActionHandler().handle(.request(.close), host: host)

        #expect(host.sent.isEmpty)
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
