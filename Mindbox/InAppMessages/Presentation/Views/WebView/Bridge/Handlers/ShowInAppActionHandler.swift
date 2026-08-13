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
/// **Not implemented yet: the request is journalled and acknowledged, and no window opens.** The
/// page is answered so it can finish its own flow — un-highlighting the story it just handled —
/// rather than sit on a promise nothing will ever settle.
final class ShowInAppActionHandler: WebBridgeActionHandler {

    let actions: Set<BridgeMessage.Action> = [.showInApp]

    func handle(_ message: BridgeMessage, host: WebBridgeHost) {
        guard let payload = message.payloadObject,
              case .string(let inAppId)? = payload["inappId"],
              !inAppId.isEmpty else {
            host.respondError("Invalid payload: missing or empty 'inappId'", to: message)
            return
        }

        // TODO: Show the in-app with this id as a direct call.
        //   - it bypasses targeting, the shown-before dedup and every presentation limit, which
        //     is achieved by NOT entering `InappMapper` or `InappScheduleManager.scheduleInApp`
        //     and going straight to `InAppPresentationManager.present`;
        //   - the show is still tracked as on the ordinary path. Reuse what
        //     `InappScheduleManager.presentInapp` already does — it also raises
        //     `isPresentingInAppMessage`, which is what keeps ordinary in-apps and snackbars from
        //     appearing over stories;
        //   - the reverse is deliberate: this path must NOT consult `canPresentInApp`, so stories
        //     open over an in-app that is already showing, dismissing it first;
        //   - `params` merges into that in-app's start payload LAST and overwrites everything it
        //     collides with, service keys included. The SDK validates nothing and protects
        //     nothing: it is an opaque dictionary and collisions are the page's business;
        //   - `index` and `sourceInappId` stay in the log and out of the payload — the page
        //     already puts whatever it needs into `params`.
        let index = payload["index"].flatMap { value -> Int? in
            guard case .int(let index) = value else { return nil }
            return index
        }
        let sourceInAppId: String? = {
            guard case .string(let source)? = payload["sourceInappId"] else { return nil }
            return source
        }()

        Logger.common(message: """
        [WebView] showInApp is not implemented, nothing will be shown: \
        inappId=\(inAppId) index=\(index.map(String.init) ?? "nil") \
        sourceInappId=\(sourceInAppId ?? "nil") params=\(payload["params"].map { String(describing: $0.anyValue) } ?? "nil")
        """, level: .default, category: host.logCategory)

        host.respondSuccess(to: message)
    }
}
