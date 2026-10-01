//
//  BridgeMessageActionWireNamesTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 8/18/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
@_spi(Internal) @testable import Mindbox

@Suite("Bridge wire names: actions and error codes", .tags(.webView))
struct BridgeMessageActionWireNamesTests {

    // These strings are the contract with the pages already shipped: every other suite builds and
    // reads messages through the enum, so a renamed raw value round-trips and stays green here
    // while the page stops recognising the action.
    @Test("A dotted action keeps the wire name the page sends", arguments: [
        (BridgeMessage.Action.localStateGet, "localState.get"),
        (BridgeMessage.Action.localStateSet, "localState.set"),
        (BridgeMessage.Action.localStateInit, "localState.init"),
        (BridgeMessage.Action.localStateChanged, "localState.changed"),
        (BridgeMessage.Action.settingsOpen, "settings.open"),
        (BridgeMessage.Action.permissionRequest, "permission.request"),
        (BridgeMessage.Action.motionStart, "motion.start"),
        (BridgeMessage.Action.motionStop, "motion.stop"),
        (BridgeMessage.Action.motionEvent, "motion.event")
    ])
    func dottedActionKeepsItsWireName(action: BridgeMessage.Action, wireName: String) {
        #expect(action.rawValue == wireName)
        #expect(BridgeMessage.Action(rawValue: wireName) == action)
    }

    @Test("The error codes keep the contract's wire values in the contract's order")
    func errorCodesKeepTheirWireValues() {
        #expect(BridgeErrorCode.allCases.map(\.rawValue) == [
            "unknown_action",
            "not_served",
            "not_visible",
            "invalid_payload",
            "unsupported_value",
            "invalid_url",
            "blocked_scheme",
            "open_failed",
            "permission_failed",
            "gestures_unavailable",
            "operation_failed",
            "unknown_inapp",
            "show_failed",
            "internal_error"
        ])
    }
}
