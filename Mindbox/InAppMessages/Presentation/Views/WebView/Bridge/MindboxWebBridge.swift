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
    func webBridge(_ bridge: MindboxWebBridge, decidePolicyFor url: URL?, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void)
}

protocol BridgePendingStore: AnyObject {
    func addPending(_ id: UUID)
    func removePending(_ id: UUID)
    func containsPending(_ id: UUID) -> Bool
}

@_spi(Internal)
public final class MindboxWebBridge: NSObject {

    weak var delegate: WebBridgeWKScriptMessageDelegate?
    weak var messageDelegate: WebBridgeMessageDelegate?
    weak var navigationDelegate: WebBridgeNavigationDelegate?

    private lazy var dispatcher = BridgeMessageDispatcher(handlers: [RequestMessageHandler(),
                                                                     ResponseMessageHandler(),
                                                                     ErrorMessageHandler()])

    private weak var webView: WKWebView?
    private var pendingRequestIds = Set<UUID>()
    private var contentURL: URL?

    init(webView: WKWebView) {
        self.webView = webView
        super.init()

        let controller = webView.configuration.userContentController
        controller.add(self, name: Constants.WebViewBridgeJS.handlerName)
        webView.navigationDelegate = self
    }

    deinit {
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: Constants.WebViewBridgeJS.handlerName)
        webView?.navigationDelegate = nil
    }

    func send(_ message: BridgeMessage) {
        guard let json = message.jsonString() else {
            Logger.common(
                message: "[WebView] Bridge: failed to serialize message to JSON",
                category: .webViewInAppMessages
            )
            return
        }

        let sendLogMessage = "[WebView] Bridge -> JS: sending \(message.type.rawValue) id \(message.id). " +
            "message: version=\(message.version) action=\(message.action) " +
            "payload=\(String(describing: message.payloadAny)) timestamp=\(message.timestamp)"
        Logger.common(
            message: sendLogMessage,
            category: .webViewInAppMessages
        )

        switch message.type {
            case .request:
                pendingRequestIds.insert(message.id)
            case .response:
                pendingRequestIds.remove(message.id)
            case .error:
                pendingRequestIds.remove(message.id)
        }

        let script = Constants.WebViewBridgeJS.sendScript(json: json)

        guard let webView = webView else {
            Logger.common(
                message: "[WebView] Bridge: webView deallocated, cannot send message",
                category: .webViewInAppMessages
            )
            pendingRequestIds.remove(message.id)
            return
        }

        webView.evaluateJavaScript(script) { result, error in
            if let error = error {
                Logger.common(
                    message: "[WebView] Bridge: failed to send \(message.type.rawValue) id \(message.id) to JS. Error: \(error.localizedDescription)",
                    category: .webViewInAppMessages
                )
                self.pendingRequestIds.remove(message.id)
                return
            }

            guard let isSuccess = result as? Bool, isSuccess else {
                Logger.common(
                    message: "[WebView] Bridge: JS rejected \(message.type.rawValue) id \(message.id). Result: \(String(describing: result))",
                    category: .webViewInAppMessages
                )
                self.pendingRequestIds.remove(message.id)
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
}

extension MindboxWebBridge: WKScriptMessageHandler {
    public func userContentController(_ userContentController: WKUserContentController,
                                      didReceive message: WKScriptMessage) {
        guard message.name == Constants.WebViewBridgeJS.handlerName else {
            Logger.common(
                message: "[WebView] Bridge: received message with wrong handler name: \(message.name)",
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

        let receiveLogMessage = "[WebView] Bridge <- JS: received \(bridgeMessage.type.rawValue) id \(bridgeMessage.id). " +
            "message: version=\(bridgeMessage.version) action=\(bridgeMessage.action) " +
            "payload=\(String(describing: bridgeMessage.payloadAny)) timestamp=\(bridgeMessage.timestamp)"
        Logger.common(
            message: receiveLogMessage,
            category: .webViewInAppMessages
        )

        delegate?.webBridge(self, didReceiveFromJS: message)
        dispatcher.dispatch(bridgeMessage, in: self)
    }
}

extension MindboxWebBridge: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        navigationDelegate?.webBridge(self, didStartProvisionalNavigation: webView.url)
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        navigationDelegate?.webBridge(self, didFinishNavigation: contentURL ?? webView.url)
    }

    public func webView(_ webView: WKWebView,
                        didFailProvisionalNavigation navigation: WKNavigation!,
                        withError error: Error) {
        navigationDelegate?.webBridge(self, didFailProvisionalNavigation: webView.url, error: error)
    }

    public func webView(_ webView: WKWebView,
                        didFail navigation: WKNavigation!,
                        withError error: Error) {
        navigationDelegate?.webBridge(self, didFailProvisionalNavigation: webView.url, error: error)
    }
    
    public func webView(_ webView: WKWebView,
                        decidePolicyFor navigationAction: WKNavigationAction,
                        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let navigationDelegate = navigationDelegate {
            navigationDelegate.webBridge(self, decidePolicyFor: navigationAction.request.url, decisionHandler: decisionHandler)
        } else {
            decisionHandler(.allow)
        }
    }
}

extension MindboxWebBridge: BridgePendingStore {
    func addPending(_ id: UUID) {
        pendingRequestIds.insert(id)
    }

    func removePending(_ id: UUID) {
        pendingRequestIds.remove(id)
    }

    func containsPending(_ id: UUID) -> Bool {
        pendingRequestIds.contains(id)
    }
}
