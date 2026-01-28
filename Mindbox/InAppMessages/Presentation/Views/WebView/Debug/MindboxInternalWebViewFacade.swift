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
    
    func start()
    func sendToJS(_ message: BridgeMessage)
    func setBridgeMessageDelegate(_ delegate: WebBridgeMessageDelegate?)
    func setNavigationDelegate(_ delegate: WebBridgeNavigationDelegate?)
    
    /// Test-only hook used by internal test apps to observe raw incoming `WKScriptMessage` objects.
    ///
    /// This is meant purely for visual/debug purposes (e.g. to display the unparsed message payload),
    /// and must not be used by production code or relied upon as part of the SDK API contract.
    func setWKScriptMessageDelegate(_ delegate: WebBridgeWKScriptMessageDelegate?)
}

public typealias WebViewLog = (String) -> Void
public typealias WebViewLogError = (String) -> Void

@_spi(Internal)
public final class MindboxInternalWebViewFacade: MindboxInternalWebViewFacadeProtocol {
    
    private let webView: MindboxWebView
    private let bridge: MindboxWebBridge
    private let params: [String: String]?
    
    private let log: WebViewLog
    private let logError: WebViewLogError
    
    public init(params: [String: String]?,
                userAgent: String,
                log: @escaping WebViewLog = { _ in },
                logError: @escaping WebViewLogError = { _ in }) {
        let webView = MindboxWebView(userAgent: userAgent)
        let bridge = MindboxWebBridge(webView: webView)
        
        self.webView = webView
        self.bridge = bridge
        self.params = params
        self.log = log
        self.logError = logError
    }
    
    public func makeView() -> UIView {
        webView
    }
    
    public func loadHTML(baseUrl: String,
                         contentUrl: String,
                         onFailure: @escaping () -> Void) {
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
    
    public func applyViewSettings(scrollViewDelegate: UIScrollViewDelegate?) {
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.delegate = scrollViewDelegate
        webView.scrollView.bounces = false
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
    }
    
    #warning("We did not set start method for the inapps.")
    public func start() {
        let message = BridgeMessage(
            type: .request,
            action: "start",
            payload: buildStartPayload()
        )
        bridge.send(message)
    }
    
    public func sendToJS(_ message: BridgeMessage) {
        bridge.send(message)
    }
    
    public func setBridgeMessageDelegate(_ delegate: WebBridgeMessageDelegate?) {
        bridge.messageDelegate = delegate
    }
    
    public func setNavigationDelegate(_ delegate: WebBridgeNavigationDelegate?) {
        bridge.navigationDelegate = delegate
    }
    
    public func setWKScriptMessageDelegate(_ delegate: WebBridgeWKScriptMessageDelegate?) {
        bridge.delegate = delegate
    }
}

extension MindboxInternalWebViewFacade {
    private func buildStartPayload() -> JSONValue {
        let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
        
        var mindboxParams: [String: String] = [
            "sdkVersion": Mindbox.shared.sdkVersion,
            "endpointId": persistenceStorage.configuration?.endpoint ?? "",
            "deviceUuid": persistenceStorage.deviceUUID ?? "",
            "sdkVersionNumeric": "\(Constants.Versions.sdkVersionNumeric)"
        ]

        if let params, !params.isEmpty {
            mindboxParams.merge(params) { _, new in new }
        }

        let payloadObject = mindboxParams.mapValues { JSONValue.string($0) }
        return .object(payloadObject)
    }
    
    private func fetchHTML(from urlString: String,
                           completion: @escaping (String?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil
        
        let session = URLSession(configuration: config)
        
        log("Fetching HTML from \(url.absoluteString)")
        
        let task = session.dataTask(with: url) { data, response, error in
            if let error {
                self.logError("Error fetching HTML: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                self.logError("Incorrect HTTP response")
                completion(nil)
                return
            }
            
            guard let data,
                  let htmlString = String(data: data, encoding: .utf8) else {
                self.logError("Failed to decode HTML data")
                completion(nil)
                return
            }
            
            self.log("HTML loaded successfully (\(htmlString.count) chars)")
            completion(htmlString)
        }
        
        task.resume()
    }
}
