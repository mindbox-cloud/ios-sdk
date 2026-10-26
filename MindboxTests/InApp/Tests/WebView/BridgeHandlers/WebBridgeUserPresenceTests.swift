//
//  WebBridgeUserPresenceTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 17.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
@_spi(Internal) @testable import Mindbox

@Suite("Bridge user presence", .tags(.webView))
struct WebBridgeUserPresenceTests {

    // MARK: - The vocabulary

    @Test("Acting on the user's behalf requires their presence",
          arguments: [BridgeMessage.Action.openLink,
                      .settingsOpen,
                      .permissionRequest,
                      .haptic,
                      .motionStart,
                      .showInApp])
    func userFacingActionsRequirePresence(action: BridgeMessage.Action) {
        #expect(action.requiresUserPresence)
    }

    @Test("Everything else runs off screen as before",
          arguments: [BridgeMessage.Action.ready,
                      .log,
                      .localStateGet,
                      .localStateSet,
                      .localStateInit,
                      .asyncOperation,
                      .syncOperation,
                      .contentRendered,
                      .filterShowableInapps,
                      .close,
                      .hide,
                      .click,
                      .motionStop])
    func otherActionsDoNotRequirePresence(action: BridgeMessage.Action) {
        #expect(!action.requiresUserPresence)
    }

    @Test("Motion can always be stopped, only started with a user there")
    func stoppingIsAlwaysAllowed() {
        #expect(BridgeMessage.Action.motionStart.requiresUserPresence)
        #expect(!BridgeMessage.Action.motionStop.requiresUserPresence)
    }

    // MARK: - The registry gate

    @Test("A user-facing action never reaches its handler off screen")
    func gatedActionIsNotDispatched() {
        let handler = PresenceHandlerSpy(actions: [.openLink])
        let registry = WebBridgeActionRegistry(handlers: [handler])
        let host = HostSpy()
        host.isUserPresent = false

        registry.handle(.request(.openLink), host: host)

        #expect(handler.handled.isEmpty)
    }

    @Test("The refused request is answered rather than dropped")
    func refusalIsAnswered() throws {
        let registry = WebBridgeActionRegistry(handlers: [PresenceHandlerSpy(actions: [.openLink])])
        let host = HostSpy()
        host.isUserPresent = false
        let message = BridgeMessage.request(.openLink)

        registry.handle(message, host: host)

        let response = try #require(host.sent.first)
        #expect(response.type == .error)
        #expect(response.id == message.id)
        #expect(response.action == BridgeMessage.Action.openLink.rawValue)
        #expect(response.payload == .object(["error": .string("not_visible")]))
    }

    @Test("Every user-facing action is refused off screen",
          arguments: [BridgeMessage.Action.openLink,
                      .settingsOpen,
                      .permissionRequest,
                      .haptic,
                      .motionStart,
                      .showInApp])
    func everyGatedActionIsRefused(action: BridgeMessage.Action) {
        let handler = PresenceHandlerSpy(actions: [action])
        let registry = WebBridgeActionRegistry(handlers: [handler])
        let host = HostSpy()
        host.isUserPresent = false

        registry.handle(.request(action), host: host)

        #expect(handler.handled.isEmpty)
        #expect(host.sent.first?.type == .error)
    }

    @Test("The same action goes through while the page is on screen")
    func gatedActionRunsWhenPresent() {
        let handler = PresenceHandlerSpy(actions: [.openLink])
        let registry = WebBridgeActionRegistry(handlers: [handler])
        let host = HostSpy()

        registry.handle(.request(.openLink), host: host)

        #expect(handler.handled.count == 1)
        #expect(host.sent.isEmpty, "the handler answers for itself, the gate has nothing to say")
    }

    @Test("An action that is nobody's business but the page's runs off screen",
          arguments: [BridgeMessage.Action.log, .asyncOperation, .contentRendered, .motionStop])
    func ungatedActionRunsWhenAbsent(action: BridgeMessage.Action) {
        let handler = PresenceHandlerSpy(actions: [action])
        let registry = WebBridgeActionRegistry(handlers: [handler])
        let host = HostSpy()
        host.isUserPresent = false

        registry.handle(.request(action), host: host)

        #expect(handler.handled.count == 1)
        #expect(host.sent.isEmpty)
    }

