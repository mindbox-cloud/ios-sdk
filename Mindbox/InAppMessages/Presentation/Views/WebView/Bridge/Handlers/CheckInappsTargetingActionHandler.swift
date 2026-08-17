//
//  CheckInappsTargetingActionHandler.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

/// Answers which of the in-apps the page asked about it is allowed to render.
///
/// The selection itself belongs to the host: only a surface that carries a feed knows where its
/// catalogue comes from. This handler owns the envelope — an unreadable question is refused
/// rather than answered with an empty list, because the page can retry a refusal, while an empty
/// answer it would take for the truth.
final class CheckInappsTargetingActionHandler: WebBridgeActionHandler {

    let actions: Set<BridgeMessage.Action> = [.checkInappsTargeting]

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
            Logger.common(message: "[WebView] checkInappsTargeting: \(requested.count - ids.count) of \(requested.count) asked ids are not strings, skipping them",
                          level: .error,
                          category: host.logCategory)
        }

        guard let feedHost = host as? WebBridgeFeedHosting else {
            // Deliberately left without an answer, not refused: the page owns its own deadline,
            // and this surface answering the feed's questions is a planned capability, so the
            // refusal would have to be unlearned by every page that starts relying on it.
            Logger.common(message: "[WebView] Bridge: checkInappsTargeting from '\(host.contentId)' has no feed to ask here, ignoring",
                          level: .error,
                          category: host.logCategory)
            return
        }

        // The host is held weakly: a show that ended while the selection was working gets no
        // answer, and waiting on the selection must not be what keeps its page alive.
        feedHost.bridgeDidAskRenderableInapps(ids) { [weak host] allowed in
            host?.respond(to: message, payload: .object(["inappIds": .array(allowed.map { .string($0) })]))
        }
    }
}
