//
//  ShowInAppActionHandler.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

final class ShowInAppActionHandler: WebBridgeActionHandler {

    let actions: Set<BridgeMessage.Action> = [.showInApp]

    func handle(_ message: BridgeMessage, host: WebBridgeHost) {
        guard let inappHost = host as? WebBridgeInappRequestHosting else {
            host.respondError(.notServed, detail: "no in-app service on this surface", to: message)
            return
        }

        guard let payload = message.payloadObject,
              case .string(let inAppId)? = payload["inappId"],
              !inAppId.isEmpty else {
            host.respondError(.invalidPayload, detail: "missing or empty 'inappId'", to: message)
            return
        }

        var params: [String: JSONValue] = [:]
        if case .object(let sent)? = payload["params"] {
            params = sent
        }

        Logger.common(message: "[WebView] showInApp: inappId=\(inAppId) with \(params.count) param(s)",
                      level: .info,
                      category: host.logCategory)

        inappHost.bridgeDidRequestShowInApp(id: inAppId, params: params) { [weak host] outcome in
            switch outcome {
            case .success:
                host?.respondSuccess(to: message)
            case .failure(let code):
                host?.respondError(code, detail: "in-app '\(inAppId)' not shown", to: message)
            }
        }
    }
}
