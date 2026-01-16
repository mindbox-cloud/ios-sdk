//
//  MindboxTestWebViewFacade.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 16.01.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit
import WebKit

@_spi(Internal)
public protocol MindboxTestWebViewFacadeProtocol: AnyObject {
    func makeView() -> UIView
    func loadHTML(baseUrl: String, contentUrl: String, onFailure: @escaping () -> Void)
    func reloadWebView()
    func cleanWebView()
    func setUserAgent(_ userAgent: String)
    func applyViewSettings(scrollViewDelegate: UIScrollViewDelegate?)
}

@_spi(Internal)
public final class MindboxTestWebViewFacade: MindboxTestWebViewFacadeProtocol {
    
    private let webView: MindboxWebView
    
    public init(params: [String: String]?,
                userAgent: String,
                messageHandler: WKScriptMessageHandler,
                navigationDelegate: WKNavigationDelegate?) {
        self.webView = MindboxWebView(params: params,
                                      userAgent: userAgent,
                                      messageHandler: messageHandler,
                                      navigationDelegate: navigationDelegate)
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
    
    public func loadHTML(baseUrl: String,
                         contentUrl: String,
                         onFailure: @escaping () -> Void) {
        let url = URL(string: baseUrl)
        
        MindboxWebView.fetchHTMLContent(from: contentUrl) { [weak webView] html in
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
            webView.navigationDelegate = nil
            webView.uiDelegate = nil
            webView.configuration.userContentController
                .removeScriptMessageHandler(forName: MindboxWebView.sdkBridgeHandlerName)
        }
    }
    
    public func setUserAgent(_ userAgent: String) {
        DispatchQueue.main.async { [weak webView] in
            webView?.customUserAgent = userAgent
        }
    }
}
