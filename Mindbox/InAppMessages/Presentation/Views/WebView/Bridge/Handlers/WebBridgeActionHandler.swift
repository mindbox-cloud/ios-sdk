//
//  WebBridgeActionHandler.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

protocol WebBridgeActionHandler: AnyObject {

    var actions: Set<BridgeMessage.Action> { get }

    func handle(_ message: BridgeMessage, host: WebBridgeHost)

    func tearDown()
}

extension WebBridgeActionHandler {

    func tearDown() {}
}

final class WebBridgeActionRegistry {

    private let handlers: [WebBridgeActionHandler]

    private var owners: [BridgeMessage.Action: WebBridgeActionHandler] = [:]

    init(handlers: [WebBridgeActionHandler]) {
        self.handlers = handlers

        for handler in handlers {
            for action in handler.actions {
                guard owners[action] == nil else {
                    Logger.common(message: "[WebView] Bridge: action '\(action.rawValue)' is claimed by more than one handler, keeping the first",
                                  level: .error,
                                  category: .webViewInAppMessages)
                    continue
                }

                owners[action] = handler
            }
        }
    }

    func handle(_ message: BridgeMessage, host: WebBridgeHost) {
        guard message.type == .request else { return }

        guard let action = message.parsedAction else { return }

        guard let owner = owners[action] else {
            host.respondError(.notServed, detail: "no handler owns this action", to: message)
            return
        }

        guard !action.requiresUserPresence || host.requireUserPresence(for: message) else {
            return
        }

        owner.handle(message, host: host)
    }

    func tearDown() {
        handlers.forEach { $0.tearDown() }
    }

    func handler<T: WebBridgeActionHandler>(ofType type: T.Type) -> T? {
        handlers.first { $0 is T } as? T
    }
}
