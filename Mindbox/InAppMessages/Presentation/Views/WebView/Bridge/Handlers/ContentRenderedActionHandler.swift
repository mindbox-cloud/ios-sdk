//
//  ContentRenderedActionHandler.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

/// The page reports how much content it put on screen.
///
/// Registered everywhere, like every handler. Only a surface that reserves space for content
/// listens today — a block gives its space back when the count is zero — but nothing here is
/// specific to one, so an in-app that wants the same signal conforms and starts receiving it.
final class ContentRenderedActionHandler: WebBridgeActionHandler {

    let actions: Set<BridgeMessage.Action> = [.contentRendered]

    func handle(_ message: BridgeMessage, host: WebBridgeHost) {
        guard let count = Self.count(in: message) else {
            host.respondError("Invalid payload: missing or non-numeric 'count'", to: message)
            return
        }

        // A count of items the page drew, not the size of a collection — isEmpty has no meaning
        // here, and a negative number is a page bug worth naming rather than clamping.
        // swiftlint:disable:next empty_count
        guard count >= 0 else {
            host.respondError("Invalid payload: 'count' must not be negative, got \(count)", to: message)
            return
        }

        guard let content = host as? WebBridgeContentHosting else {
            Logger.common(message: "[WebView] Bridge: contentRendered(\(count)) from '\(host.contentId)' has nobody listening here, ignoring",
                          category: host.logCategory)
            host.respondSuccess(to: message)
            return
        }

        content.bridgeDidRenderContent(count: count)
        host.respondSuccess(to: message)
    }

    /// JS gives a number as a `Double`, but a whole value may also arrive as an `Int`.
    private static func count(in message: BridgeMessage) -> Int? {
        switch message.payloadObject?["count"] {
        case .int(let count):
            return count
        case .double(let count):
            return Int(exactly: count.rounded())
        default:
            return nil
        }
    }
}
