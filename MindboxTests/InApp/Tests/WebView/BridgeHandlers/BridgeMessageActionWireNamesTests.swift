//
//  BridgeMessageActionWireNamesTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 8/18/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
@_spi(Internal) @testable import Mindbox

@Suite("BridgeMessage action wire names", .tags(.webView))
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
}
