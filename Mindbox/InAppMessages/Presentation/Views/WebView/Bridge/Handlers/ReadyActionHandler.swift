//
//  ReadyActionHandler.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

final class ReadyActionHandler: WebBridgeActionHandler {

    let actions: Set<BridgeMessage.Action> = [.ready]

    func handle(_ message: BridgeMessage, host: WebBridgeHost) {
        host.makeStartPayload { [weak host] payload in
            host?.respond(to: message, payload: payload)
        }
    }
}
