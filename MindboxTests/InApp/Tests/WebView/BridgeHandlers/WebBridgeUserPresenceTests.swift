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

/// A page nobody is looking at must not act on the user's behalf.
///
/// An embedded block that left the window keeps its page alive, and that page still delivers
/// whatever its `setTimeout` scheduled. These suites pin down what that costs it: which actions
/// are refused, that the refusal reaches the page as an answer rather than as silence, and that
/// leaving the screen mid-request stops the action too.
@Suite("Bridge user presence", .tags(.webView))
struct WebBridgeUserPresenceTests {

    // MARK: - The vocabulary

    /// Leaving the app, covering it, or reaching for the device — none of it has a touch behind
    /// it once the page is off screen.
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

    /// Bookkeeping the page does about itself. A block goes on reporting, logging and sending its
    /// operations off screen exactly as it did before the shared bridge — none of it is something
    /// done on the user's behalf.
    @Test("Everything else runs off screen as before",
          arguments: [BridgeMessage.Action.ready,
                      .log,
                      .localStateGet,
                      .localStateSet,
                      .localStateInit,
                      .asyncOperation,
                      .syncOperation,
                      .contentRendered,
                      .checkInappsTargeting,
                      .close,
                      .hide,
                      .click,
                      .motionStop])
    func otherActionsDoNotRequirePresence(action: BridgeMessage.Action) {
        #expect(!action.requiresUserPresence)
    }

    /// Giving the sensors back is not something done on the user's behalf, and a page that left
    /// the screen is exactly the page that should be able to release them.
    @Test("Motion can always be stopped, only started with a user there")
    func stoppingIsAlwaysAllowed() {
        #expect(BridgeMessage.Action.motionStart.requiresUserPresence)
        #expect(!BridgeMessage.Action.motionStop.requiresUserPresence)
    }

    /// The refusal travels as the answer to the request. An action already answered
    /// `{success: true}` by the dispatcher has no answer left to spend on it, so the two sets
    /// cannot drift apart.
    @Test("Every action that requires presence answers for itself")
    func presenceGatedActionsAreDeferred() {
        let gated = BridgeMessage.Action.allCases.filter(\.requiresUserPresence)
        let everyGatedActionAnswersForItself = gated.allSatisfy(\.isDeferred)

        #expect(!gated.isEmpty)
        #expect(everyGatedActionAnswersForItself)
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

    /// The page is waiting on a promise. Dropping the request would leave it waiting forever, so
    /// the refusal is spent as its answer.
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
    }

    /// The action is owned — it was refused, not unrecognised. Reporting it as unhandled would
    /// send the page's host looking for a handler that is right there.
    @Test("A refusal still counts as handled")
    func refusalCountsAsHandled() {
        let registry = WebBridgeActionRegistry(handlers: [PresenceHandlerSpy(actions: [.openLink])])
        let host = HostSpy()
        host.isUserPresent = false

        #expect(registry.handle(.request(.openLink), host: host))
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

    /// A modal in-app has no off-screen life in which its page could keep talking, so nothing here
    /// costs it anything.
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

/// The gate before dispatch is not enough on its own: the system takes its own time to decide a
/// link is nobody's, and the block can be scrolled away while it does. A sheet put up after that
/// covers a screen the user chose themselves.
@Suite("Bridge user presence, mid-request", .tags(.webView))
@MainActor
struct WebBridgeUserPresenceDuringRequestTests {

    /// The one the gate before dispatch cannot catch: the page is on screen when the system is
    /// asked, and gone by the time it answers. Told apart from the ordinary refusal by the reason —
    /// the spy page owns no controller, so a fallback that got past the gate would fail on the
    /// missing presenter instead.
    @Test("A page that leaves the screen while the system decides gets no Safari")
    func presenceLostBeforeSafariFallback() async throws {
        let opener = DeferredURLOpenerSpy()
        let host = HostSpy()
        let handler = OpenLinkActionHandler(urlOpener: opener)

        handler.handle(.request(.openLink, payload: .object(["url": .string("https://example.com")])), host: host)
        await drainMainQueue(until: { !opener.opened.isEmpty })
        #expect(opener.opened.first?.universalLinksOnly == true, "the system is asked while the page is still up")

        host.isUserPresent = false
        // Nobody claims the link, which is what sends the handler to the Safari sheet.
        opener.answer(opened: false)
        await drainMainQueue(until: { !host.sent.isEmpty })

        let response = try #require(host.sent.first)
        #expect(response.type == .error)
        #expect(response.payload == .object(["error": .string("Nobody is looking at this page")]))
        #expect(host.sent.count == 1)
    }

    /// A web address is offered to the system a main-queue turn after the request arrives, and
    /// that turn is enough for the block to leave the window.
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
        #expect(response.payload == .object(["error": .string("Nobody is looking at this page")]))
    }

    /// The same turn on the route every other scheme takes, and the one `settings.open` shares.
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
        #expect(response.payload == .object(["error": .string("Nobody is looking at this page")]))
    }

    /// The whole point of asking again is that the answer may have changed. A page still on screen
    /// when the system comes back is opened for, exactly as before.
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

/// Records what it was given, so a suite can tell "the handler refused" from "the handler was
/// never reached".
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

/// Holds the system's answer back until the test hands it over.
///
/// The only way to stand a page down *between* asking the system and hearing from it — which is
/// the window the gate before dispatch cannot see. `URLOpenerSpy` answers on the spot and leaves
/// no such window.
private final class DeferredURLOpenerSpy: BridgeURLOpening {

    private(set) var opened: [(url: URL, universalLinksOnly: Bool)] = []

    private var pending: ((Bool) -> Void)?

    func open(_ url: URL, universalLinksOnly: Bool, completion: @escaping (Bool) -> Void) {
        opened.append((url, universalLinksOnly))
        pending = completion
    }

    /// - Parameter opened: what the system decided about the last URL it was given.
    func answer(opened: Bool) {
        let completion = pending
        pending = nil
        completion?(opened)
    }
}
