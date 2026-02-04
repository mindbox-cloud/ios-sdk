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

    private let webView: WKWebView
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
        let controller = webView.configuration.userContentController
        controller.removeScriptMessageHandler(forName: Constants.WebViewBridgeJS.handlerName)
        webView.navigationDelegate = nil
    }

    func send(_ message: BridgeMessage) {
        guard let json = message.jsonString() else { return }

        switch message.type {
            case .request:
                pendingRequestIds.insert(message.id)
            case .response:
                pendingRequestIds.remove(message.id)
            case .error:
                pendingRequestIds.remove(message.id)
        }
        
        let script = Constants.WebViewBridgeJS.sendScript(json: json)

        webView.evaluateJavaScript(script) { result, error in
            guard error == nil else {
                self.pendingRequestIds.remove(message.id)
                return
            }

            guard let isSuccess = result as? Bool, isSuccess else {
                self.pendingRequestIds.remove(message.id)
                return
            }
        }
    }

    func updateContentURL(_ url: URL?) {
        contentURL = url
    }
}

extension MindboxWebBridge: WKScriptMessageHandler {
    public func userContentController(_ userContentController: WKUserContentController,
                                      didReceive message: WKScriptMessage) {
        guard message.name == Constants.WebViewBridgeJS.handlerName,
              let bridgeMessage = BridgeMessage.from(body: message.body),
              bridgeMessage.version >= Constants.Versions.webBridgeVersion
        else {
            return
        }
        
        delegate?.webBridge(self, didReceiveFromJS: message) // Проверить что в нужном месте стоит.
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
