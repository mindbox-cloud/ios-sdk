//
//  InAppWebViewPrewarmNavigationPolicy.swift
//  Mindbox
//
//  Created by Sergei Semko on 06.07.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import WebKit
import MindboxLogger

final class InAppWebViewPrewarmNavigationPolicy: NSObject, WKNavigationDelegate {

    private var allowedURLs: Set<String> = ["about:blank"]

    func allow(_ url: URL) {
        allowedURLs.insert(url.absoluteString)
    }

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
