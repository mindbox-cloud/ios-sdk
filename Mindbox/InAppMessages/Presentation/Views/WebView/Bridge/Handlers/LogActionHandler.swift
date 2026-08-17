//
//  LogActionHandler.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

/// Writes what the page says into the SDK log.
///
/// The category comes from the host rather than from here: the same handler serves an in-app
/// popup and an embedded block, and each keeps its own trail. That is the whole reason a
/// handler is given a host instead of being told which surface it is on.
final class LogActionHandler: WebBridgeActionHandler {

    let actions: Set<BridgeMessage.Action> = [.log]

    func handle(_ message: BridgeMessage, host: WebBridgeHost) {
        // `log` is not deferred: `RequestMessageHandler` has already answered `{success: true}`.
        // Answering again would arrive against an id JS has closed.
        Logger.common(message: "[JS] \(message.payloadString)", category: host.logCategory)
    }
}
