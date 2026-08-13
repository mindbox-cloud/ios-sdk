//
//  BridgeURLOpening.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit
import MindboxLogger

/// Handing a URL to the system.
///
/// A seam over `UIApplication.open`, which cannot be exercised in a test: without it the
/// decision of *which* way a link is opened could only be checked by actually leaving the app.
protocol BridgeURLOpening: AnyObject {

    func open(_ url: URL, universalLinksOnly: Bool, completion: @escaping (Bool) -> Void)
}

final class SystemURLOpener: BridgeURLOpening {

    func open(_ url: URL, universalLinksOnly: Bool, completion: @escaping (Bool) -> Void) {
        let options: [UIApplication.OpenExternalURLOptionsKey: Any] = universalLinksOnly
            ? [.universalLinksOnly: true]
            : [:]

        UIApplication.shared.open(url, options: options, completionHandler: completion)
    }
}

extension BridgeURLOpening {

    /// Opens through the system and answers the page with the outcome.
    ///
    /// Shared by `openLink` and by `settings.open`, which has always reached the system this
    /// same way. The log still says "navigate" for both because that is the text it has always
    /// carried — worth correcting, but not while the point of the change is that nothing moved.
    func open(_ url: URL, answering message: BridgeMessage, host: WebBridgeHost) {
        DispatchQueue.main.async { [weak host] in
            self.open(url, universalLinksOnly: false) { success in
                DispatchQueue.main.async {
                    guard let host else { return }

                    if success {
                        Logger.common(
                            message: "[WebView] navigate: successfully opened \(url.absoluteString)",
                            level: .info,
                            category: host.logCategory
                        )
                        host.respondSuccess(to: message)
                    } else {
                        Logger.common(
                            message: "[WebView] navigate: failed to open \(url.absoluteString)",
                            level: .default,
                            category: host.logCategory
                        )
                        host.respondError("Failed to open URL: '\(url.absoluteString)'", to: message)
                    }
                }
            }
        }
    }
}
