//
//  WebViewJSBridge.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 26.01.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import WebKit

@_spi(Internal)
public protocol WebBridgeDelegate: AnyObject {
    func webBridge(_ bridge: WebBridge, didReceiveFromJS message: BridgeMessage)
}

@_spi(Internal)
public final class WebBridge: NSObject {

    weak var delegate: WebBridgeDelegate?

    private let webView: WKWebView
    private let handlerName: String

    init(webView: WKWebView, handlerName: String = "SdkBridge") {
        self.webView = webView
        self.handlerName = handlerName
        super.init()

        let controller = webView.configuration.userContentController
        controller.add(self, name: handlerName)
//        webView.navigationDelegate = self
    }

    deinit {
        let controller = webView.configuration.userContentController
        controller.removeScriptMessageHandler(forName: handlerName)
        webView.navigationDelegate = nil
    }

    func send(_ message: BridgeMessage) {
        guard let json = message.jsonString() else { return }

        let script = """
        window.__nativeBridge && window.__nativeBridge.receive(\(json));
        """

        webView.evaluateJavaScript(script, completionHandler: nil)
    }
}

extension WebBridge: WKScriptMessageHandler {
    public func userContentController(_ userContentController: WKUserContentController,
                                      didReceive message: WKScriptMessage) {

        guard message.name == handlerName,
              let bridgeMessage = BridgeMessage.from(body: message.body)
        else {
            return
        }

        delegate?.webBridge(self, didReceiveFromJS: bridgeMessage)
    }
}
//
//extension WebBridge: WKNavigationDelegate {
//    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
//        // инфраструктурные события при необходимости
//    }
//
//    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
//    }
//
//    public func webView(_ webView: WKWebView,
//                        didFail navigation: WKNavigation!,
//                        withError error: Error) {
//    }
//}
