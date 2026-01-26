//
//  MindboxInternalWebViewFacade.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 16.01.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit
import WebKit

@_spi(Internal)
public protocol MindboxInternalWebViewFacadeProtocol: AnyObject {
    func makeView() -> UIView
    func loadHTML(baseUrl: String, contentUrl: String, onFailure: @escaping () -> Void)
    func reloadWebView()
    func cleanWebView()
    func applyViewSettings(scrollViewDelegate: UIScrollViewDelegate?)
    
    func sendToJS(_ message: BridgeMessage)
    func setBridgeDelegate(_ delegate: WebBridgeDelegate?)
}

@_spi(Internal)
public final class MindboxInternalWebViewFacade: MindboxInternalWebViewFacadeProtocol {

    private let webView: MindboxWebView
    private let bridge: WebBridge

    public init(params: [String: String]?, userAgent: String) {
        let webView = MindboxWebView(params: params, userAgent: userAgent)
        let bridge = WebBridge(webView: webView, handlerName: MindboxWebView.sdkBridgeHandlerName)

        self.webView = webView
        self.bridge = bridge
    }

    public func setBridgeDelegate(_ delegate: WebBridgeDelegate?) {
        bridge.delegate = delegate
    }

    public func sendToJS(_ message: BridgeMessage) {
        bridge.send(message)
    }

    public func makeView() -> UIView {
        webView
    }

    public func applyViewSettings(scrollViewDelegate: UIScrollViewDelegate?) {
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.delegate = scrollViewDelegate
        webView.scrollView.bounces = false
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
    }

    public func loadHTML(
        baseUrl: String,
        contentUrl: String,
        onFailure: @escaping () -> Void
    ) {
        let url = URL(string: baseUrl)

        fetchHTML(from: contentUrl) { [weak webView] html in
            guard let webView else { return }

            if let html {
                DispatchQueue.main.async {
                    webView.loadHTMLString(html, baseURL: url)
                }
            } else {
                DispatchQueue.main.async {
                    onFailure()
                }
            }
        }
    }

    public func reloadWebView() {
        DispatchQueue.main.async { [weak webView] in
            webView?.reload()
        }
    }

    public func cleanWebView() {
        DispatchQueue.main.async { [weak webView] in
            guard let webView else { return }
            webView.stopLoading()
        }
    }
}

extension MindboxInternalWebViewFacade {
    private func fetchHTML(
        from urlString: String,
        completion: @escaping (String?) -> Void
    ) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }

        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil

        let session = URLSession(configuration: config)
        session.dataTask(with: url) { data, response, error in
            guard
                error == nil,
                let http = response as? HTTPURLResponse,
                (200...299).contains(http.statusCode),
                let data,
                let html = String(data: data, encoding: .utf8)
            else {
                completion(nil)
                return
            }

            completion(html)
        }.resume()
    }
}
