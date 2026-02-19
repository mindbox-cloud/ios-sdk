//
//  BridgeMessageDispatcher.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 28.01.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

protocol BridgeMessageHandler {
    func canHandle(_ message: BridgeMessage) -> Bool
    func handle(_ message: BridgeMessage, bridge: MindboxWebBridge, pending: BridgePendingStore)
}

final class BridgeMessageDispatcher {

    private let handlers: [BridgeMessageHandler]

    init(handlers: [BridgeMessageHandler]) {
        self.handlers = handlers
    }

    func dispatch(_ message: BridgeMessage, in bridge: MindboxWebBridge) {
        for handler in handlers where handler.canHandle(message) {
            handler.handle(message, bridge: bridge, pending: bridge)
            return
        }

        Logger.common(
            message: "[WebView] Bridge: unhandled message type \(message.type.rawValue)",
            category: .webViewInAppMessages
        )
    }
}

final class RequestMessageHandler: BridgeMessageHandler {

    func canHandle(_ message: BridgeMessage) -> Bool {
        message.type == .request
    }

    func handle(_ message: BridgeMessage,
                bridge: MindboxWebBridge,
                pending: BridgePendingStore) {

        pending.addPending(message.id)

        let requestLogMessage = "[WebView] Bridge: handling request id \(message.id). " +
            "message: version=\(message.version) type=\(message.type.rawValue) " +
            "action=\(message.action) payload=\(String(describing: message.payloadAny)) " +
            "timestamp=\(message.timestamp)"
        Logger.common(
            message: requestLogMessage,
            category: .webViewInAppMessages
        )

        if !BridgeMessage.Action.deferredActions.contains(message.action) {
            let response = BridgeMessage(
                type: .response,
                action: message.action,
                payload: .object(["success": .bool(true)]),
                id: message.id
            )

            bridge.send(response)
        }

        bridge.messageDelegate?.webBridge(bridge, didReceiveBridgeMessage: message)
    }
}

final class ResponseMessageHandler: BridgeMessageHandler {

    func canHandle(_ message: BridgeMessage) -> Bool {
        message.type == .response
    }

    func handle(_ message: BridgeMessage,
                bridge: MindboxWebBridge,
                pending: BridgePendingStore) {

        if pending.containsPending(message.id) {
            pending.removePending(message.id)

            let responseLogMessage = "[WebView] Bridge: handling response id \(message.id) - matched pending request. " +
                "message: version=\(message.version) type=\(message.type.rawValue) " +
                "action=\(message.action) payload=\(String(describing: message.payloadAny)) " +
                "timestamp=\(message.timestamp)"
            Logger.common(
                message: responseLogMessage,
                category: .webViewInAppMessages
            )

            bridge.messageDelegate?.webBridge(bridge, didReceiveBridgeMessage: message)
        } else {
            let responseLogMessage = "[WebView] Bridge: handling response id \(message.id) - no pending request found. " +
                "message: version=\(message.version) type=\(message.type.rawValue) " +
                "action=\(message.action) payload=\(String(describing: message.payloadAny)) " +
                "timestamp=\(message.timestamp)"
            Logger.common(
                message: responseLogMessage,
                category: .webViewInAppMessages
            )
        }
    }
}

final class ErrorMessageHandler: BridgeMessageHandler {

    func canHandle(_ message: BridgeMessage) -> Bool {
        message.type == .error
    }

    func handle(_ message: BridgeMessage,
                bridge: MindboxWebBridge,
                pending: BridgePendingStore) {

        let hadPending = pending.containsPending(message.id)
        if hadPending {
            pending.removePending(message.id)
        }

        let errorLogMessage = "[WebView] Bridge: handling error id \(message.id) hadPending=\(hadPending). " +
            "message: version=\(message.version) type=\(message.type.rawValue) " +
            "action=\(message.action) payload=\(String(describing: message.payloadAny)) " +
            "timestamp=\(message.timestamp)"
        Logger.common(
            message: errorLogMessage,
            category: .webViewInAppMessages
        )
    }
}
