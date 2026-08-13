//
//  LifecycleActionHandler.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

/// What a page says about its own life: it booted, it was tapped, it wants to be hidden or
/// closed.
///
/// Registered everywhere, like every other handler. Whether these mean anything depends on who
/// is hosting the page — a surface that has no window to close simply does not conform, and the
/// message is journalled and dropped rather than refused. That is what lets a surface pick one
/// of these up later by adding a conformance and nothing else.
final class LifecycleActionHandler: WebBridgeActionHandler {

    let actions: Set<BridgeMessage.Action> = [.close, .`init`, .click, .hide]

    func handle(_ message: BridgeMessage, host: WebBridgeHost) {
        // None of these are deferred: `RequestMessageHandler` has already answered
        // `{success: true}`, so this handler only acts and never replies.
        guard let lifecycle = host as? WebBridgeLifecycleHosting else {
            Logger.common(message: "[WebView] Bridge: '\(message.action)' from '\(host.contentId)' has no lifecycle to reach here, ignoring",
                          category: host.logCategory)
            return
        }

        switch message.parsedAction {
        case .`init`:
            lifecycle.bridgeDidInit()
        case .close:
            lifecycle.bridgeDidRequestClose()
        case .hide:
            lifecycle.bridgeDidRequestHide()
        case .click:
            // Forwarded verbatim: what a tap means is decided above the bridge.
            lifecycle.bridgeDidClick(rawPayload: message.payloadString)
        default:
            // Unreachable: the registry routes only what `actions` claims.
            break
        }
    }
}
