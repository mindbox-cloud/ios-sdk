//
//  ContentRenderedActionHandler.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

final class ContentRenderedActionHandler: WebBridgeActionHandler {

    let actions: Set<BridgeMessage.Action> = [.contentRendered]

    func handle(_ message: BridgeMessage, host: WebBridgeHost) {
        guard let content = host as? WebBridgeContentHosting else {
            Logger.common(message: "[WebView] Bridge: contentRendered from '\(host.contentId)' has nobody listening here, ignoring",
                          category: host.logCategory)
            host.respondSuccess(to: message)
            return
        }

        let renderedCount: Int

        switch Self.count(in: message) {
        case .whole(let count):
            renderedCount = count
        case .notWhole(let count):
            refuse("'count' must be a whole number, got \(count)", message: message, host: host, content: content)
            return
        case .absent:
            refuse("missing or non-numeric 'count'", message: message, host: host, content: content)
            return
        }

        guard renderedCount >= 0 else {
            refuse("'count' must not be negative, got \(renderedCount)", message: message, host: host, content: content)
            return
        }

        content.bridgeDidRenderContent(count: renderedCount)
        host.respondSuccess(to: message)
    }

    private func refuse(_ detail: String, message: BridgeMessage, host: WebBridgeHost, content: WebBridgeContentHosting) {
        host.respondError(.invalidPayload, detail: detail, to: message)
        content.bridgeDidReportUnreadableContent()
    }

    private enum ReportedCount {

        case whole(Int)

        case notWhole(Double)

        case absent
    }

    private static func count(in message: BridgeMessage) -> ReportedCount {
        switch message.payloadObject?["count"] {
        case .int(let count):
            return .whole(count)
        case .double(let count):
            guard let whole = Int(exactly: count) else { return .notWhole(count) }

            return .whole(whole)
        default:
            return .absent
        }
    }
}
