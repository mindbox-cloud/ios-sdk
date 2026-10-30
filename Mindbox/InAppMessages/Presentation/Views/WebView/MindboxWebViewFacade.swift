//
//  MindboxWebViewFacade.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 16.01.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit
import WebKit
import MindboxLogger

@_spi(Internal)
public protocol InappWebViewFacadeProtocol: AnyObject {
    func makeView() -> UIView
    func loadHTML(baseUrl: String, contentUrl: String, onFailure: @escaping () -> Void)
    func applyViewSettings(scrollViewDelegate: UIScrollViewDelegate?)
    func cleanWebView()
    func endShow()

    func makeStartPayload(_ completion: @escaping (JSONValue) -> Void)

    func sendInitDataUpdated(params: [String: JSONValue])

    func sendToJS(_ message: BridgeMessage)
    func evaluateJavaScript(_ script: String, completion: @escaping (Result<Any?, Error>) -> Void)
    func setBridgeMessageDelegate(_ delegate: WebBridgeMessageDelegate?)
    func setNavigationDelegate(_ delegate: WebBridgeNavigationDelegate?)
    func retryContentLoadBypassingCache(failedURL: String?, onPurgeOutcome: @escaping (_ didRemoveAnything: Bool) -> Void)
    func releaseRetainedContent()
}

@_spi(Internal)
public typealias WebViewLog = (String) -> Void
@_spi(Internal)
public typealias WebViewLogError = (String) -> Void

@_spi(Internal)
public final class MindboxWebViewFacade: InappWebViewFacadeProtocol {

    private let webView: WKWebView
    let bridge: MindboxWebBridge
    private let warmWebViewLender: InAppWebViewPrewarmServiceProtocol?

    // Main-confined, like fetchTask, isClosed and the retained content: methods without a main hop are called on main.
    private var params: [String: JSONValue]?
    private let operation: (name: String, body: String)?
    private let inAppId: String

    private let log: WebViewLog
    private let logError: WebViewLogError

    private var fetchTask: URLSessionDataTask?
    private var isClosed = false

    private var retainedContentHTML: String?
    private var retainedContentBaseURL: URL?

    public convenience init(params: [String: JSONValue]?,
                            operation: (name: String, body: String)? = nil,
                            userAgent: String,
                            inAppId: String = "",
                            mayBorrowWarmWebView: Bool = true,
                            log: @escaping WebViewLog = { _ in },
                            logError: @escaping WebViewLogError = { _ in }) {
        self.init(params: params,
                  operation: operation,
                  userAgent: userAgent,
                  inAppId: inAppId,
                  prewarmService: mayBorrowWarmWebView ? DI.injectOrFail(InAppWebViewPrewarmServiceProtocol.self) : nil,
                  log: log,
                  logError: logError)
    }

    init(params: [String: JSONValue]?,
         operation: (name: String, body: String)?,
         userAgent: String,
         inAppId: String,
         prewarmService: InAppWebViewPrewarmServiceProtocol?,
         log: @escaping WebViewLog,
         logError: @escaping WebViewLogError) {
        // A warm instance serves only the stock UA: applicationNameForUserAgent is fixed when the prewarm creates it.
        let webView: WKWebView
        if let prewarmService,
           userAgent == SDKUserAgent.build(),
           let warm = prewarmService.borrowWarmWebView() {
            webView = warm
            warmWebViewLender = prewarmService
        } else {
            webView = InAppWebViewFactory.make(userAgent: userAgent)
            warmWebViewLender = nil
        }
        let bridge = MindboxWebBridge(webView: webView)

        self.webView = webView
        self.bridge = bridge
        self.params = params
        self.operation = operation
        self.inAppId = inAppId
        self.log = log
        self.logError = logError
    }

    deinit {
        fetchTask?.cancel()
        // A borrowed warm instance may already serve the next show, so only an owned web view's bridge is detached here.
        if warmWebViewLender == nil {
            bridge.detach()
        }
    }

    public func makeView() -> UIView {
        webView
    }
    
    public func loadHTML(baseUrl: String,
                         contentUrl: String,
                         onFailure: @escaping () -> Void) {
        let url = URL(string: baseUrl)
        let contentURL = URL(string: contentUrl)
        bridge.updateContentURL(contentURL)
        
        fetchHTML(from: contentUrl) { [weak self] html in
            DispatchQueue.main.async {
                guard let self, !self.isClosed else { return }
                guard let html else {
                    onFailure()
                    return
                }
                self.retainedContentHTML = html
                self.retainedContentBaseURL = url
                self.bridge.expectContentNavigation(self.webView.loadHTMLString(html, baseURL: url))
            }
        }
    }

