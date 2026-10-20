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

final class OpenLinkActionHandler: WebBridgeActionHandler {

    let actions: Set<BridgeMessage.Action> = [.openLink]

    private let urlOpener: BridgeURLOpening

    init(urlOpener: BridgeURLOpening = SystemURLOpener()) {
        self.urlOpener = urlOpener
    }

    func handle(_ message: BridgeMessage, host: WebBridgeHost) {
        guard case .string(let requestedURL)? = message.payloadObject?["url"],
              case let urlString = requestedURL.trimmingCharacters(in: .whitespacesAndNewlines),
              !urlString.isEmpty else {
            host.respondError(.invalidPayload, detail: "missing or empty 'url' field", to: message)
            return
        }

        guard let url = URL(string: urlString) else {
            host.respondError(.invalidURL, detail: "'\(urlString)' could not be parsed", to: message)
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

    func openAsUniversalLinkOrSafari(url: URL, message: BridgeMessage, host: WebBridgeHost) {
        let opener = urlOpener

        DispatchQueue.main.async { [weak host] in
            guard host?.requireUserPresence(for: message) == true else { return }

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
        guard host.requireUserPresence(for: message) else { return }

        guard var presenter = host.presentingViewController else {
            Logger.common(message: "[WebView] navigate: no presenting view controller found",
                          level: .default,
                          category: host.logCategory)
            host.respondError(.openFailed, detail: "no presenting view controller for '\(url.absoluteString)'", to: message)
            return
        }

        while let presented = presenter.presentedViewController {
            presenter = presented
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
