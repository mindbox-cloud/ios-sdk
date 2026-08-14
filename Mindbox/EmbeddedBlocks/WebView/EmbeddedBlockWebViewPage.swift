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
/// Speaks the same bridge as an in-app: same envelope, same handler name, same handler set. The
/// page therefore gets everything an in-app page has — logging, local state, links, operations —
/// without a line of block-specific code, and a page can be written once for both.
///
/// The web view comes from `InAppWebViewFactory` — the same place in-app web views are
/// configured — so the block shares their user agent, their `WKWebsiteDataStore` and therefore
/// their HTTP cache.
final class EmbeddedBlockWebViewPage: NSObject, EmbeddedBlockPageHosting {

    let webView: WKWebView

    var view: UIView { webView }

    var onContentRendered: ((Int) -> Void)?

    var onLoadFailure: (() -> Void)?

    var onLoadFinish: (() -> Void)?

    /// Set by the provider. A block that left the window keeps its page alive, and that page can
    /// still deliver whatever its `setTimeout` scheduled — nothing the user did stands behind
    /// such a message.
    var isUserPresent = true

    private let id: String
    private let content: EmbeddedBlockWebContent
    private let bridge: MindboxWebBridge
    private let actionRegistry: WebBridgeActionRegistry

    init(id: String,
         content: EmbeddedBlockWebContent,
         webView: WKWebView = InAppWebViewFactory.make(),
         actionRegistry: WebBridgeActionRegistry
         = WebBridgeActionRegistry(handlers: WebBridgeActionHandlerFactory.makeHandlers())) {
        self.id = id
        self.content = content
        self.webView = webView
        self.bridge = MindboxWebBridge(webView: webView)
        self.actionRegistry = actionRegistry
        super.init()

        setUpWebView()
        bridge.messageDelegate = self
        bridge.navigationDelegate = self
    }

    deinit {
        actionRegistry.tearDown()
    }

    func load() {
        switch content.source {
        case .url(let url):
            bridge.updateContentURL(url)
            // The navigation has to be handed to the bridge: until this exact document commits,
            // every script message is treated as a leftover from a previous owner of the web
            // view. Without this the page's messages are dropped in silence and the block waits
            // out its whole budget with no error anywhere.
            bridge.expectContentNavigation(webView.load(URLRequest(url: url)))
        case .html(let html):
            bridge.updateContentURL(nil)
            // Markup has an about:blank origin, so no localStorage and no requests to its own
            // domain. Debug scenarios only.
            bridge.expectContentNavigation(webView.loadHTMLString(html, baseURL: nil))
        }
    }

    func reload() {
        bridge.expectContentNavigation(webView.reload())
    }

    func cancel() {
        webView.stopLoading()
    }

    private func setUpWebView() {
        // The background is transparent: the app background, not a white sheet, should show
        // through the gaps in the content.
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear

        // The container height equals the content height, so there is nothing to scroll
        // vertically — otherwise the block would bounce under the finger on every horizontal
        // swipe.
        webView.scrollView.bounces = false
        webView.scrollView.alwaysBounceVertical = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
    }
}

// MARK: - WebBridgeHost

extension EmbeddedBlockWebViewPage: WebBridgeHost {

    var contentId: String { id }

    var logCategory: LogCategory { .embeddedBlocks }

    /// A block has none: tags belong to an in-app show.
    var tags: [String: String]? { nil }

    /// The block draws inside the host's own hierarchy and owns no controller, so the search starts
    /// at the window's root — and does not stop there. Whatever is on top is what can present: a
    /// root that already presents something refuses to present anything else, and the block sitting
    /// inside a modal screen is exactly that case. Stopping at the root would leave the tap with no
    /// Safari and the page with no answer.
    var presentingViewController: UIViewController? {
        guard var presenter = view.window?.rootViewController else { return nil }

        while let presented = presenter.presentedViewController {
            presenter = presented
        }

        return presenter
    }

    func send(_ message: BridgeMessage) {
        bridge.send(message)
    }

