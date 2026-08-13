//
//  OpenLinkActionHandler.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit
import SafariServices
import MindboxLogger

/// Opens a link the page asked for.
///
/// A web address is offered to the system as a universal link first, so an app that owns the
/// domain wins; only when nothing claims it does the link open in-app in Safari. Anything else —
/// `tel:`, `mailto:`, a deep link — goes straight to the system, which is the only thing that
/// knows what to do with it.
final class OpenLinkActionHandler: WebBridgeActionHandler {

    let actions: Set<BridgeMessage.Action> = [.openLink]

    private let urlOpener: BridgeURLOpening

    init(urlOpener: BridgeURLOpening = SystemURLOpener()) {
        self.urlOpener = urlOpener
    }

    func handle(_ message: BridgeMessage, host: WebBridgeHost) {
        guard case .string(let urlString)? = message.payloadObject?["url"], !urlString.isEmpty else {
            host.respondError("Invalid payload: missing or empty 'url' field", to: message)
            return
        }

        guard let url = URL(string: urlString) else {
            host.respondError("Invalid URL: '\(urlString)' could not be parsed", to: message)
            return
        }

        switch url.scheme?.lowercased() {
        case "http", "https":
            Logger.common(message: "[WebView] navigate: trying universal link first for \(urlString)",
                          level: .info,
                          category: host.logCategory)
            openAsUniversalLinkOrSafari(url: url, message: message, host: host)
        default:
            Logger.common(message: "[WebView] navigate: opening via UIApplication \(urlString)",
                          level: .info,
                          category: host.logCategory)
            urlOpener.open(url, answering: message, host: host)
        }
    }
}

private extension OpenLinkActionHandler {

    /// The opener is captured, not `self`: handing the URL to the system must not depend on the
    /// handler still being around, exactly as it did not depend on the view before. The page is
    /// held weakly for the opposite reason — a show that ended gets no answer, and waiting on
    /// the system must not be what keeps it alive.
    func openAsUniversalLinkOrSafari(url: URL, message: BridgeMessage, host: WebBridgeHost) {
        let opener = urlOpener

        DispatchQueue.main.async { [weak host] in
            opener.open(url, universalLinksOnly: true) { opened in
                DispatchQueue.main.async {
                    guard let host else { return }

                    guard !opened else {
                        Logger.common(message: "[WebView] navigate: opened as universal link \(url.absoluteString)",
                                      level: .info,
                                      category: host.logCategory)
                        host.respondSuccess(to: message)
                        return
                    }

                    Logger.common(message: "[WebView] navigate: not a universal link, falling back to SFSafariViewController for \(url.absoluteString)",
                                  level: .info,
                                  category: host.logCategory)
                    Self.openInSafari(url: url, message: message, host: host)
                }
            }
        }
    }

    static func openInSafari(url: URL, message: BridgeMessage, host: WebBridgeHost) {
        guard let presenter = host.presentingViewController else {
            Logger.common(message: "[WebView] navigate: no presenting view controller found",
                          level: .default,
                          category: host.logCategory)
            host.respondError("Failed to open URL: no presenting view controller", to: message)
            return
        }

        let safari = SFSafariViewController(url: url)
        presenter.present(safari, animated: true) {
            Logger.common(message: "[WebView] navigate: SFSafariViewController presented for \(url.absoluteString)",
                          level: .info,
                          category: host.logCategory)
            host.respondSuccess(to: message)
        }
    }
}
