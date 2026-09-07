//
//  ShowInAppActionHandler.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

/// One terminal answer, by the outcome: success once the window is on screen, otherwise an error
/// naming why — in sync with Android and the bridge contract.
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
            host.respondError("showInApp is not served on this surface", to: message)
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

        inappHost.bridgeDidRequestShowInApp(id: inAppId, params: params) { [weak host] outcome in
            switch outcome {
            case .success:
                host?.respondSuccess(to: message)
            case .failure(let refusal):
                host?.respondError(refusal.rawValue, to: message)
            }
        }
    }
}
