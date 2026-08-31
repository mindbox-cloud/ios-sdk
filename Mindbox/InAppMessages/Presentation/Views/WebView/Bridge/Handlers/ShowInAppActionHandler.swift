//
//  ShowInAppActionHandler.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

/// The success response says the request was well-formed and handed over, never that a window
/// opened — the page does not wait for the show.
final class ShowInAppActionHandler: WebBridgeActionHandler {

    let actions: Set<BridgeMessage.Action> = [.showInApp]

    func handle(_ message: BridgeMessage, host: WebBridgeHost) {
        guard let payload = message.payloadObject,
              case .string(let inAppId)? = payload["inappId"],
              !inAppId.isEmpty else {
            host.respondError("Invalid payload: missing or empty 'inappId'", to: message)
            return
        }

        guard let inappHost = host as? WebBridgeInappRequestHosting else {
            // Journalled and dropped, not refused: surfaces without an in-app service may conform later, and
            // pages must not have learned that this errors here.
            Logger.common(message: "[WebView] Bridge: showInApp from '\(host.contentId)' has no in-app service to serve it here, ignoring",
                          level: .error,
                          category: host.logCategory)
            return
        }

        var params: [String: JSONValue] = [:]
        if case .object(let sent)? = payload["params"] {
            params = sent
        }

        let index = payload["index"].flatMap { value -> Int? in
            guard case .int(let index) = value else { return nil }
            return index
        }
        let sourceInAppId: String? = {
            guard case .string(let source)? = payload["sourceInappId"] else { return nil }
            return source
        }()

        Logger.common(message: "[WebView] showInApp: inappId=\(inAppId) index=\(index.map(String.init) ?? "nil") sourceInappId=\(sourceInAppId ?? "nil") with \(params.count) param(s)",
                      level: .info,
                      category: host.logCategory)

        inappHost.bridgeDidRequestShowInApp(id: inAppId, params: params)
        host.respondSuccess(to: message)
    }
}
