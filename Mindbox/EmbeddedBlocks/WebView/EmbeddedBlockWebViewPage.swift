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

final class EmbeddedBlockWebViewPage: NSObject, EmbeddedBlockPageHosting {

    var view: UIView { pageView }

    var onContentRendered: ((Int) -> Void)?

    var onUnreadableContentReport: (() -> Void)?

    var onShowableQuestion: (([String], @escaping ([String]) -> Void) -> Void)?

    var onShowInAppRequest: ((String, [String: JSONValue], @escaping (Result<Void, BridgeErrorCode>) -> Void) -> Void)?

    var onDataPushConfirmed: (() -> Void)?

    var onLoadFailure: ((String) -> Void)?

    var isUserPresent = true

    private let content: EmbeddedBlockWebContent
    let facade: InappWebViewFacadeProtocol
    private let registry: MindboxWebPageRegistry
    private let actionRegistry: WebBridgeActionRegistry
    private let pageView: UIView

    private var isRegistered = false

    private let noCacheRetryPolicy: WebViewNoCacheRetryPolicy

    init(content: EmbeddedBlockWebContent,
         facade: InappWebViewFacadeProtocol? = nil,
         registry: MindboxWebPageRegistry = .shared,
         actionRegistry: WebBridgeActionRegistry
         = WebBridgeActionRegistry(handlers: WebBridgeActionHandlerFactory.makeHandlers()),
         noCacheRetryPolicy: WebViewNoCacheRetryPolicy = WebViewNoCacheRetryPolicy()) {
        self.content = content
        self.noCacheRetryPolicy = noCacheRetryPolicy
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

    func load() {
        facade.loadHTML(baseUrl: content.baseUrl, contentUrl: content.contentUrl) { [weak self] in
            Logger.common(message: "[EmbeddedBlock] Failed to load page markup from '\(self?.content.contentUrl ?? "")'",
                          level: .error, category: .embeddedBlocks)
            self?.onLoadFailure?("Failed to fetch page HTML")
        }
    }

    func cancel() {
        facade.endShow()
    }

    func sendInitData(params: [String: JSONValue]) {
        facade.sendInitDataUpdated(params: params)
    }

    private func applyViewSettings() {
        pageView.backgroundColor = .clear

        guard let webView = pageView as? WKWebView else { return }

        webView.isOpaque = false
        webView.scrollView.backgroundColor = .clear

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

    var tags: [String: String]? { content.tags }

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

    func makeStartPayload(_ completion: @escaping (JSONValue) -> Void) {
        facade.makeStartPayload(completion)
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

// MARK: - WebBridgeInappRequestHosting

extension EmbeddedBlockWebViewPage: WebBridgeInappRequestHosting {

    func bridgeDidAskShowableInapps(_ ids: [String], completion: @escaping ([String]) -> Void) {
        onShowableQuestion?(ids, completion)
    }

    func bridgeDidRequestShowInApp(id: String,
                                   params: [String: JSONValue],
                                   completion: @escaping (Result<Void, BridgeErrorCode>) -> Void) {
        onShowInAppRequest?(id, params, completion)
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
        if message.type == .response, message.parsedAction == .initDataUpdated {
            onDataPushConfirmed?()
            return
        }

        if message.type == .request, message.parsedAction == .ready {
            registerForBroadcasts()
        }

        actionRegistry.handle(message, host: self)
    }

    private func registerForBroadcasts() {
        guard !isRegistered else { return }

        isRegistered = true
        registry.register(self)
        facade.releaseRetainedContent()
    }
}

// MARK: - Navigation

extension EmbeddedBlockWebViewPage: WebBridgeNavigationDelegate {

    func webBridge(_ bridge: MindboxWebBridge, didStartProvisionalNavigation url: URL?) {
        Logger.common(message: "[EmbeddedBlock] Page started loading \(url?.absoluteString ?? "unknown")",
                      category: .embeddedBlocks)
    }

    func webBridge(_ bridge: MindboxWebBridge, didFinishNavigation url: URL?) {
        Logger.common(message: "[EmbeddedBlock] Page of in-app \(content.inAppId) loaded its document, waiting for it to report itself",
                      category: .embeddedBlocks)
    }

    func webBridge(_ bridge: MindboxWebBridge, didFailProvisionalNavigation url: URL?, error: Error) {
        let error = error as NSError

        guard !(error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled) else {
            Logger.common(message: "[EmbeddedBlock] Page navigation was cancelled, not a load failure",
                          category: .embeddedBlocks)
            return
        }

        Logger.common(message: "[EmbeddedBlock] Page navigation failed: \(error.localizedDescription)",
                      level: .error, category: .embeddedBlocks)
        onLoadFailure?("Page failed to load: \(error.code) \(error.localizedDescription)")
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
