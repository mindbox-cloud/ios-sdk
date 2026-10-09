//
//  FilterShowableInappsActionHandler.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

/// An unreadable question, or one the SDK has no config to answer, is refused rather than answered with
/// an empty list: the page can retry a refusal, while an empty answer it would take for the truth.
final class FilterShowableInappsActionHandler: WebBridgeActionHandler {

    let actions: Set<BridgeMessage.Action> = [.filterShowableInapps]

    func handle(_ message: BridgeMessage, host: WebBridgeHost) {
        guard let inappHost = host as? WebBridgeInappRequestHosting else {
            host.respondError(.notServed, detail: "no in-app service on this surface", to: message)
            return
        }

        guard case .array(let requested)? = message.payloadObject?["inappIds"] else {
            host.respondError(.invalidPayload, detail: "missing 'inappIds' array", to: message)
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

        inappHost.bridgeDidAskShowableInapps(ids) { [weak host] answer in
            switch answer {
            case .success(let allowed):
                host?.respond(to: message, payload: .object(["inappIds": .array(allowed.map { .string($0) })]))
            case .failure(let code):
                host?.respondError(code, detail: "the SDK cannot answer it", to: message)
            }
        }
    }
}
