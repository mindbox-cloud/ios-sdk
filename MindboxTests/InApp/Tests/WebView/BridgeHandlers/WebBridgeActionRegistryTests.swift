//
//  WebBridgeActionRegistryTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
@_spi(Internal) @testable import Mindbox

@Suite("WebBridgeActionRegistry", .tags(.webView))
struct WebBridgeActionRegistryTests {

    // MARK: - Routing

    @Test("Routes a request to the handler that owns its action")
    func routesToOwner() {
        let log = HandlerSpy(actions: [.log])
        let haptic = HandlerSpy(actions: [.haptic])
        let registry = WebBridgeActionRegistry(handlers: [log, haptic])
        let message = BridgeMessage.request(.haptic)

        registry.handle(message, host: HostSpy())

        #expect(haptic.handled.map(\.id) == [message.id])
        #expect(log.handled.isEmpty)
    }

    @Test("A handler owning several actions receives all of them")
    func routesEveryOwnedAction() {
        let localState = HandlerSpy(actions: [.localStateGet, .localStateSet, .localStateInit])
        let registry = WebBridgeActionRegistry(handlers: [localState])
        let host = HostSpy()

        registry.handle(BridgeMessage.request(.localStateGet), host: host)
        registry.handle(BridgeMessage.request(.localStateSet), host: host)
        registry.handle(BridgeMessage.request(.localStateInit), host: host)

        #expect(localState.handled.count == 3)
    }

    @Test("A known action nobody owns is refused as not served")
    func refusesUnownedAction() throws {
        let registry = WebBridgeActionRegistry(handlers: [HandlerSpy(actions: [.log])])
        let host = HostSpy()
        let message = BridgeMessage.request(.haptic)

        registry.handle(message, host: host)

        #expect(host.sent.count == 1)
        let response = try #require(host.sent.first)
        #expect(response.type == .error)
        #expect(response.id == message.id)
        #expect(response.action == message.action)
        #expect(response.payload == .object(["error": .string("not_served")]))
    }

    @Test("An action outside the known vocabulary is not refused a second time")
    func unknownActionIsNotRefusedTwice() {
        let registry = WebBridgeActionRegistry(handlers: [HandlerSpy(actions: [.log])])
        let host = HostSpy()
        let message = BridgeMessage(type: .request, action: "someFutureAction", payload: nil)

        registry.handle(message, host: host)

        #expect(host.sent.isEmpty)
    }

    @Test("When two handlers claim one action, the first keeps it")
    func firstClaimWins() {
        let first = HandlerSpy(actions: [.log])
        let second = HandlerSpy(actions: [.log])
        let registry = WebBridgeActionRegistry(handlers: [first, second])

        registry.handle(BridgeMessage.request(.log), host: HostSpy())

        #expect(first.handled.count == 1)
        #expect(second.handled.isEmpty)
    }

    // MARK: - Requests only

    /// Both kinds in one test rather than as arguments: `MessageType` does not cross into a test
    /// as a parameter under the Swift 6 language mode.
    @Test("Anything that is not a request is swallowed without an answer")
    func nonRequestIsSwallowed() {
        let motion = HandlerSpy(actions: [.motionStart])
        let registry = WebBridgeActionRegistry(handlers: [motion])
        let host = HostSpy()
        let event = BridgeMessage.Action.motionEvent.rawValue

        registry.handle(BridgeMessage(type: .response, action: event, payload: nil), host: host)
        registry.handle(BridgeMessage(type: .error, action: event, payload: nil), host: host)

        #expect(motion.handled.isEmpty)
        #expect(host.sent.isEmpty)
    }

    /// The handler contract is "requests only", so an answer that happens to carry an owned action
    /// must not run it a second time — the request it answers has already been through here.
    @Test("A response carrying an owned action does not reach that handler")
    func responseWithOwnedActionIsNotRouted() {
        let openLink = HandlerSpy(actions: [.openLink])
        let registry = WebBridgeActionRegistry(handlers: [openLink])
        let host = HostSpy()
        host.isUserPresent = false

        registry.handle(BridgeMessage(type: .response,
                                      action: BridgeMessage.Action.openLink.rawValue,
                                      payload: nil),
                        host: host)

        #expect(openLink.handled.isEmpty)
        #expect(host.sent.isEmpty, "the presence gate answers requests, and this is not one")
    }

    // MARK: - Session teardown

    @Test("Teardown reaches every handler, including ones that never handled anything")
    func tearDownReachesEveryHandler() {
        let used = HandlerSpy(actions: [.log])
        let idle = HandlerSpy(actions: [.haptic])
        let registry = WebBridgeActionRegistry(handlers: [used, idle])
        registry.handle(BridgeMessage.request(.log), host: HostSpy())

        registry.tearDown()

        #expect(used.tearDownCount == 1)
        #expect(idle.tearDownCount == 1)
    }

    // MARK: - Out-of-band lookup

    @Test("A handler can be found by type for events that arrive outside a request")
    func findsHandlerByType() {
        let registry = WebBridgeActionRegistry(handlers: [HandlerSpy(actions: [.log]), OtherHandlerSpy()])

        #expect(registry.handler(ofType: OtherHandlerSpy.self) != nil)
    }

    @Test("Looking up a type that was never registered returns nothing")
    func missingHandlerTypeIsNil() {
        let registry = WebBridgeActionRegistry(handlers: [HandlerSpy(actions: [.log])])

        #expect(registry.handler(ofType: OtherHandlerSpy.self) == nil)
    }
}

// MARK: - Doubles

private final class HandlerSpy: WebBridgeActionHandler {

    let actions: Set<BridgeMessage.Action>

    private(set) var handled: [BridgeMessage] = []
    private(set) var tearDownCount = 0

    init(actions: Set<BridgeMessage.Action>) {
        self.actions = actions
    }

    func handle(_ message: BridgeMessage, host: WebBridgeHost) {
        handled.append(message)
    }

    func tearDown() {
        tearDownCount += 1
    }
}

/// A second concrete type, so `handler(ofType:)` has something to tell apart from `HandlerSpy`.
private final class OtherHandlerSpy: WebBridgeActionHandler {

    let actions: Set<BridgeMessage.Action> = [.motionStart]

    func handle(_ message: BridgeMessage, host: WebBridgeHost) {}
}
