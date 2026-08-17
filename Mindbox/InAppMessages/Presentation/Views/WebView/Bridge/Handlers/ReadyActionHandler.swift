//
//  ReadyActionHandler.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

/// The page reports it can receive messages, and is answered with what it needs to configure
/// itself.
///
/// Deferred, and deliberately so: the blanket `{success: true}` would tell the page nothing,
/// and this is the one answer it cannot start without.
///
/// What goes into the payload belongs to the host — an in-app knows its operation, a block
/// knows its configuration entry — so this handler only decides *when* to answer, never *with
/// what*.
final class ReadyActionHandler: WebBridgeActionHandler {

    let actions: Set<BridgeMessage.Action> = [.ready]

    func handle(_ message: BridgeMessage, host: WebBridgeHost) {
        host.respond(to: message, payload: host.makeStartPayload())
    }
}
