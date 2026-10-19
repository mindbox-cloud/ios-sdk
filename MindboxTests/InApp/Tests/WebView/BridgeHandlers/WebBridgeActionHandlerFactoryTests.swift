//
//  WebBridgeActionHandlerFactoryTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
@_spi(Internal) @testable import Mindbox

@Suite("WebBridgeActionHandlerFactory", .tags(.webView))
struct WebBridgeActionHandlerFactoryTests {

    private static let requestedOnlyBySDK: Set<BridgeMessage.Action> = [
        .navigationIntercepted,
        .motionEvent,
        .initDataUpdated,
        .localStateChanged
    ]

    @Test("Every action a page can send has an owner in the shipped set")
    func everyIncomingActionIsOwned() {
        let owned = WebBridgeActionHandlerFactory.makeHandlers().reduce(into: Set<BridgeMessage.Action>()) {
            $0.formUnion($1.actions)
        }

        let expected = Set(BridgeMessage.Action.allCases).subtracting(Self.requestedOnlyBySDK)

        #expect(expected.subtracting(owned).isEmpty, "actions with no handler in the shipped set")
    }

    @Test("The shipped set claims nothing that travels native to JS")
    func claimsNothingOutgoing() {
        let owned = WebBridgeActionHandlerFactory.makeHandlers().reduce(into: Set<BridgeMessage.Action>()) {
            $0.formUnion($1.actions)
        }

        #expect(owned.isDisjoint(with: Self.requestedOnlyBySDK))
    }

    @Test("No action is claimed twice")
    func noActionIsClaimedTwice() {
        let handlers = WebBridgeActionHandlerFactory.makeHandlers()
        let claims = handlers.flatMap(\.actions)

        #expect(claims.count == Set(claims).count)
    }

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
