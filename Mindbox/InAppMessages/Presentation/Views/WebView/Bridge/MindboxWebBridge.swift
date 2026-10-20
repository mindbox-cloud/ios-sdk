//
//  MindboxWebBridge.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 26.01.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import WebKit
import MindboxLogger
import UIKit

@_spi(Internal)
public protocol WebBridgeMessageDelegate: AnyObject {
    func webBridge(_ bridge: MindboxWebBridge, didReceiveBridgeMessage message: BridgeMessage)
}

@_spi(Internal)
public protocol WebBridgeNavigationDelegate: AnyObject {
    func webBridge(_ bridge: MindboxWebBridge, didStartProvisionalNavigation url: URL?)
    func webBridge(_ bridge: MindboxWebBridge, didFinishNavigation url: URL?)
    func webBridge(_ bridge: MindboxWebBridge, didFailProvisionalNavigation url: URL?, error: Error)
    func webBridge(_ bridge: MindboxWebBridge, decidePolicyFor url: URL?, navigationType: WKNavigationType, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void)
    func webBridge(_ bridge: MindboxWebBridge, didReceiveHTTPError url: String?)
}

@_spi(Internal)
public extension WebBridgeNavigationDelegate {
    func webBridge(_ bridge: MindboxWebBridge, didReceiveHTTPError url: String?) {}
}

protocol BridgePendingStore: AnyObject {
    func removePending(_ id: UUID)
    func containsPending(_ id: UUID) -> Bool
}

@_spi(Internal)
public final class MindboxWebBridge: NSObject {

    weak var messageDelegate: WebBridgeMessageDelegate?
    weak var navigationDelegate: WebBridgeNavigationDelegate?

    private lazy var dispatcher = BridgeMessageDispatcher(handlers: [RequestMessageHandler(),
                                                                     ResponseMessageHandler(),
                                                                     ErrorMessageHandler()])

    private weak var webView: WKWebView?
    private var pendingRequestIds = Set<UUID>()
    private var contentURL: URL?

    private var expectedNavigation: WKNavigation?
    private var expectedNavigationFinished = false
    private var expectedNavigationCommitted = false
    private var contentLoadIssued = false

    init(webView: WKWebView) {
        self.webView = webView
        super.init()

        let controller = webView.configuration.userContentController
        controller.removeScriptMessageHandler(forName: Constants.WebViewBridgeJS.handlerName)
        controller.add(self, name: Constants.WebViewBridgeJS.handlerName)
        controller.removeScriptMessageHandler(forName: Constants.WebViewHTTPErrorJS.handlerName)
        controller.add(self, name: Constants.WebViewHTTPErrorJS.handlerName)
        webView.navigationDelegate = self
    }

    func detach() {
        assert(Thread.isMainThread)
        guard let webView else { return }

        let controller = webView.configuration.userContentController
        controller.removeScriptMessageHandler(forName: Constants.WebViewBridgeJS.handlerName)
        controller.removeScriptMessageHandler(forName: Constants.WebViewHTTPErrorJS.handlerName)
        if webView.navigationDelegate === self {
            webView.navigationDelegate = nil
        }
    }

    func send(_ message: BridgeMessage) {
        guard let json = message.jsonString() else {
            Logger.common(
                message: "[WebView] Bridge: failed to serialize message to JSON",
                category: .webViewInAppMessages
            )
            return
        }

        #if DEBUG
        let payloadDescription = message.prettyPayloadDescription()
        let sendLogMessage = "[WebView] Bridge -> JS: sending \(message.type.rawValue) id \(message.id). " +
            "message: version=\(message.version) action=\(message.action) timestamp=\(message.timestamp)\n" +
            "payload:\n\(payloadDescription)"
        #else
        let sendLogMessage = "[WebView] Bridge -> JS: sending \(message.type.rawValue) id \(message.id). " +
            "message: version=\(message.version) action=\(message.action) " +
            "payload=\(String(describing: message.payloadAny)) timestamp=\(message.timestamp)"
        #endif
        Logger.common(
            message: sendLogMessage,
            category: .webViewInAppMessages
        )

        let tracksPending = message.type == .request
        if tracksPending {
            pendingRequestIds.insert(message.id)
        }

        let script = Constants.WebViewBridgeJS.sendScript(json: json)

        guard let webView = webView else {
            Logger.common(
                message: "[WebView] Bridge: webView deallocated, cannot send message",
                category: .webViewInAppMessages
            )
            if tracksPending { pendingRequestIds.remove(message.id) }
            return
        }

        webView.evaluateJavaScript(script) { result, error in
            if let error = error {
                Logger.common(
                    message: "[WebView] Bridge: failed to send \(message.type.rawValue) id \(message.id) to JS. Error: \(error.localizedDescription)",
                    category: .webViewInAppMessages
                )
                if tracksPending { self.pendingRequestIds.remove(message.id) }
                return
            }

            guard let isSuccess = result as? Bool, isSuccess else {
                Logger.common(
                    message: "[WebView] Bridge: JS rejected \(message.type.rawValue) id \(message.id). Result: \(String(describing: result))",
                    category: .webViewInAppMessages
                )
                if tracksPending { self.pendingRequestIds.remove(message.id) }
                return
            }

            Logger.common(
                message: "[WebView] Bridge: \(message.type.rawValue) id \(message.id) delivered to JS successfully",
                category: .webViewInAppMessages
            )
        }
    }

