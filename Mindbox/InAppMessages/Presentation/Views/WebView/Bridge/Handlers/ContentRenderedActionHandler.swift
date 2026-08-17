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
        let renderedCount: Int

        switch Self.count(in: message) {
        case .whole(let count):
            renderedCount = count
        case .notWhole(let count):
            // A fraction is a page bug, and rounding one decides the block's fate on the page's
            // behalf: `0.4` would collapse it as empty, `0.6` would show it. Named instead, so
            // the bug is found where it is rather than lived with as a block that sometimes
            // disappears.
            refuse("Invalid payload: 'count' must be a whole number, got \(count)", message: message, host: host)
            return
        case .absent:
            refuse("Invalid payload: missing or non-numeric 'count'", message: message, host: host)
            return
        }

        // A count of items the page drew, not the size of a collection: a negative number is a
        // page bug, and the refusal is what makes it land in the metrics instead of passing for
        // an empty feed.
        guard renderedCount >= 0 else {
            refuse("Invalid payload: 'count' must not be negative, got \(renderedCount)", message: message, host: host)
            return
        }

        guard let content = host as? WebBridgeContentHosting else {
            Logger.common(message: "[WebView] Bridge: contentRendered(\(renderedCount)) from '\(host.contentId)' has nobody listening here, ignoring",
                          category: host.logCategory)
            host.respondSuccess(to: message)
            return
        }

        content.bridgeDidRenderContent(count: renderedCount)
        host.respondSuccess(to: message)
    }

    /// The page is refused, and the host hears it too: this report is the page's only statement
    /// about itself, so a host that reserved space for it now holds a show nobody can vouch for.
    private func refuse(_ reason: String, message: BridgeMessage, host: WebBridgeHost) {
        host.respondError(reason, to: message)
        (host as? WebBridgeContentHosting)?.bridgeDidReportUnreadableContent()
    }

    /// What the payload's `count` turned out to be.
    private enum ReportedCount {

        case whole(Int)

        /// A number, but not a number of items. Carried as sent so the refusal can name it.
        case notWhole(Double)

        /// Missing, or not a number at all.
        case absent
    }

    /// JS gives a number as a `Double`, but a whole value may also arrive as an `Int`.
    private static func count(in message: BridgeMessage) -> ReportedCount {
        switch message.payloadObject?["count"] {
        case .int(let count):
            return .whole(count)
        case .double(let count):
            // `Int(exactly:)` refuses a fraction, and refuses NaN, infinity and anything past
            // `Int` with it — none of which is a number of items either.
            guard let whole = Int(exactly: count) else { return .notWhole(count) }

            return .whole(whole)
        default:
            return .absent
        }
    }
}
