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

/// The embedded block page, on the same web layer in-app messages run on.
///
/// The web view, the JS bridge, the markup fetch and the start payload all come from
/// `MindboxWebViewFacade`: a block and an overlay have to agree on the protocol down to the envelope,
/// and two implementations of one bridge would drift the first time either side changed.
///
/// The actions themselves are served by the shared `WebBridgeActionRegistry` — the same handler set
/// that serves an overlay. What is different about a block lives in the capabilities this page
/// conforms to, not in a handler list of its own.
final class EmbeddedBlockWebViewPage: NSObject, EmbeddedBlockPageHosting {

    var view: UIView { pageView }

    var onContentRendered: ((Int) -> Void)?

    var onUnreadableContentReport: (() -> Void)?

    var onFeedQuestion: (([String], @escaping ([String]) -> Void) -> Void)?

    var onShowInAppRequest: ((String, [String: JSONValue]) -> Void)?

    var onDataPushConfirmed: (() -> Void)?

    var onLoadFailure: (() -> Void)?

    /// Set by the provider. A block that left the window keeps its page alive, and that page can
    /// still deliver whatever its `setTimeout` scheduled — nothing the user did stands behind
    /// such a message.
    var isUserPresent = true

    private let content: EmbeddedBlockWebContent
    private let facade: InappWebViewFacadeProtocol
    private let registry: MindboxWebPageRegistry
    private let actionRegistry: WebBridgeActionRegistry
    private let pageView: UIView

    /// A page joins the broadcast set once it has proven it can receive, that is, on its first `ready`:
    /// registering earlier would aim `localState.changed` at a document that has no bridge yet.
    private var isRegistered = false

    /// The same poisoned-cache heal the overlay path runs: a subresource that keeps failing over a
    /// stale cache entry is retried once with the cache bypassed. Gated on the page not having booted —
    /// a page whose bridge already spoke can fail a request for its own reasons.
    private let noCacheRetryPolicy: WebViewNoCacheRetryPolicy

    init(content: EmbeddedBlockWebContent,
         facade: InappWebViewFacadeProtocol? = nil,
         registry: MindboxWebPageRegistry = .shared,
         actionRegistry: WebBridgeActionRegistry
         = WebBridgeActionRegistry(handlers: WebBridgeActionHandlerFactory.makeHandlers()),
         noCacheRetryPolicy: WebViewNoCacheRetryPolicy
         = WebViewNoCacheRetryPolicy { InAppWebViewDataStore.isCacheFeatureEnabled }) {
        self.content = content
        self.noCacheRetryPolicy = noCacheRetryPolicy
        // The block does not borrow the prewarmed instance: it would hold it for as long as its
        // screen lives and leave the next in-app to start cold.
        self.facade = facade ?? MindboxWebViewFacade(params: content.params,
                                                     userAgent: SDKUserAgent.build(),
                                                     inAppId: content.inAppId,
                                                     mayBorrowWarmWebView: false)
        self.registry = registry
        self.actionRegistry = actionRegistry
        self.pageView = self.facade.makeView()
        super.init()

        self.facade.setBridgeMessageDelegate(self)
        self.facade.setNavigationDelegate(self)
        applyViewSettings()
    }

    deinit {
        actionRegistry.tearDown()
    }

    /// The markup is downloaded from `contentUrl` and committed under `baseUrl`, the same way in-app
    /// web views load. Loading `contentUrl` directly would give the page the static host as its
    /// origin, and the page resolves parts of itself against its own location.
    func load() {
        facade.loadHTML(baseUrl: content.baseUrl, contentUrl: content.contentUrl) { [weak self] in
            Logger.common(message: "[EmbeddedBlock] Failed to load page markup from '\(self?.content.contentUrl ?? "")'",
                          level: .error, category: .embeddedBlocks)
            self?.onLoadFailure?()
        }
    }

    func cancel() {
        facade.cleanWebView()
    }

    func sendInitData(params: [String: JSONValue]) {
        facade.sendInitDataUpdated(params: params)
    }

    private func applyViewSettings() {
        // The background is transparent: the app background, not a white sheet, should show through
        // the gaps in the content.
        pageView.backgroundColor = .clear

        guard let webView = pageView as? WKWebView else { return }

        webView.isOpaque = false
        webView.scrollView.backgroundColor = .clear

        // The container height equals the content height, so there is nothing to scroll vertically —
        // otherwise the block would bounce under the finger on every horizontal swipe. Horizontal
        // scrolling stays on, unlike an overlay's: a feed is a row the user swipes through.
        webView.scrollView.bounces = false
        webView.scrollView.alwaysBounceVertical = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
    }
}

// MARK: - WebBridgeHost

extension EmbeddedBlockWebViewPage: WebBridgeHost {

    var contentId: String { content.inAppId }

    var logCategory: LogCategory { .embeddedBlocks }

    /// The tags of the in-app the block is showing: operations the page sends carry them, so
    /// metrics can tell the block's traffic from an overlay's.
    var tags: [String: String]? { content.tags }

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
        facade.sendToJS(message)
    }

    func makeStartPayload() -> JSONValue {
        facade.makeStartPayload()
    }
}

// MARK: - WebBridgeContentHosting

extension EmbeddedBlockWebViewPage: WebBridgeContentHosting {

    func bridgeDidRenderContent(count: Int) {
        onContentRendered?(count)
    }

