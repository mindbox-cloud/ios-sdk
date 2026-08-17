//
//  ShowInAppActionHandler.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

/// Shows the in-app the page asked for, by id.
///
/// The show itself belongs to the host: what asking means — closing whatever is on screen,
/// bypassing which limits — is a decision of the surface that carries the feed, not of the
/// bridge. The success below says the request was well-formed and handed over, never that a
/// window opened: the page finishes its own flow on it and does not wait for the show.
final class ShowInAppActionHandler: WebBridgeActionHandler {

    let actions: Set<BridgeMessage.Action> = [.showInApp]

    func handle(_ message: BridgeMessage, host: WebBridgeHost) {
        guard let payload = message.payloadObject,
              case .string(let inAppId)? = payload["inappId"],
              !inAppId.isEmpty else {
            host.respondError("Invalid payload: missing or empty 'inappId'", to: message)
            return
        }

        guard let feedHost = host as? WebBridgeFeedHosting else {
            // Journalled and dropped, not refused: a surface without a feed picking this up
            // later is a conformance, and pages must not have learned that it errors here.
            Logger.common(message: "[WebView] Bridge: showInApp from '\(host.contentId)' has no feed to serve it here, ignoring",
                          level: .error,
                          category: host.logCategory)
            return
        }

        // `params` merges into the shown in-app's start payload last and overwrites everything
        // it collides with, service keys included: an opaque dictionary, collisions are the
        // page's business. `index` and `sourceInappId` stay in the log and out of the payload —
        // the page already puts whatever it needs into `params`.
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

        feedHost.bridgeDidRequestShowInApp(id: inAppId, params: params)
        host.respondSuccess(to: message)
    }
}
