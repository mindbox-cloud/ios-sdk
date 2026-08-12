//
//  EmbeddedBlockWebViewPage.swift
//  Mindbox
//
//  Created by vailence on 03.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit
import WebKit
import MindboxLogger

/// The embedded block page in a WKWebView.
///
/// The web view comes from `InAppWebViewFactory` — the same place where in-app web views are
/// configured: the block gets the same user agent and the same `WKWebsiteDataStore`, and therefore
/// a shared HTTP cache.
final class EmbeddedBlockWebViewPage: NSObject, EmbeddedBlockPageHosting {

    /// The handler name is our own until blocks move to the shared in-app bridge.
    private enum Constants {
        static let handlerName = "mindboxEmbeddedBlock"
    }

    let webView: WKWebView

    var view: UIView { webView }

    var onMessage: ((EmbeddedBlockPageMessage) -> Void)?

    var onLoadFailure: (() -> Void)?

    var onLoadFinish: (() -> Void)?

    private let content: EmbeddedBlockWebContent

    init(content: EmbeddedBlockWebContent, webView: WKWebView = InAppWebViewFactory.make()) {
        self.content = content
        self.webView = webView
        super.init()

        setUpWebView()
        attachBridge()
    }

    func load() {
        switch content.source {
        case .url(let url):
            webView.load(URLRequest(url: url))
        case .html(let html):
            // A page supplied as markup has an about:blank origin, so it will have neither localStorage nor network requests to its own domain. This case will change or be removed entirely in (MOBILE-328)
            webView.loadHTMLString(html, baseURL: nil)
        }
    }

    func cancel() {
        webView.stopLoading()
    }

    private func setUpWebView() {
        webView.navigationDelegate = self

        // The background is transparent: the app background, not a white sheet, should show through
        // the gaps in the content.
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear

        // The container height equals the content height, so there is nothing to scroll vertically —
        // otherwise the block would bounce under the finger on every horizontal swipe.
        webView.scrollView.bounces = false
        webView.scrollView.alwaysBounceVertical = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
    }

    private func attachBridge() {
        let controller = webView.configuration.userContentController
        // Idempotent: the web view may come from reuse and carry a handler with this name from its
        // previous owner.
        controller.removeScriptMessageHandler(forName: Constants.handlerName)
        // WKUserContentController holds the handler strongly, so a weak proxy goes into it —
        // otherwise the page and the web view would never be released.
        controller.add(EmbeddedBlockWebViewMessageProxy(receiver: self), name: Constants.handlerName)
    }

    fileprivate func receive(body: Any) {
        guard let message = EmbeddedBlockPageMessage(body: body) else {
            Logger.common(message: "[EmbeddedBlock] Unknown page message: \(body)", category: .embeddedBlocks)
            return
        }

        onMessage?(message)
    }
}

/// Navigation only judges its own business: the load failed or the document arrived. Block
/// readiness does not follow from that — it is declared by the page itself with its `ready`, and
/// the only listener of a loaded document is the debug readiness override.
extension EmbeddedBlockWebViewPage: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        onLoadFinish?()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        reportLoadFailure(error, phase: "navigation")
    }

    func webView(_ webView: WKWebView,
                 didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        reportLoadFailure(error, phase: "provisional navigation")
    }
}

private extension EmbeddedBlockWebViewPage {

    /// A cancelled navigation is not a load failure, and passing it off as one is not allowed: the
    /// block would collapse out of nowhere and stay a zero-height hole until the end of the screen's
    /// life. WebKit returns `NSURLErrorCancelled` in two perfectly ordinary cases: the navigation
    /// was superseded by the next one — a client-side redirect, the page will load on its own — and
    /// the navigation was stopped by us, by calling `cancel()` on a block that went off screen. The
    /// second case also arrives after the block is back in the window, so the provider will not
    /// filter it out with its `isStarted`.
    func reportLoadFailure(_ error: Error, phase: String) {
        let error = error as NSError

        guard !(error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled) else {
            Logger.common(message: "[EmbeddedBlock] Page \(phase) was cancelled, not a load failure",
                          category: .embeddedBlocks)
            return
        }

        Logger.common(message: "[EmbeddedBlock] Page \(phase) failed: \(error.localizedDescription)",
                      category: .embeddedBlocks)
        onLoadFailure?()
    }
}

/// A weak layer between `WKUserContentController` and the page.
private final class EmbeddedBlockWebViewMessageProxy: NSObject, WKScriptMessageHandler {

    private weak var receiver: EmbeddedBlockWebViewPage?

    init(receiver: EmbeddedBlockWebViewPage) {
        self.receiver = receiver
        super.init()
    }

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        receiver?.receive(body: message.body)
    }
}
