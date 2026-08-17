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

    func makeStartPayload() -> JSONValue

    /// Pushes the start payload again, unprompted, after the config behind this page changed.
    ///
    /// `params` replace the ones the page was created with, because they are the part of the payload the
    /// config owns — a feed's catalog of stories lives there.
    func sendInitDataUpdated(params: [String: JSONValue])

    func sendToJS(_ message: BridgeMessage)
    func evaluateJavaScript(_ script: String, completion: @escaping (Result<Any?, Error>) -> Void)
    func setBridgeMessageDelegate(_ delegate: WebBridgeMessageDelegate?)
    func setNavigationDelegate(_ delegate: WebBridgeNavigationDelegate?)
    func retryContentLoadBypassingCache(failedURL: String?, onPurgeOutcome: @escaping (_ didRemoveAnything: Bool) -> Void)
    func releaseRetainedContent()
}

@_spi(Internal)
public extension InappWebViewFacadeProtocol {
    // Defaults so existing conformers (mocks, test apps) keep compiling. The cost of having them: a
    // conformer whose signature drifts from the requirement does not fail to compile — the default
    // silently becomes its witness, and the call turns into a no-op.
    func retryContentLoadBypassingCache(failedURL: String?, onPurgeOutcome: @escaping (_ didRemoveAnything: Bool) -> Void) {}
    func releaseRetainedContent() {}
    func sendInitDataUpdated(params: [String: JSONValue]) {}
}

@_spi(Internal)
public protocol MindboxInternalWebViewFacadeProtocol: InappWebViewFacadeProtocol {
    func reloadWebView()
    func cleanWebView()

    /// Test-only hook used by internal test apps to observe raw incoming `WKScriptMessage` objects.
    ///
    /// This is meant purely for visual/debug purposes (e.g. to display the unparsed message payload),
    /// and must not be used by production code or relied upon as part of the SDK API contract.
    func setWKScriptMessageDelegate(_ delegate: WebBridgeWKScriptMessageDelegate?)
}

@_spi(Internal)
public typealias WebViewLog = (String) -> Void
@_spi(Internal)
public typealias WebViewLogError = (String) -> Void

@_spi(Internal)
public final class MindboxWebViewFacade: MindboxInternalWebViewFacadeProtocol {

    private let webView: WKWebView
    private let bridge: MindboxWebBridge

    /// Not constant: a new config can change the params behind a live page, and the next start payload
    /// has to carry the new ones. Main-confined, like every other send on this facade.
    private var params: [String: JSONValue]?
    private let operation: (name: String, body: String)?
    private let inAppId: String

    private let log: WebViewLog
    private let logError: WebViewLogError

    // Main-confined. A borrowed prewarmed `webView` outlives this facade (the prewarm
    // service keeps it warm across shows), so a `[weak webView]` guard is not enough to
    // stop a slow fetch that completes after the show closed — it would load the dead
    // show's page into the parked hidden instance. `isClosed` gates the load and the
    // in-flight fetch is cancelled outright on teardown.
    private var fetchTask: URLSessionDataTask?
    private var isClosed = false

    // Main-confined. The content page is retained so a poisoned-cache HTTP error can be
    // answered by reloading the exact same page after the purge (mirror of Android's
    // `lastLoadedContent`). Released on `init` — after it the page has proven it can boot
    // and a reload would tear down a live in-app.
    private var retainedContentHTML: String?
    private var retainedContentBaseURL: URL?