    func bridgeDidReportUnreadableContent() {
        onUnreadableContentReport?()
    }
}

// MARK: - WebBridgeFeedHosting

extension EmbeddedBlockWebViewPage: WebBridgeFeedHosting {

    func bridgeDidAskRenderableInapps(_ ids: [String], completion: @escaping ([String]) -> Void) {
        onFeedQuestion?(ids, completion)
    }

    func bridgeDidRequestShowInApp(id: String, params: [String: JSONValue]) {
        onShowInAppRequest?(id, params)
    }
}

// MARK: - MindboxWebPage

extension EmbeddedBlockWebViewPage: MindboxWebPage {

    func push(_ action: BridgeMessage.Action, payload: JSONValue) {
        facade.sendToJS(BridgeMessage(type: .request, action: action, payload: payload))
    }
}

// MARK: - Bridge messages

extension EmbeddedBlockWebViewPage: WebBridgeMessageDelegate {

    func webBridge(_ bridge: MindboxWebBridge, didReceiveBridgeMessage message: BridgeMessage) {
        // The page's answer to the `initDataUpdated` we pushed — the provider is waiting on it.
        // Caught before the registry, which swallows every non-request as somebody's confirmed
        // response; this one is the single response the SDK acts on.
        if message.type == .response, message.parsedAction == .initDataUpdated {
            onDataPushConfirmed?()
            return
        }

        // The first `ready` is the page proving it can receive — the moment it may join the
        // broadcast set. Observed on the way through; answering it stays the registry's business.
        if message.type == .request, message.parsedAction == .ready {
            registerForBroadcasts()
        }

        // An action nobody owns is not an error: the web vocabulary is allowed to be newer than
        // the SDK. Messages that are not requests are the registry's to swallow — both hosts hand
        // it everything the dispatcher matched.
        guard actionRegistry.handle(message, host: self) else {
            Logger.common(message: "[EmbeddedBlock] Unknown bridge action '\(message.action)'",
                          category: .embeddedBlocks)
            return
        }
    }

    private func registerForBroadcasts() {
        guard !isRegistered else { return }

        isRegistered = true
        registry.register(self)
    }
}

// MARK: - Navigation

/// Navigation only judges its own business: the load failed or the document arrived. Block
/// readiness does not follow from that — the page declares it by reporting the content it
/// rendered.
extension EmbeddedBlockWebViewPage: WebBridgeNavigationDelegate {

    func webBridge(_ bridge: MindboxWebBridge, didStartProvisionalNavigation url: URL?) {
        Logger.common(message: "[EmbeddedBlock] Page started loading \(url?.absoluteString ?? "unknown")",
                      category: .embeddedBlocks)
    }

    func webBridge(_ bridge: MindboxWebBridge, didFinishNavigation url: URL?) {
        Logger.common(message: "[EmbeddedBlock] Page of in-app \(content.inAppId) loaded its document, waiting for it to report itself",
                      category: .embeddedBlocks)
    }

    /// A cancelled navigation is not a load failure — reporting it as one would collapse the block for
    /// nothing. WebKit returns `NSURLErrorCancelled` in two perfectly ordinary cases: the navigation
    /// was superseded by the next one — a client-side redirect, the page will load on its own — and it
    /// was stopped by us, by calling `cancel()` on a block that went off screen.
    func webBridge(_ bridge: MindboxWebBridge, didFailProvisionalNavigation url: URL?, error: Error) {
        let error = error as NSError

        guard !(error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled) else {
            Logger.common(message: "[EmbeddedBlock] Page navigation was cancelled, not a load failure",
                          category: .embeddedBlocks)
            return
        }

        Logger.common(message: "[EmbeddedBlock] Page navigation failed: \(error.localizedDescription)",
                      level: .error, category: .embeddedBlocks)
        onLoadFailure?()
    }

    func webBridge(_ bridge: MindboxWebBridge,
                   decidePolicyFor url: URL?,
                   navigationType: WKNavigationType,
                   decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let decision = WebViewNavigationPolicy.decision(for: navigationType, url: url)
        WebViewNavigationPolicy.log(decision, navigationType: navigationType, url: url, category: .embeddedBlocks)

        switch decision {
        case .allow:
            decisionHandler(.allow)

        case .handInBack(let url):
            decisionHandler(.cancel)

            guard let url else { return }

            push(.navigationIntercepted, payload: .object(["url": .string(url.absoluteString)]))
        }
    }

    func webBridge(_ bridge: MindboxWebBridge, didReceiveHTTPError url: String?) {
        guard noCacheRetryPolicy.onHTTPError(url: url, hasReceivedInit: isRegistered) else {
            Logger.common(message: "[EmbeddedBlock] Subresource error for \(url ?? "nil"), not healing",
                          level: .debug, category: .embeddedBlocks)
            return
        }

        Logger.common(message: "[EmbeddedBlock] Retrying the page's content with the cache bypassed (\(noCacheRetryPolicy.lastHTTPErrorDetail ?? "unknown"))",
                      level: .info, category: .embeddedBlocks)
        facade.retryContentLoadBypassingCache(failedURL: url) { [weak self] didRemoveAnything in
            self?.noCacheRetryPolicy.notePurgeOutcome(didRemoveAnything: didRemoveAnything)
        }
    }
}
