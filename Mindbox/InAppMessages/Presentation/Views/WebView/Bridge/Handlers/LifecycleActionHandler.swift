//
//  LifecycleActionHandler.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

final class LifecycleActionHandler: WebBridgeActionHandler {

    let actions: Set<BridgeMessage.Action> = [.close, .`init`, .click, .hide]

    func handle(_ message: BridgeMessage, host: WebBridgeHost) {
        host.respondSuccess(to: message)

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
            lifecycle.bridgeDidClick(rawPayload: message.payloadString)
        default:
            break
        }
    }
}
