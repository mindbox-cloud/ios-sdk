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

        let didHandle = registry.handle(message, host: HostSpy())

        #expect(didHandle)
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

    @Test("Reports an unowned action instead of swallowing it")
    func reportsUnownedAction() {
        let registry = WebBridgeActionRegistry(handlers: [HandlerSpy(actions: [.log])])

        let didHandle = registry.handle(BridgeMessage.request(.haptic), host: HostSpy())

        #expect(!didHandle)
    }

    @Test("An action outside the known vocabulary is not handled")
    func reportsUnknownAction() {
        let registry = WebBridgeActionRegistry(handlers: [HandlerSpy(actions: [.log])])
        let message = BridgeMessage(type: .request, action: "someFutureAction", payload: nil)

        let didHandle = registry.handle(message, host: HostSpy())

        #expect(!didHandle)
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