    func updateContentURL(_ url: URL?) {
        contentURL = url
    }

    func expectContentNavigation(_ navigation: WKNavigation?) {
        contentLoadIssued = true
        expectedNavigation = navigation
        expectedNavigationFinished = false
        expectedNavigationCommitted = false
    }

    private func isStaleNavigation(_ navigation: WKNavigation?) -> Bool {
        if expectedNavigationFinished { return false }
        guard contentLoadIssued else { return true }
        guard let navigation else { return false }
        guard let expected = expectedNavigation else { return false }
        return navigation !== expected
    }

    private func logStaleNavigation(_ event: String) {
        Logger.common(
            message: "[WebView] Bridge: ignoring stale navigation \(event) (leftover load on reused WebView)",
            category: .webViewInAppMessages
        )
    }
}

extension MindboxWebBridge: WKScriptMessageHandler {
    public func userContentController(_ userContentController: WKUserContentController,
                                      didReceive message: WKScriptMessage) {
        if message.name == Constants.WebViewHTTPErrorJS.handlerName {
            guard expectedNavigationCommitted else {
                logStaleNavigation("http error message")
                return
            }
            guard let failedURL = InAppWebViewHTTPError.failedResourceURL(from: message.body) else { return }
            navigationDelegate?.webBridge(self, didReceiveHTTPError: failedURL)
            return
        }

        guard message.name == Constants.WebViewBridgeJS.handlerName else {
            Logger.common(
                message: "[WebView] Bridge: received message with wrong handler name: \(message.name)",
                category: .webViewInAppMessages
            )
            return
        }

        guard expectedNavigationCommitted else {
            Logger.common(
                message: "[WebView] Bridge: ignoring JS message before the show's document committed (leftover page on reused WebView)",
                category: .webViewInAppMessages
            )
            return
        }

        guard let bridgeMessage = BridgeMessage.from(body: message.body) else {
            Logger.common(
                message: "[WebView] Bridge: failed to parse message from JS. Body: \(String(describing: message.body))",
                category: .webViewInAppMessages
            )
            return
        }

        guard bridgeMessage.version >= Constants.Versions.webBridgeVersion else {
            Logger.common(
                message: "[WebView] Bridge: received message with unsupported version \(bridgeMessage.version), expected >= \(Constants.Versions.webBridgeVersion)",
                category: .webViewInAppMessages
            )
            return
        }

        #if DEBUG
        let payloadDescription = bridgeMessage.prettyPayloadDescription()
        let receiveLogMessage = "[WebView] Bridge <- JS: received \(bridgeMessage.type.rawValue) id \(bridgeMessage.id). " +
            "message: version=\(bridgeMessage.version) action=\(bridgeMessage.action) timestamp=\(bridgeMessage.timestamp)\n" +
            "payload:\n\(payloadDescription)"
        #else
        let receiveLogMessage = "[WebView] Bridge <- JS: received \(bridgeMessage.type.rawValue) id \(bridgeMessage.id). " +
            "message: version=\(bridgeMessage.version) action=\(bridgeMessage.action) " +
            "payload=\(String(describing: bridgeMessage.payloadAny)) timestamp=\(bridgeMessage.timestamp)"
        #endif
        Logger.common(
            message: receiveLogMessage,
            category: .webViewInAppMessages
        )

        dispatcher.dispatch(bridgeMessage, in: self)
    }
}

extension MindboxWebBridge: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        guard !isStaleNavigation(navigation) else {
            logStaleNavigation("start")
            return
        }
        navigationDelegate?.webBridge(self, didStartProvisionalNavigation: webView.url)
    }

    public func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        guard !isStaleNavigation(navigation) else {
            logStaleNavigation("commit")
            return
        }
        expectedNavigationCommitted = true
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !isStaleNavigation(navigation) else {
            logStaleNavigation("finish")
            return
        }
        let isExpected = navigation === expectedNavigation
        if isExpected {
            expectedNavigationFinished = true
        }
        navigationDelegate?.webBridge(self, didFinishNavigation: isExpected ? (contentURL ?? webView.url) : webView.url)
    }

    public func webView(_ webView: WKWebView,
                        didFailProvisionalNavigation navigation: WKNavigation!,
                        withError error: Error) {
        guard !isStaleNavigation(navigation) else {
            logStaleNavigation("provisional failure: \(error.localizedDescription)")
            return
        }
        navigationDelegate?.webBridge(self, didFailProvisionalNavigation: webView.url, error: error)
    }

    public func webView(_ webView: WKWebView,
                        didFail navigation: WKNavigation!,
                        withError error: Error) {
        guard !isStaleNavigation(navigation) else {
            logStaleNavigation("failure: \(error.localizedDescription)")
            return
        }
        navigationDelegate?.webBridge(self, didFailProvisionalNavigation: webView.url, error: error)
    }
    
    public func webView(_ webView: WKWebView,
                        decidePolicyFor navigationAction: WKNavigationAction,
                        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let navigationDelegate = navigationDelegate {
            navigationDelegate.webBridge(self, decidePolicyFor: navigationAction.request.url, navigationType: navigationAction.navigationType, decisionHandler: decisionHandler)
        } else {
            decisionHandler(.allow)
        }
    }
}

extension MindboxWebBridge: BridgePendingStore {
    func removePending(_ id: UUID) {
        pendingRequestIds.remove(id)
    }

    func containsPending(_ id: UUID) -> Bool {
        pendingRequestIds.contains(id)
    }
}
