//
//  InAppWebViewPrewarmNavigationPolicy.swift
//  Mindbox
//
//  Created by Sergei Semko on 06.07.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import WebKit
import MindboxLogger

/// Pins the hidden prewarm instance to the documents the SDK itself loads: any
/// page-initiated main-frame navigation (JS redirect, meta refresh) is cancelled — a
/// hidden WebView must never wander off and keep fetching arbitrary URLs. Active only
/// until the first borrow; the show's bridge installs its own delegate then.
final class InAppWebViewPrewarmNavigationPolicy: NSObject, WKNavigationDelegate {

    // Main-thread confined, like every WKWebView interaction around it.
    private var allowedURLs: Set<String> = ["about:blank"]

    /// Registers a document URL the service is about to load itself.
    func allow(_ url: URL) {
        allowedURLs.insert(url.absoluteString)
    }

    /// Pure decision core (WKNavigationAction cannot be faked in tests). Subframes are
    /// the page's own business; a nil target frame (window.open) is pinned like the top frame.
    func decision(for url: URL?, targetIsMainFrame: Bool?) -> WKNavigationActionPolicy {
        if targetIsMainFrame == false { return .allow }
        return allowedURLs.contains(url?.absoluteString ?? "about:blank") ? .allow : .cancel
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let verdict = decision(for: navigationAction.request.url,
                               targetIsMainFrame: navigationAction.targetFrame?.isMainFrame)
        if verdict == .cancel {
            Logger.common(message: "[WebView] Prewarm: blocked page-initiated navigation to \(navigationAction.request.url?.absoluteString ?? "nil")",
                          level: .info, category: .webViewInAppMessages)
        }
        decisionHandler(verdict)
    }
}
