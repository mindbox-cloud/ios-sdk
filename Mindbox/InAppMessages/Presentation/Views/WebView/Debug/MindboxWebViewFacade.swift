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

private enum PayloadKey {
    static let sdkVersion = "sdkVersion"
    static let sdkVersionNumeric = "sdkVersionNumeric"
    static let endpointId = "endpointId"
    static let deviceUuid = "deviceUUID"
    static let userVisitCount = "userVisitCount"

    static let inAppId = "inAppId"
    static let operationName = "operationName"
    static let operationBody = "operationBody"

    static let trackVisitSource = "trackVisitSource"
    static let trackVisitRequestUrl = "trackVisitRequestUrl"

    static let firstInitializationDateTime = "firstInitializationDateTime"

    static let permissions = "permissions"
    static let localStateVersion = "localStateVersion"

    enum Insets {
        static let key = "insets"
        static let top = "top"
        static let left = "left"
        static let bottom = "bottom"
        static let right = "right"
    }
}

@_spi(Internal)
public protocol InappWebViewFacadeProtocol: AnyObject {
    func makeView() -> UIView
    func loadHTML(baseUrl: String, contentUrl: String, onFailure: @escaping () -> Void)
    func applyViewSettings(scrollViewDelegate: UIScrollViewDelegate?)
    func cleanWebView()

    func sendReadyEvent(id: UUID)
    func sendToJS(_ message: BridgeMessage)
    func evaluateJavaScript(_ script: String, completion: @escaping (Result<Any?, Error>) -> Void)
    func setBridgeMessageDelegate(_ delegate: WebBridgeMessageDelegate?)
    func setNavigationDelegate(_ delegate: WebBridgeNavigationDelegate?)
    func retryContentLoadBypassingCache(failedURL: String?, onPurgeOutcome: @escaping (_ didRemoveAnything: Bool) -> Void)
    func releaseRetainedContent()
}

@_spi(Internal)
public extension InappWebViewFacadeProtocol {
    // Defaults so existing conformers (mocks, test apps) keep compiling.
    func retryContentLoadBypassingCache(failedURL: String?, onPurgeOutcome: @escaping (_ didRemoveAnything: Bool) -> Void) {}
    func releaseRetainedContent() {}
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
    private let params: [String: JSONValue]?
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
                log: @escaping WebViewLog = { _ in },
                logError: @escaping WebViewLogError = { _ in }) {
        // Borrow the prewarmed live instance when available (kept across shows — hidden,
        // not destroyed); otherwise create one on the same shared data store so cached
        // resources stay visible either way. A warm instance can only serve a caller that
        // wants the stock UA: its applicationNameForUserAgent was baked at prewarm
        // creation and cannot change on a live WKWebView.
        let webView: WKWebView
        if userAgent == SDKUserAgent.build(),
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
    
    public func sendReadyEvent(id: UUID) {
        let message = BridgeMessage(
            type: .response,
            action: BridgeMessage.Action.ready,
            payload: buildStartPayload(),
            id: id
        )
        bridge.send(message)
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
    private func buildStartPayload() -> JSONValue {
        let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
        let systemInfoProvider = DI.injectOrFail(SystemInfoProvider.self)

        var params = buildBaseParams(persistenceStorage: persistenceStorage)
        addSystemInfo(to: &params, systemInfoProvider: systemInfoProvider)
        mergeCustomParams(into: &params)
        addOperationParams(to: &params)
        addTrackVisitParams(to: &params)

        return serializeToJSONString(params)
    }

    private func buildBaseParams(persistenceStorage: PersistenceStorage) -> [String: Any] {
        var params: [String: Any] = [
            PayloadKey.sdkVersion: Mindbox.shared.sdkVersion,
            PayloadKey.endpointId: persistenceStorage.configuration?.endpoint ?? "",
            PayloadKey.deviceUuid: persistenceStorage.deviceUUID ?? "",
            PayloadKey.userVisitCount: "\(persistenceStorage.userVisitCount ?? 0)",
            PayloadKey.sdkVersionNumeric: "\(Constants.Versions.sdkVersionNumeric)",
            PayloadKey.inAppId: inAppId,
            // Add localState version for WebView JS migration logic
            PayloadKey.localStateVersion: persistenceStorage.webViewLocalStateVersion ?? Constants.WebViewLocalState.defaultVersion
        ]

        if let firstInitDate = persistenceStorage.firstInitializationDateTime {
            params[PayloadKey.firstInitializationDateTime] = firstInitDate.toString(withFormat: .utc)
        }

        return params
    }

    private func addOperationParams(to params: inout [String: Any]) {
        guard let operation else { return }
        params[PayloadKey.operationName] = operation.name
        params[PayloadKey.operationBody] = operation.body
    }

    private func addSystemInfo(to params: inout [String: Any], systemInfoProvider: SystemInfoProvider) {
        params.merge(systemInfoProvider.getBasicSystemInfo()) { _, new in new }

        let insets = systemInfoProvider.getSafeAreaInsets(from: webView)
        params[PayloadKey.Insets.key] = [
            PayloadKey.Insets.top: insets.top,
            PayloadKey.Insets.left: insets.left,
            PayloadKey.Insets.bottom: insets.bottom,
            PayloadKey.Insets.right: insets.right
        ]

        let permissions = systemInfoProvider.getGrantedPermissions()
        if !permissions.isEmpty {
            params[PayloadKey.permissions] = permissions.mapValues { $0.toDictionary() }
        }
    }

    private func mergeCustomParams(into params: inout [String: Any]) {
        guard let customParams = self.params, !customParams.isEmpty else { return }
        for (key, value) in customParams {
            params[key] = value.anyValue ?? NSNull()
        }
    }

    private func addTrackVisitParams(to params: inout [String: Any]) {
        guard let lastTrackVisit = SessionTemporaryStorage.shared.lastTrackVisit else { return }
        if let source = lastTrackVisit.source {
            params[PayloadKey.trackVisitSource] = source.rawValue
        }
        if let requestUrl = lastTrackVisit.requestUrl {
            params[PayloadKey.trackVisitRequestUrl] = requestUrl
        }
    }

    private func serializeToJSONString(_ params: [String: Any]) -> JSONValue {
        do {
            let data = try JSONSerialization.data(withJSONObject: params, options: [])
            guard let jsonString = String(bytes: data, encoding: .utf8) else {
                logError("[WebView] Failed to convert JSON data to UTF-8 string")
                return .string("{}")
            }
            return .string(jsonString)
        } catch {
            logError("[WebView] Failed to encode start payload to JSON string: \(error)")
            return .string("{}")
        }
    }

    private func fetchHTML(from urlString: String,
                           completion: @escaping (String?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(nil)
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
