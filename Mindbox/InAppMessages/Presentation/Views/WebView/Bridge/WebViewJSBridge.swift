//
//  WebViewJSBridge.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 26.01.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import WebKit
import MindboxLogger

@_spi(Internal)
public protocol WebBridgeScriptDelegate: AnyObject {
    func webBridge(_ bridge: WebBridge, didReceiveFromJS message: WKScriptMessage)
}

@_spi(Internal)
public protocol WebBridgeNavigationDelegate: AnyObject {
    func webBridge(_ bridge: WebBridge, didStartProvisionalNavigation url: URL?)
    func webBridge(_ bridge: WebBridge, didFinishNavigation url: URL?)
    func webBridge(_ bridge: WebBridge, didFailProvisionalNavigation url: URL?, error: Error)
    func webBridge(_ bridge: WebBridge, decidePolicyFor url: URL?, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void)
}

@_spi(Internal)
public final class WebBridge: NSObject {

    weak var delegate: WebBridgeScriptDelegate?
    weak var navigationDelegate: WebBridgeNavigationDelegate?

    private let webView: WKWebView
    private let handlerName: String
    private let bridgeVersion = 1
    private var pendingRequestIds = Set<UUID>()

    init(webView: WKWebView, handlerName: String = "SdkBridge") {
        self.webView = webView
        self.handlerName = handlerName
        super.init()

        let controller = webView.configuration.userContentController
        controller.add(self, name: handlerName)
        webView.navigationDelegate = self
    }

    deinit {
        let controller = webView.configuration.userContentController
        controller.removeScriptMessageHandler(forName: handlerName)
        webView.navigationDelegate = nil
    }

    func send(_ message: BridgeMessage) {
        guard let json = message.jsonString() else { return }

        if message.type == .request {
            pendingRequestIds.insert(message.id)
        }

        let script = "window.receiveFromSDK(\(json));"

        webView.evaluateJavaScript(script) { _, error in
            if let error {
            }
        }
    }
}

extension WebBridge: WKScriptMessageHandler {
    public func userContentController(_ userContentController: WKUserContentController,
                                      didReceive message: WKScriptMessage) {

        delegate?.webBridge(self, didReceiveFromJS: message)
        guard message.name == handlerName,
              let bridgeMessage = BridgeMessage.from(body: message.body)
        else {
            return
        }

        guard bridgeMessage.version == bridgeVersion else {
            return
        }

        switch bridgeMessage.type {
        case .request:
            break
        case .response:
            if pendingRequestIds.contains(bridgeMessage.id) {
                pendingRequestIds.remove(bridgeMessage.id)
                Logger.common(
                    message: "[WebView] Bridge: response matched id \(bridgeMessage.id)",
                    category: .webViewInAppMessages
                )
            } else {
                Logger.common(
                    message: "[WebView] Bridge: response id \(bridgeMessage.id) not found",
                    category: .webViewInAppMessages
                )
            }
        case .error:
            break
        }
    }
}

extension WebBridge: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        navigationDelegate?.webBridge(self, didStartProvisionalNavigation: webView.url)
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        navigationDelegate?.webBridge(self, didFinishNavigation: webView.url)
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
        navigationDelegate?.webBridge(self, decidePolicyFor: navigationAction.request.url, decisionHandler: decisionHandler)
    }
}