    @Test("A page that is always present is never refused",
          arguments: [BridgeMessage.Action.openLink, .haptic, .permissionRequest])
    func alwaysPresentHostIsNeverRefused(action: BridgeMessage.Action) {
        let handler = PresenceHandlerSpy(actions: [action])
        let registry = WebBridgeActionRegistry(handlers: [handler])

        registry.handle(.request(action), host: HostSpy())

        #expect(handler.handled.count == 1)
    }
}

// MARK: - Leaving the screen mid-request

@Suite("Bridge user presence, mid-request", .tags(.webView))
@MainActor
struct WebBridgeUserPresenceDuringRequestTests {

    @Test("A page that leaves the screen while the system decides gets no Safari")
    func presenceLostBeforeSafariFallback() async throws {
        let opener = DeferredURLOpenerSpy()
        let host = HostSpy()
        let handler = OpenLinkActionHandler(urlOpener: opener)

        handler.handle(.request(.openLink, payload: .object(["url": .string("https://example.com")])), host: host)
        await drainMainQueue(until: { !opener.opened.isEmpty })
        #expect(opener.opened.first?.universalLinksOnly == true, "the system is asked while the page is still up")

        host.isUserPresent = false
        opener.answer(opened: false)
        await drainMainQueue(until: { !host.sent.isEmpty })

        let response = try #require(host.sent.first)
        #expect(response.type == .error)
        #expect(response.payload == .object(["error": .string("not_visible")]))
        #expect(host.sent.count == 1)
    }

    @Test("A page that leaves the screen first is not offered to the system as a universal link")
    func universalLinkIsNotTriedAfterPresenceIsLost() async throws {
        let opener = URLOpenerSpy()
        let host = HostSpy()
        let handler = OpenLinkActionHandler(urlOpener: opener)

        handler.handle(.request(.openLink, payload: .object(["url": .string("https://example.com")])), host: host)
        host.isUserPresent = false
        await drainMainQueue(until: { !host.sent.isEmpty })

        #expect(opener.opened.isEmpty)
        let response = try #require(host.sent.first)
        #expect(response.type == .error)
        #expect(response.payload == .object(["error": .string("not_visible")]))
    }

    @Test("A page that leaves the screen first never reaches the system at all")
    func systemIsNotReachedAfterPresenceIsLost() async throws {
        let opener = URLOpenerSpy()
        let host = HostSpy()
        let handler = OpenLinkActionHandler(urlOpener: opener)

        handler.handle(.request(.openLink, payload: .object(["url": .string("tel:+123456789")])), host: host)
        host.isUserPresent = false
        await drainMainQueue(until: { !host.sent.isEmpty })

        #expect(opener.opened.isEmpty)
        let response = try #require(host.sent.first)
        #expect(response.type == .error)
        #expect(response.payload == .object(["error": .string("not_visible")]))
    }

    @Test("A page still on screen when the system answers is served")
    func presenceKeptThroughoutIsServed() async {
        let opener = URLOpenerSpy()
        opener.result = true
        let host = HostSpy()
        let handler = OpenLinkActionHandler(urlOpener: opener)

        handler.handle(.request(.openLink, payload: .object(["url": .string("https://example.com")])), host: host)
        await drainMainQueue(until: { !host.sent.isEmpty })

        #expect(host.sent.first?.type == .response)
    }
}

// MARK: - Doubles

private final class PresenceHandlerSpy: WebBridgeActionHandler {

    let actions: Set<BridgeMessage.Action>

    private(set) var handled: [BridgeMessage] = []

    init(actions: Set<BridgeMessage.Action>) {
        self.actions = actions
    }

    func handle(_ message: BridgeMessage, host: WebBridgeHost) {
        handled.append(message)
    }
}

private final class DeferredURLOpenerSpy: BridgeURLOpening {

    private(set) var opened: [(url: URL, universalLinksOnly: Bool)] = []

    private var pending: ((Bool) -> Void)?

    func open(_ url: URL, universalLinksOnly: Bool, completion: @escaping (Bool) -> Void) {
        opened.append((url, universalLinksOnly))
        pending = completion
    }

    func answer(opened: Bool) {
        let completion = pending
        pending = nil
        completion?(opened)
    }
}
