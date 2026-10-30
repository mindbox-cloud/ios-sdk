//
//  LogActionHandler.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

final class LogActionHandler: WebBridgeActionHandler {

    let actions: Set<BridgeMessage.Action> = [.log]

    func handle(_ message: BridgeMessage, host: WebBridgeHost) {
        host.respondSuccess(to: message)
        Logger.common(message: "[JS] \(message.payloadString)", category: host.logCategory)
    }
}
