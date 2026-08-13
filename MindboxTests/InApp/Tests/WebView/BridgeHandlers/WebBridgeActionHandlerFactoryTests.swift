//
//  WebBridgeActionHandlerFactoryTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
@_spi(Internal) @testable import Mindbox

/// Guards the one thing no other suite can see: that the shipped handler set is complete.
///
/// Every other suite either builds a handler directly or injects a registry of its own, so a
/// handler written, tested and then left out of the factory would pass all of them while the
/// action silently did nothing in the app — and for a deferred action, "nothing" means the page
/// waits for an answer that never comes.
@Suite("WebBridgeActionHandlerFactory", .tags(.webView))
struct WebBridgeActionHandlerFactoryTests {

    /// Actions the registry is not meant to own: both travel native → JS and never arrive as
    /// a request.
    private static let notOwnedByRegistry: Set<BridgeMessage.Action> = [
        .navigationIntercepted,
        .motionEvent
    ]

    @Test("Every action a page can send has an owner in the shipped set")
    func everyIncomingActionIsOwned() {
        let owned = WebBridgeActionHandlerFactory.makeHandlers().reduce(into: Set<BridgeMessage.Action>()) {
            $0.formUnion($1.actions)
        }

        let expected = Set(BridgeMessage.Action.allCases).subtracting(Self.notOwnedByRegistry)

        #expect(expected.subtracting(owned).isEmpty, "actions with no handler in the shipped set")
    }

    @Test("The shipped set claims nothing that travels native to JS")
    func claimsNothingOutgoing() {
        let owned = WebBridgeActionHandlerFactory.makeHandlers().reduce(into: Set<BridgeMessage.Action>()) {
            $0.formUnion($1.actions)
        }

        #expect(owned.isDisjoint(with: [.navigationIntercepted, .motionEvent]))
    }

    /// Two handlers claiming one action is resolved by the registry, but silently — the set
    /// itself should not contain the collision in the first place.
    @Test("No action is claimed twice")
    func noActionIsClaimedTwice() {
        let handlers = WebBridgeActionHandlerFactory.makeHandlers()
        let claims = handlers.flatMap(\.actions)

        #expect(claims.count == Set(claims).count)
    }

    /// Several handlers own state that belongs to one page — a prepared haptic engine, a motion
    /// subscription — so a set shared between shows would leak one page's devices into another.
    @Test("Each call builds a fresh set")
    func buildsFreshInstances() {
        let first = WebBridgeActionHandlerFactory.makeHandlers()
        let second = WebBridgeActionHandlerFactory.makeHandlers()

        #expect(first.count == second.count)
        for (lhs, rhs) in zip(first, second) {
            #expect(lhs !== rhs)
        }
    }
}