    public func retryContentLoadBypassingCache(failedURL: String?, onPurgeOutcome: @escaping (_ didRemoveAnything: Bool) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.isClosed, let html = self.retainedContentHTML else { return }
            let baseURL = self.retainedContentBaseURL
            InAppWebViewDataStore.purgeCache(forHostOf: failedURL) { [weak self] didRemoveAnything in
                onPurgeOutcome(didRemoveAnything)
                guard let self, !self.isClosed else { return }
                self.bridge.expectContentNavigation(self.webView.loadHTMLString(html, baseURL: baseURL))
            }
        }
    }

    public func releaseRetainedContent() {
        DispatchQueue.main.async { [weak self] in
            self?.retainedContentHTML = nil
            self?.retainedContentBaseURL = nil
        }
    }

    public func cleanWebView() {
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.isClosed else { return }
            self.isClosed = true
            self.fetchTask?.cancel()
            self.fetchTask = nil
            self.webView.stopLoading()
        }
    }

    public func endShow() {
        guard !isClosed else { return }
        isClosed = true
        fetchTask?.cancel()
        fetchTask = nil
        if let warmWebViewLender {
            warmWebViewLender.returnWarmWebView(webView)
        } else {
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
    
    public func makeStartPayload(_ completion: @escaping (JSONValue) -> Void) {
        WebViewStartPayloadBuilder(contentId: inAppId,
                                   operation: operation,
                                   customParams: params,
                                   insetsSource: webView,
                                   logError: logError).build(completion)
    }
    
    public func sendInitDataUpdated(params: [String: JSONValue]) {
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.isClosed else { return }

            self.params = params

            self.makeStartPayload { [weak self] payload in
                guard let self, !self.isClosed, self.params == params else { return }

                self.bridge.send(BridgeMessage(type: .request,
                                               action: BridgeMessage.Action.initDataUpdated,
                                               payload: payload))
            }
        }
    }

    public func sendToJS(_ message: BridgeMessage) {
        guard !isClosed else { return }
        bridge.send(message)
    }

    public func evaluateJavaScript(_ script: String, completion: @escaping (Result<Any?, Error>) -> Void) {
        let evaluate = { [weak self] in
            guard let self, !self.isClosed else {
                let error = MindboxError.internalError(
                    InternalError(
                        errorKey: .general,
                        reason: "WebView page was closed before JavaScript execution"
                    )
                )
                completion(.failure(error))
                return
            }
            self.webView.evaluateJavaScript(script) { result, error in
                if let error {
                    completion(.failure(error))
                } else {
                    completion(.success(result))
                }
            }
        }
        if Thread.isMainThread {
            evaluate()
        } else {
            DispatchQueue.main.async(execute: evaluate)
        }
    }
    
    public func setBridgeMessageDelegate(_ delegate: WebBridgeMessageDelegate?) {
        bridge.messageDelegate = delegate
    }
    
    public func setNavigationDelegate(_ delegate: WebBridgeNavigationDelegate?) {
        bridge.navigationDelegate = delegate
    }
}

extension MindboxWebViewFacade {

    private func fetchHTML(from urlString: String,
                           completion: @escaping (String?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }

        if url.scheme == "data" {
            completion((try? Data(contentsOf: url)).flatMap { String(data: $0, encoding: .utf8) })
            return
        }

        let (session, request) = InAppWebViewHTMLFetcher.sessionAndRequest(for: url)

        log("Fetching HTML from \(url.absoluteString)")

        // Capture the loggers, not the facade: the completion runs on URLSession's queue and must not release the facade off main.
        let task = session.dataTask(with: request) { [log, logError] data, response, error in
            if let error {
                logError("Error fetching HTML: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                logError("Incorrect HTTP response")
                completion(nil)
                return
            }

            guard let data,
                  let htmlString = String(data: data, encoding: .utf8) else {
                logError("Failed to decode HTML data")
                completion(nil)
                return
            }

            log("HTML loaded successfully (\(htmlString.count) chars)")
            completion(htmlString)
        }

        fetchTask = task
        task.resume()
    }
}
