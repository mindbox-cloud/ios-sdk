//
//  FilterShowableInappsActionHandler.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

/// An unreadable question is refused rather than answered with an empty list: the page can
/// retry a refusal, while an empty answer it would take for the truth.
final class FilterShowableInappsActionHandler: WebBridgeActionHandler {

    let actions: Set<BridgeMessage.Action> = [.filterShowableInapps]

    func handle(_ message: BridgeMessage, host: WebBridgeHost) {
        guard case .array(let requested)? = message.payloadObject?["inappIds"] else {
            host.respondError("Invalid payload: missing 'inappIds' array", to: message)
            return
        }

        let ids = requested.compactMap { value -> String? in
            guard case .string(let id) = value else { return nil }
            return id
        }

        if ids.count != requested.count {
            Logger.common(message: "[WebView] filterShowableInapps: \(requested.count - ids.count) of \(requested.count) asked ids are not strings, skipping them",
                          level: .error,
                          category: host.logCategory)
        }

        guard let inappHost = host as? WebBridgeInappRequestHosting else {
            // Left unanswered, not refused: surfaces without an in-app service may conform later, and a refusal
            // would have to be unlearned by every page that starts relying on it.
            Logger.common(message: "[WebView] Bridge: filterShowableInapps from '\(host.contentId)' has no in-app service to ask here, ignoring",
                          level: .error,
                          category: host.logCategory)
            return
        }

        inappHost.bridgeDidAskShowableInapps(ids) { [weak host] allowed in
            host?.respond(to: message, payload: .object(["inappIds": .array(allowed.map { .string($0) })]))
        }
    }
}
