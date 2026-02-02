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
    private let handlerName = "SdkBridge"
    private var pendingRequestIds = Set<UUID>()

    init(webView: WKWebView) {
        self.webView = webView
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
        } else if message.type == .response {
            pendingRequestIds.remove(message.id)
        }

        let script = "window.receiveFromSDK(\(json));"

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
}

extension MindboxWebBridge: WKScriptMessageHandler {
    public func userContentController(_ userContentController: WKUserContentController,
                                      didReceive message: WKScriptMessage) {
        delegate?.webBridge(self, didReceiveFromJS: message)

        guard message.name == handlerName,
              let bridgeMessage = BridgeMessage.from(body: message.body),
              bridgeMessage.version == Constants.Versions.webBridgeVersion
        else {
            return
        }

        dispatcher.dispatch(bridgeMessage, in: self)
    }
}

extension MindboxWebBridge: WKNavigationDelegate {
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