    public init(params: [String: JSONValue]?,
                operation: (name: String, body: String)? = nil,
                userAgent: String,
                inAppId: String = "",
                mayBorrowWarmWebView: Bool = true,
                log: @escaping WebViewLog = { _ in },
                logError: @escaping WebViewLogError = { _ in }) {
        // Borrow the prewarmed live instance when available (kept across shows — hidden,
        // not destroyed); otherwise create one on the same shared data store so cached
        // resources stay visible either way. A warm instance can only serve a caller that
        // wants the stock UA: its applicationNameForUserAgent was baked at prewarm
        // creation and cannot change on a live WKWebView.
        //
        // A surface opts out when it would hold the instance instead of passing it on: an
        // overlay borrows for the seconds it is shown, an embedded block lives as long as
        // its screen does, so a block taking the warm instance would cost every later in-app
        // its head start.
        let webView: WKWebView
        if mayBorrowWarmWebView,
           userAgent == SDKUserAgent.build(),
           let warm = DI.injectOrFail(InAppWebViewPrewarmServiceProtocol.self).borrowWarmWebView() {
            webView = warm
        } else {
            webView = InAppWebViewFactory.make(userAgent: userAgent)
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
        // The fetch completion holds only a weak self, so a pending request can outlive
        // the facade; cancel it so it can never resume work against a reused webView.
        fetchTask?.cancel()
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
                // A show that closed while the fetch was in flight must not load into the
                // (possibly reused) webView, and must not re-report failure — it is already
                // tearing down.
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
                // The reload must be sequenced strictly after the purge completes —
                // re-fetching before the poisoned entry is gone would just replay it.
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

    public func reloadWebView() {
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.isClosed else { return }
            self.bridge.expectContentNavigation(self.webView.reload())
        }
    }

    public func cleanWebView() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isClosed = true
            self.fetchTask?.cancel()
            self.fetchTask = nil
            self.webView.stopLoading()
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
    
    public func makeStartPayload() -> JSONValue {
        WebViewStartPayloadBuilder(contentId: inAppId,
                                   operation: operation,
                                   customParams: params,
                                   insetsSource: webView,
                                   logError: logError).build()
    }
    
    public func sendInitDataUpdated(params: [String: JSONValue]) {
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.isClosed else { return }

            self.params = params

            self.bridge.send(BridgeMessage(type: .request,
                                           action: BridgeMessage.Action.initDataUpdated,
                                           payload: self.makeStartPayload()))
        }
    }

    public func sendToJS(_ message: BridgeMessage) {
        bridge.send(message)
    }

    public func evaluateJavaScript(_ script: String, completion: @escaping (Result<Any?, Error>) -> Void) {
        DispatchQueue.main.async { [weak webView] in
            guard let webView else {
                let error = MindboxError.internalError(
                    InternalError(
                        errorKey: .general,
                        reason: "WebView was deallocated before JavaScript execution"
                    )
                )
                completion(.failure(error))
                return
            }
            webView.evaluateJavaScript(script) { result, error in
                if let error {
                    completion(.failure(error))
                } else {
                    completion(.success(result))
                }
            }
        }
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

extension MindboxWebViewFacade {

    private func fetchHTML(from urlString: String,
                           completion: @escaping (String?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }

        // A data: url carries its document in itself — the embedded-block debug override packs
        // markup this way. It never travels over HTTP, so the fetch below and its status check do
        // not apply; going through URLSession would only die on the HTTPURLResponse cast.
        if url.scheme == "data" {
            completion((try? Data(contentsOf: url)).flatMap { String(data: $0, encoding: .utf8) })
            return
        }

        let (session, request) = InAppWebViewHTMLFetcher.sessionAndRequest(for: url)

        log("Fetching HTML from \(url.absoluteString)")

        let task = session.dataTask(with: request) { [weak self] data, response, error in
            if let error {
                self?.logError("Error fetching HTML: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                self?.logError("Incorrect HTTP response")
                completion(nil)
                return
            }

            guard let data,
                  let htmlString = String(data: data, encoding: .utf8) else {
                self?.logError("Failed to decode HTML data")
                completion(nil)
                return
            }

            self?.log("HTML loaded successfully (\(htmlString.count) chars)")
            completion(htmlString)
        }

        // Retained so teardown can cancel an in-flight request. Main-confined: `loadHTML`
        // (the sole caller) runs on the main thread.
        fetchTask = task
        task.resume()
    }
}