    func makeStartPayload() -> JSONValue {
        WebViewStartPayloadBuilder(contentId: id,
                                   operation: nil,
                                   // The configuration entry goes here once the resolver reads
                                   // one; today the block address is still hardcoded.
                                   customParams: nil,
                                   insetsSource: view,
                                   logError: { [id] message in
                                       Logger.common(message: "[EmbeddedBlock] Block '\(id)': \(message)",
                                                     level: .error,
                                                     category: .embeddedBlocks)
                                   }).build()
    }
}

// MARK: - WebBridgeContentHosting

extension EmbeddedBlockWebViewPage: WebBridgeContentHosting {

    func bridgeDidRenderContent(count: Int) {
        onContentRendered?(count)
    }
}

// MARK: - WebBridgeMessageDelegate

extension EmbeddedBlockWebViewPage: WebBridgeMessageDelegate {

    func webBridge(_ bridge: MindboxWebBridge, didReceiveBridgeMessage message: BridgeMessage) {
        guard message.type == .request else { return }

        // An action nobody owns is not an error: the web vocabulary is allowed to be newer than
        // the SDK.
        guard actionRegistry.handle(message, host: self) else {
            Logger.common(message: "[EmbeddedBlock] Block '\(id)': unknown action '\(message.action)'",
                          category: .embeddedBlocks)
            return
        }
    }
}

// MARK: - WebBridgeNavigationDelegate

/// Navigation only judges its own business: the load failed or the document arrived. Block
/// readiness does not follow from that — the page declares it by reporting the content it
/// rendered.
extension EmbeddedBlockWebViewPage: WebBridgeNavigationDelegate {

    func webBridge(_ bridge: MindboxWebBridge, didStartProvisionalNavigation url: URL?) {
        Logger.common(message: "[EmbeddedBlock] Block '\(id)': loading \(url?.absoluteString ?? "unknown")",
                      category: .embeddedBlocks)
    }

    func webBridge(_ bridge: MindboxWebBridge, didFinishNavigation url: URL?) {
        onLoadFinish?()
    }

    /// A cancelled navigation is not a load failure, and passing it off as one is not allowed:
    /// the block would collapse out of nowhere and stay a zero-height hole until the end of the
    /// screen's life. WebKit returns `NSURLErrorCancelled` in two perfectly ordinary cases: the
    /// navigation was superseded by the next one — a client-side redirect, the page will load on
    /// its own — and the navigation was stopped by us, by calling `cancel()` on a block that went
    /// off screen. The second case also arrives after the block is back in the window, so the
    /// provider will not filter it out with its own state.
    func webBridge(_ bridge: MindboxWebBridge, didFailProvisionalNavigation url: URL?, error: Error) {
        let error = error as NSError

        guard !(error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled) else {
            Logger.common(message: "[EmbeddedBlock] Block '\(id)': navigation was cancelled, not a load failure",
                          category: .embeddedBlocks)
            return
        }

        Logger.common(message: "[EmbeddedBlock] Block '\(id)': navigation failed: \(error.localizedDescription)",
                      category: .embeddedBlocks)
        onLoadFailure?()
    }

    func webBridge(_ bridge: MindboxWebBridge,
                   decidePolicyFor url: URL?,
                   navigationType: WKNavigationType,
                   decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        switch navigationType {
        case .other, .reload, .backForward, .formSubmitted, .formResubmitted:
            decisionHandler(.allow)
        case .linkActivated:
            // A block is a piece of the host's own layout: letting a tap replace the feed with
            // the destination page in place would be a dead end with no way back. Links belong
            // in `openLink`, which opens them where a link should open.
            Logger.common(message: "[EmbeddedBlock] Block '\(id)': blocked in-place navigation to \(url?.absoluteString ?? "unknown")",
                          category: .embeddedBlocks)
            decisionHandler(.cancel)
        @unknown default:
            decisionHandler(.allow)
        }
    }

    func webBridge(_ bridge: MindboxWebBridge, didReceiveHTTPError url: String?) {
        // Reported only. Healing a poisoned cache entry is the in-app path's job today; giving
        // the block the same treatment is its own change.
        Logger.common(message: "[EmbeddedBlock] Block '\(id)': subresource error for \(url ?? "nil")",
                      category: .embeddedBlocks)
    }
}
