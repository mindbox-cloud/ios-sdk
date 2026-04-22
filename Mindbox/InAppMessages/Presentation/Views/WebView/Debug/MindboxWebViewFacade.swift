//
//  MindboxWebViewFacade.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 16.01.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

// swiftlint:disable file_length
// Prototype: offline webview cache (asset cache + scheme handler + JS shim + warmup) is co-located
// here to minimize project-level churn. Split into separate files before promoting from prototype.

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

    public init(params: [String: JSONValue]?,
                operation: (name: String, body: String)? = nil,
                userAgent: String,
                inAppId: String = "",
                log: @escaping WebViewLog = { _ in },
                logError: @escaping WebViewLogError = { _ in }) {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.applicationNameForUserAgent = userAgent
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        if InAppWebViewSchemeHandler.runtimeInterceptionEnabled {
            let schemeHandler = InAppWebViewSchemeHandler(cache: .shared)
            config.setURLSchemeHandler(schemeHandler, forURLScheme: InAppWebViewSchemeHandler.scheme)

            let shim = WKUserScript(
                source: InAppWebViewSchemeHandler.fetchShimJS,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
            config.userContentController.addUserScript(shim)
        }

        if InAppWebViewDiagnostics.enabled {
            config.userContentController.add(InAppWebViewDiagnostics.shared, name: InAppWebViewDiagnostics.handlerName)
            let script = WKUserScript(
                source: InAppWebViewDiagnostics.userScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
            config.userContentController.addUserScript(script)
        }

        let webView = WKWebView(frame: .zero, configuration: config)
//        #if DEBUG
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
//        #endif
        let bridge = MindboxWebBridge(webView: webView)

        self.webView = webView
        self.bridge = bridge
        self.params = params
        self.operation = operation
        self.inAppId = inAppId
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
        let contentURL = URL(string: contentUrl)
        bridge.updateContentURL(contentURL)

        var priorityScripts: [String] = []
        if let endpointId = DI.inject(PersistenceStorage.self)?.configuration?.endpoint {
            // Order matters: JSON configs must be injected BEFORE byendpoint so it picks them up
            // instead of fetching at runtime.
            if let url = InAppWebViewAssetCache.popMechanicInitURL(for: endpointId) {
                priorityScripts.append(url.absoluteString)
            }
            if let url = InAppWebViewAssetCache.quizzesConfigURL(for: endpointId) {
                priorityScripts.append(url.absoluteString)
            }
            if let url = InAppWebViewAssetCache.byendpointScriptURL(for: endpointId) {
                priorityScripts.append(url.absoluteString)
            }
        }

        if let cachedHTML = InAppWebViewAssetCache.shared.cachedInlinedHTML(
            for: contentUrl,
            priorityInlineScripts: priorityScripts
        ) {
            Logger.common(message: "[WebViewCache] Cache HIT on loadHTML (\(cachedHTML.count) chars): \(contentUrl)", level: .debug, category: .webViewInAppMessages)
            DispatchQueue.main.async { [weak webView] in
                webView?.loadHTMLString(cachedHTML, baseURL: url)
            }
            return
        }

        Logger.common(message: "[WebViewCache] Cache MISS on loadHTML, fetching from network: \(contentUrl)", level: .debug, category: .webViewInAppMessages)
        fetchHTML(from: contentUrl) { [weak self, weak webView] html in
            guard let webView else {
                DispatchQueue.main.async {
                    onFailure()
                }
                return
            }

            if let html {
                InAppWebViewAssetCache.shared.store(
                    html: html,
                    for: contentUrl,
                    log: { Logger.common(message: $0, level: .debug, category: .webViewInAppMessages) },
                    logError: { Logger.common(message: $0, level: .error, category: .webViewInAppMessages) }
                )
                _ = self
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
            params[PayloadKey.firstInitializationDateTime] = firstInitDate.iso8601
        }

        return params
    }

    // Add operation data
    private func addOperationParams(to params: inout [String: Any]) {
        guard let operation else { return }
        params[PayloadKey.operationName] = operation.name
        params[PayloadKey.operationBody] = operation.body
    }

    // Add system info (theme, platform, locale, version)
    private func addSystemInfo(to params: inout [String: Any], systemInfoProvider: SystemInfoProvider) {
        params.merge(systemInfoProvider.getBasicSystemInfo()) { _, new in new }

        // Add safe area insets
        let insets = systemInfoProvider.getSafeAreaInsets(from: webView)
        params[PayloadKey.Insets.key] = [
            PayloadKey.Insets.top: insets.top,
            PayloadKey.Insets.left: insets.left,
            PayloadKey.Insets.bottom: insets.bottom,
            PayloadKey.Insets.right: insets.right
        ]

        // Add granted permissions
        let permissions = systemInfoProvider.getGrantedPermissions()
        if !permissions.isEmpty {
            params[PayloadKey.permissions] = permissions.mapValues { $0.toDictionary() }
        }
    }

    // Merge params from configuration
    private func mergeCustomParams(into params: inout [String: Any]) {
        guard let customParams = self.params, !customParams.isEmpty else { return }
        for (key, value) in customParams {
            params[key] = value.anyValue ?? NSNull()
        }
    }

    // Add last track-visit data
    private func addTrackVisitParams(to params: inout [String: Any]) {
        guard let lastTrackVisit = SessionTemporaryStorage.shared.lastTrackVisit else { return }
        if let source = lastTrackVisit.source {
            params[PayloadKey.trackVisitSource] = source.rawValue
        }
        if let requestUrl = lastTrackVisit.requestUrl {
            params[PayloadKey.trackVisitRequestUrl] = requestUrl
        }
    }

    // Serialize to JSON string
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
        
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil
        
        let session = URLSession(configuration: config)
        
        log("Fetching HTML from \(url.absoluteString)")
        
        let task = session.dataTask(with: url) { [weak self] data, response, error in
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

        task.resume()
    }
}

// MARK: - Prototype disk cache

final class InAppWebViewAssetCache {

    static let shared = InAppWebViewAssetCache()

    /// Keeps tracker.js's `loadEndpointSettings` resolvable when offline.
    ///
    /// tracker.js chain:
    ///   BatchedModulesLoader.loadModule → getRemoteBlob → fetch('/js/byendpoint/{id}.js')
    /// Offline, the fetch rejects. The reject-branch of `.then(onOk, onErr)` calls
    /// `setBatchedModuleInitialized(true)` but does NOT call
    /// `endpointSettingsFetching.resolve(...)`, so every subsequent `await` on that
    /// promise (e.g. byendpoint's `Pt()` → `formsReady`) hangs forever with no error.
    ///
    /// This shim intercepts `fetch` for the byendpoint URL pattern and returns a 200
    /// stub Response with empty JS. tracker's success-branch then runs, reads
    /// `window.MindboxEndpointSettings` (already set by our pre-inlined byendpoint
    /// classic script), and resolves the settings promise — unblocking init.
    ///
    /// Must run BEFORE tracker's module script. Non-matching URLs pass through to
    /// the original `fetch` so normal online behavior is unchanged.
    static let offlineByendpointFetchShim: String = """
    (function() {
      if (window.__mbOfflineByendpointFetchShimInstalled) return;
      window.__mbOfflineByendpointFetchShimInstalled = true;
      var origFetch = window.fetch ? window.fetch.bind(window) : null;
      var pattern = /\\/js\\/byendpoint\\/[^\\/?#]+\\.js(\\?|$)/i;
      window.fetch = function(input, init) {
        var url = '';
        try {
          url = (typeof input === 'string') ? input : (input && input.url) || '';
        } catch (e) {}
        if (pattern.test(url)) {
          try { console.log('[mb-shim] byendpoint fetch intercepted:', url); } catch (e) {}
          try {
            return Promise.resolve(new Response('', {
              status: 200,
              headers: { 'Content-Type': 'application/javascript' }
            }));
          } catch (e) {
            return Promise.resolve({
              ok: true, status: 200,
              text: function() { return Promise.resolve(''); },
              blob: function() { return Promise.resolve(new Blob([''], {type: 'application/javascript'})); }
            });
          }
        }
        return origFetch ? origFetch(input, init) : Promise.reject(new Error('fetch unavailable'));
      };
    })();
    """

    private let fileManager = FileManager.default
    private let session: URLSession
    private let downloadQueue = DispatchQueue(label: "cloud.mindbox.InAppWebViewAssetCache", qos: .utility)

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil
        self.session = URLSession(configuration: config)
    }

    func cachedInlinedHTML(for contentUrl: String,
                           priorityInlineScripts: [String] = []) -> String? {
        guard let dir = directory(for: contentUrl) else { return nil }
        let htmlURL = dir.appendingPathComponent("index.html")
        guard let html = try? String(contentsOf: htmlURL, encoding: .utf8) else { return nil }
        return inline(
            html: html,
            scriptsDir: dir.appendingPathComponent("scripts", isDirectory: true),
            priorityInlineScripts: priorityInlineScripts
        )
    }

    /// Prefetches HTML + all scripts referenced from it. Idempotent per file — re-runs on cached
    /// HTML only backfill missing script files, never re-download existing ones.
    ///
    /// `extraScripts` are additional URLs (not referenced from the HTML) that should be cached
    /// alongside each inapp. Used for bootstrap scripts loaded at runtime by tracker.js — e.g.
    /// `https://web-static.mindbox.ru/js/byendpoint/{endpointId}.js` which sets `window.PopMechanic`.
    func prefetch(contentUrls: [String],
                  extraScripts: [URL] = [],
                  log: WebViewLog? = nil,
                  logError: WebViewLogError? = nil) {
        let unique = Array(Set(contentUrls))
        for urlString in unique {
            downloadQueue.async { [weak self] in
                guard let self else { return }
                if !self.hasCachedHTML(for: urlString) {
                    self.downloadAndStoreHTML(urlString: urlString, log: log, logError: logError)
                } else {
                    log?("[WebViewCache] HTML cached, ensuring scripts are also cached: \(urlString)")
                    self.backfillScripts(for: urlString, log: log, logError: logError)
                }
                self.downloadExtraScripts(extraScripts, for: urlString, logError: logError)
            }
        }
    }

    private func backfillScripts(for contentUrl: String,
                                 log: WebViewLog?,
                                 logError: WebViewLogError?) {
        guard let dir = directory(for: contentUrl) else { return }
        let htmlURL = dir.appendingPathComponent("index.html")
        guard let html = try? String(contentsOf: htmlURL, encoding: .utf8) else { return }

        let scriptsDir = dir.appendingPathComponent("scripts", isDirectory: true)
        try? fileManager.createDirectory(at: scriptsDir, withIntermediateDirectories: true)

        let urls = extractScriptURLs(from: html)
        log?("[WebViewCache] Backfilling \(urls.count) script(s) for \(contentUrl)")
        for url in urls {
            downloadScript(url: url, into: scriptsDir, logError: logError)
        }
    }

    private func downloadExtraScripts(_ urls: [URL],
                                      for contentUrl: String,
                                      logError: WebViewLogError?) {
        guard !urls.isEmpty, let dir = directory(for: contentUrl) else { return }
        let scriptsDir = dir.appendingPathComponent("scripts", isDirectory: true)
        try? fileManager.createDirectory(at: scriptsDir, withIntermediateDirectories: true)
        for url in urls {
            downloadScript(url: url, into: scriptsDir, logError: logError)
        }
    }

    /// Well-known URL of the per-endpoint bootstrap script that tracker.js fetches at runtime to
    /// install `window.PopMechanic`, `window.MindboxEndpointSettings`, etc. Pre-caching and
    /// inlining this script is what makes the popup render without network at popup time.
    static func byendpointScriptURL(for endpointId: String) -> URL? {
        let trimmed = endpointId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return nil }
        return URL(string: "https://web-static.mindbox.ru/js/byendpoint/\(trimmed).js")
    }

    /// PopMechanic form config. byendpoint's `pt()` returns `window.__POPMECHANIC_INIT` if set,
    /// avoiding the runtime fetch.
    static func popMechanicInitURL(for endpointId: String) -> URL? {
        let trimmed = endpointId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return nil }
        return URL(string: "https://web-static.mindbox.ru/personalization/byendpoint/\(trimmed).json")
    }

    /// Quizzes config. byendpoint skips `ft()` fetch when `window.__PRELOADED_QUIZZES_CONFIG` is set.
    static func quizzesConfigURL(for endpointId: String) -> URL? {
        let trimmed = endpointId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return nil }
        return URL(string: "https://web-static.mindbox.ru/quizzes/byendpoint/\(trimmed).json")
    }

    /// The quizzes ES-module library that byendpoint attaches dynamically via
    /// `<script type="module" async src=".../quizzes.js">`. Offline that fetch fails; we cache
    /// the script and inline it as a module so byendpoint's dynamic load has nothing left to do.
    static let quizzesStableScriptURL: URL? = URL(string: "https://web-static.mindbox.ru/quizzes/stable/quizzes.js")

    /// Returns the JS global variable name that a given preloaded JSON URL should be assigned to,
    /// so byendpoint skips its runtime fetch.
    static func preloadGlobalVariableName(forURL urlString: String) -> String? {
        if urlString.contains("/personalization/byendpoint/") { return "__POPMECHANIC_INIT" }
        if urlString.contains("/quizzes/byendpoint/") { return "__PRELOADED_QUIZZES_CONFIG" }
        return nil
    }

    /// Walks the config DTO tree and returns contentUrls of all webview layers.
    static func extractWebViewContentUrls(from inapps: [InAppDTO]?) -> [String] {
        guard let inapps else { return [] }
        var urls: [String] = []
        for inapp in inapps {
            guard let variants = inapp.form.variants else { continue }
            for variant in variants {
                let layers: [ContentBackgroundLayerDTO]?
                switch variant {
                case .modal(let modal):
                    layers = modal.content?.background?.layers
                case .snackbar(let snackbar):
                    layers = snackbar.content?.background?.layers
                case .unknown:
                    layers = nil
                }
                for layer in layers ?? [] {
                    if case let .webview(wv) = layer, let url = wv.contentUrl, !url.isEmpty {
                        urls.append(url)
                    }
                }
            }
        }
        return urls
    }

    func store(html: String,
               for contentUrl: String,
               log: WebViewLog?,
               logError: WebViewLogError?) {
        downloadQueue.async { [weak self] in
            guard let self, let dir = self.directory(for: contentUrl) else { return }
            let scriptsDir = dir.appendingPathComponent("scripts", isDirectory: true)
            do {
                try self.fileManager.createDirectory(at: scriptsDir, withIntermediateDirectories: true)
                if let data = html.data(using: .utf8) {
                    try data.write(to: dir.appendingPathComponent("index.html"), options: .atomic)
                }
            } catch {
                logError?("[WebViewCache] Failed to prepare cache dir: \(error.localizedDescription)")
                return
            }

            let urls = self.extractScriptURLs(from: html)
            log?("[WebViewCache] Persisted HTML, downloading \(urls.count) script(s) for \(contentUrl)")
            for url in urls {
                self.downloadScript(url: url, into: scriptsDir, logError: logError)
            }
        }
    }

    // MARK: - Private

    private func hasCachedHTML(for contentUrl: String) -> Bool {
        guard let dir = directory(for: contentUrl) else { return false }
        return fileManager.fileExists(atPath: dir.appendingPathComponent("index.html").path)
    }

    private func downloadAndStoreHTML(urlString: String,
                                      log: WebViewLog?,
                                      logError: WebViewLogError?) {
        guard let url = URL(string: urlString) else { return }
        log?("[WebViewCache] Prefetching HTML: \(urlString)")
        session.dataTask(with: url) { [weak self] data, response, error in
            if let error {
                logError?("[WebViewCache] Prefetch failed for \(urlString): \(error.localizedDescription)")
                return
            }
            guard let data,
                  let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode),
                  let html = String(data: data, encoding: .utf8) else {
                logError?("[WebViewCache] Prefetch bad response for \(urlString)")
                return
            }
            self?.store(html: html, for: urlString, log: log, logError: logError)
        }.resume()
    }

    private func directory(for contentUrl: String) -> URL? {
        guard let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first,
              let name = contentUrl.addingPercentEncoding(withAllowedCharacters: .alphanumerics),
              !name.isEmpty else {
            return nil
        }
        return base
            .appendingPathComponent("Mindbox", isDirectory: true)
            .appendingPathComponent("InAppWebView", isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
    }

    private func extractScriptURLs(from html: String) -> [URL] {
        var seen = Set<String>()
        var urls: [URL] = []

        let collect: (String) -> Void = { raw in
            guard !seen.contains(raw), let url = URL(string: raw) else { return }
            seen.insert(raw)
            urls.append(url)
        }

        // Static <script src="https://..."> tags.
        let staticPattern = #"<script\b[^>]*\bsrc\s*=\s*"(https://[^"]+)""#
        if let regex = try? NSRegularExpression(pattern: staticPattern, options: [.caseInsensitive]) {
            let range = NSRange(html.startIndex..., in: html)
            regex.enumerateMatches(in: html, range: range) { match, _, _ in
                guard let match, match.numberOfRanges > 1,
                      let r = Range(match.range(at: 1), in: html) else { return }
                collect(String(html[r]))
            }
        }

        // Bootstrap `window.__env_vars` paths that the inline script appends as dynamic module scripts.
        // Pattern matches identifiers ending in `_PATH` whose value is a quoted http(s) URL.
        let envPattern = #"([A-Z_][A-Z0-9_]*_PATH)\s*:\s*['"](https?://[^'"]+)['"]"#
        if let regex = try? NSRegularExpression(pattern: envPattern, options: []) {
            let range = NSRange(html.startIndex..., in: html)
            regex.enumerateMatches(in: html, range: range) { match, _, _ in
                guard let match, match.numberOfRanges > 2,
                      let r = Range(match.range(at: 2), in: html) else { return }
                collect(String(html[r]))
            }
        }

        return urls
    }

    private func downloadScript(url: URL, into dir: URL, logError: WebViewLogError?) {
        guard let fileURL = scriptFileURL(for: url.absoluteString, in: dir) else { return }
        if fileManager.fileExists(atPath: fileURL.path) {
            // Re-scan in case new media URLs are referenced (though typically idempotent).
            scanCachedScriptForMedia(at: fileURL, into: dir, logError: logError)
            return
        }

        session.dataTask(with: url) { [weak self] data, response, error in
            if let error {
                logError?("[WebViewCache] Failed to download \(url.absoluteString): \(error.localizedDescription)")
                return
            }
            guard let data,
                  let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                logError?("[WebViewCache] Bad HTTP response for \(url.absoluteString)")
                return
            }
            do {
                try data.write(to: fileURL, options: .atomic)
                self?.scanCachedScriptForMedia(at: fileURL, into: dir, logError: logError)
            } catch {
                logError?("[WebViewCache] Failed to write \(fileURL.lastPathComponent): \(error.localizedDescription)")
            }
        }.resume()
    }

    private func scanCachedScriptForMedia(at fileURL: URL,
                                          into dir: URL,
                                          logError: WebViewLogError?) {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return }
        for imgURL in extractMediaURLs(from: content) {
            downloadMedia(url: imgURL, into: dir, logError: logError)
        }
    }

    /// Matches Mindbox media URLs (user-media, screenshots) embedded as string literals inside JS.
    private func extractMediaURLs(from content: String) -> [URL] {
        let pattern = #"https://[A-Za-z0-9.\-]+\.mindbox\.ru/[^\s"'\\)]+?\.(?:jpg|jpeg|png|webp|gif|svg|mp4)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        var seen = Set<String>()
        var urls: [URL] = []
        let range = NSRange(content.startIndex..., in: content)
        regex.enumerateMatches(in: content, range: range) { match, _, _ in
            guard let match, let r = Range(match.range, in: content) else { return }
            let raw = String(content[r])
            guard !seen.contains(raw), let url = URL(string: raw) else { return }
            seen.insert(raw)
            urls.append(url)
        }
        return urls
    }

    private func downloadMedia(url: URL, into dir: URL, logError: WebViewLogError?) {
        guard let fileURL = mediaFileURL(for: url.absoluteString, in: dir) else { return }
        if fileManager.fileExists(atPath: fileURL.path) { return }

        session.dataTask(with: url) { data, response, error in
            if let error {
                logError?("[WebViewCache] Failed to download media \(url.absoluteString): \(error.localizedDescription)")
                return
            }
            guard let data,
                  let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                return
            }
            try? data.write(to: fileURL, options: .atomic)
        }.resume()
    }

    private func mediaFileURL(for urlString: String, in dir: URL) -> URL? {
        guard let name = urlString.addingPercentEncoding(withAllowedCharacters: .alphanumerics),
              !name.isEmpty else { return nil }
        return dir.appendingPathComponent("media-" + name)
    }

    private static func mimeType(forPathExtension ext: String) -> String {
        switch ext.lowercased() {
        case "jpg", "jpeg": return "image/jpeg"
        case "png":         return "image/png"
        case "webp":        return "image/webp"
        case "gif":         return "image/gif"
        case "svg":         return "image/svg+xml"
        case "mp4":         return "video/mp4"
        default:            return "application/octet-stream"
        }
    }

    /// Replaces every cached Mindbox media URL embedded in `content` with an inline `data:` URI so
    /// the popup renders without network for images/screenshots.
    fileprivate func inlineMediaReferences(in content: String, scriptsDir: URL) -> String {
        let pattern = #"https://[A-Za-z0-9.\-]+\.mindbox\.ru/[^\s"'\\)]+?\.(?:jpg|jpeg|png|webp|gif|svg|mp4)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return content
        }

        var result = content
        let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
        for match in matches.reversed() {
            guard let range = Range(match.range, in: result) else { continue }
            let urlString = String(result[range])
            guard let url = URL(string: urlString),
                  let fileURL = mediaFileURL(for: urlString, in: scriptsDir),
                  let data = try? Data(contentsOf: fileURL) else { continue }
            let mime = Self.mimeType(forPathExtension: url.pathExtension)
            let base64 = data.base64EncodedString()
            result.replaceSubrange(range, with: "data:\(mime);base64,\(base64)")
        }
        return result
    }

    private func inline(html: String,
                        scriptsDir: URL,
                        priorityInlineScripts: [String]) -> String {
        var result = inlineScripts(html: html, scriptsDir: scriptsDir)
        result = inlineBootstrapScripts(
            html: result,
            scriptsDir: scriptsDir,
            priorityInlineScripts: priorityInlineScripts
        )
        guard InAppWebViewSchemeHandler.runtimeInterceptionEnabled else {
            return result
        }
        return rewriteStaticAssetURLs(html: result)
    }

    /// Injects cached scripts into the bootstrap HTML and disables the bootstrap's dynamic
    /// `document.head.appendChild(...)` calls so the same scripts don't also load from CDN.
    ///
    /// Injection order before `</head>`:
    ///  1. `priorityInlineScripts` — classic `<script>` tags (byendpoint.js). Must run BEFORE
    ///     tracker/main because tracker expects `window.MindboxEndpointSettings` and main expects
    ///     to register `PopMechanic.onLoad` which byendpoint calls after its async formsReady.
    ///  2. Env-var script URLs (`MAIN_JS_PATH`, `TRACKER_PATH`) as `<script type="module">`.
    private func inlineBootstrapScripts(html: String,
                                        scriptsDir: URL,
                                        priorityInlineScripts: [String]) -> String {
        var injected = ""

        // Must run before tracker.js module script — see doc-comment on the shim.
        injected += "\n<script data-mb-cached-preload=\"offline-byendpoint-fetch-shim\">\n\(Self.offlineByendpointFetchShim)\n</script>\n"

        // Inline the quizzes ES-module up front so byendpoint's later dynamic append (which we
        // neutralize below) has nothing to do. Offline this removes a resource-error; online it's
        // a no-op because the duplicate dynamic load is stripped.
        if let quizzesURL = Self.quizzesStableScriptURL,
           let fileURL = scriptFileURL(for: quizzesURL.absoluteString, in: scriptsDir),
           let data = try? Data(contentsOf: fileURL),
           let contents = String(data: data, encoding: .utf8) {
            injected += "\n<script type=\"module\" data-mb-cached-src=\"\(quizzesURL.absoluteString)\">\n\(contents)\n</script>\n"
        }

        for urlString in priorityInlineScripts {
            guard let fileURL = scriptFileURL(for: urlString, in: scriptsDir),
                  let data = try? Data(contentsOf: fileURL),
                  let rawContents = String(data: data, encoding: .utf8) else {
                continue
            }

            if let globalName = Self.preloadGlobalVariableName(forURL: urlString) {
                // JSON config → inject as `window.NAME = {...json...};` so byendpoint uses it and
                // skips the runtime fetch. Media URLs embedded in the JSON (e.g. `option_image`)
                // are swapped to `data:` URIs so they render offline. Escape any stray `</` to
                // keep the script tag intact after inlining grew the payload.
                let withInlinedMedia = inlineMediaReferences(in: rawContents, scriptsDir: scriptsDir)
                let safeJson = withInlinedMedia.replacingOccurrences(of: "</", with: "<\\/")
                injected += "\n<script data-mb-cached-preload=\"\(urlString)\">\nwindow.\(globalName) = \(safeJson);\n</script>\n"
                continue
            }

            let contents = inlineMediaReferences(in: rawContents, scriptsDir: scriptsDir)
            injected += "\n<script data-mb-cached-src=\"\(urlString)\">\n\(contents)\n</script>\n"
        }

        let envPattern = #"([A-Z_][A-Z0-9_]*_PATH)\s*:\s*['"](https?://[^'"]+)['"]"#
        if let regex = try? NSRegularExpression(pattern: envPattern, options: []) {
            var seen = Set<String>()
            regex.enumerateMatches(in: html, range: NSRange(html.startIndex..., in: html)) { match, _, _ in
                guard let match, match.numberOfRanges > 2,
                      let urlRange = Range(match.range(at: 2), in: html) else { return }
                let urlString = String(html[urlRange])
                guard !seen.contains(urlString),
                      let fileURL = scriptFileURL(for: urlString, in: scriptsDir),
                      let data = try? Data(contentsOf: fileURL),
                      let contents = String(data: data, encoding: .utf8) else {
                    return
                }
                seen.insert(urlString)
                injected += "\n<script type=\"module\" data-mb-cached-src=\"\(urlString)\">\n\(contents)\n</script>\n"
            }
        }

        guard !injected.isEmpty else { return html }

        var result = html

        // Neutralize dynamic script injection so the bootstrap doesn't also fetch from CDN.
        // Matches e.g. `document.head.appendChild(mainJsScript);` and the minified byendpoint
        // quizzes IIFE `i.head.appendChild(n)` (where `i` is the aliased `document` param).
        if let appendRegex = try? NSRegularExpression(
            pattern: #"\w+\.head\.appendChild\(\s*\w+\s*\)\s*;?"#,
            options: []
        ) {
            let nsRange = NSRange(result.startIndex..., in: result)
            result = appendRegex.stringByReplacingMatches(
                in: result,
                range: nsRange,
                withTemplate: "void 0 /* mb-cache: dynamic script injection disabled */"
            )
        }

        // Inject inlined scripts just before `</head>`.
        if let range = result.range(of: "</head>", options: .caseInsensitive) {
            result.replaceSubrange(range, with: injected + "</head>")
            return result
        }
        return injected + result
    }

    private func inlineScripts(html: String, scriptsDir: URL) -> String {
        let pattern = #"<script\b[^>]*\bsrc\s*=\s*"(https://[^"]+)"[^>]*>\s*</script>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return html
        }
        let modulePattern = try? NSRegularExpression(pattern: #"\btype\s*=\s*"module""#, options: [.caseInsensitive])

        var result = html
        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
        for match in matches.reversed() {
            guard match.numberOfRanges >= 2,
                  let urlRange = Range(match.range(at: 1), in: result),
                  let fullRange = Range(match.range, in: result) else {
                continue
            }
            let tag = String(result[fullRange])
            if let modulePattern,
               modulePattern.firstMatch(in: tag, range: NSRange(tag.startIndex..., in: tag)) != nil {
                // Leave ES module scripts alone — inlining them strips `type="module"` which breaks
                // import/export syntax. They'll load from CDN (online) or fail (offline — needs loopback).
                continue
            }
            guard let fileURL = scriptFileURL(for: String(result[urlRange]), in: scriptsDir),
                  let data = try? Data(contentsOf: fileURL),
                  let contents = String(data: data, encoding: .utf8) else {
                continue
            }
            result.replaceSubrange(fullRange, with: "<script>\n\(contents)\n</script>")
        }
        return result
    }

    /// Rewrites static `src=`/`href=` attributes pointing at Mindbox http(s) URLs to the mindbox-cache://
    /// scheme, so WKWebView routes them through our WKURLSchemeHandler (disk cache + network fallback).
    /// Non-Mindbox URLs are left untouched to avoid breaking third-party resources.
    private func rewriteStaticAssetURLs(html: String) -> String {
        let pattern = #"(\s(?:src|href)\s*=\s*)"(https?://[^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return html
        }

        var result = html
        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
        for match in matches.reversed() {
            guard match.numberOfRanges >= 3,
                  let fullRange = Range(match.range, in: result),
                  let prefixRange = Range(match.range(at: 1), in: result),
                  let urlRange = Range(match.range(at: 2), in: result) else {
                continue
            }
            let url = String(result[urlRange])
            guard InAppWebViewSchemeHandler.isMindboxHost(urlString: url),
                  let encoded = url.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else {
                continue
            }
            let prefix = String(result[prefixRange])
            result.replaceSubrange(fullRange, with: "\(prefix)\"\(InAppWebViewSchemeHandler.scheme)://proxy?u=\(encoded)\"")
        }
        return result
    }

    private func scriptFileURL(for urlString: String, in dir: URL) -> URL? {
        guard let name = urlString.addingPercentEncoding(withAllowedCharacters: .alphanumerics),
              !name.isEmpty else { return nil }
        return dir.appendingPathComponent(name + ".js")
    }
}

// MARK: - Resource cache (runtime fetch/XHR responses)

struct CachedResource {
    let data: Data
    let mime: String
}

extension InAppWebViewAssetCache {
    func cachedResource(for urlString: String) -> CachedResource? {
        guard let (dataURL, metaURL) = resourceFiles(for: urlString),
              let data = try? Data(contentsOf: dataURL),
              let metaData = try? Data(contentsOf: metaURL),
              let meta = try? JSONSerialization.jsonObject(with: metaData) as? [String: String],
              let mime = meta["mime"] else {
            return nil
        }
        return CachedResource(data: data, mime: mime)
    }

    func storeResource(data: Data, mime: String, for urlString: String) {
        guard let (dataURL, metaURL) = resourceFiles(for: urlString) else { return }
        let dir = dataURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try data.write(to: dataURL, options: .atomic)
            let metaData = try JSONSerialization.data(withJSONObject: ["mime": mime], options: [])
            try metaData.write(to: metaURL, options: .atomic)
        } catch {
            // prototype: ignore write errors
        }
    }

    private func resourceFiles(for urlString: String) -> (data: URL, meta: URL)? {
        guard let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first,
              let name = urlString.addingPercentEncoding(withAllowedCharacters: .alphanumerics),
              !name.isEmpty else {
            return nil
        }
        let dir = base
            .appendingPathComponent("Mindbox", isDirectory: true)
            .appendingPathComponent("InAppWebView", isDirectory: true)
            .appendingPathComponent("_resources", isDirectory: true)
        return (dir.appendingPathComponent(name + ".bin"),
                dir.appendingPathComponent(name + ".meta"))
    }
}

// MARK: - Prototype WebKit warmup

/// Creates a hidden WKWebView at SDK start so the first on-screen in-app webview
/// doesn't pay the cost of spinning up the WebKit content/networking processes.
final class InAppWebViewWarmupService {

    static let shared = InAppWebViewWarmupService()

    private var warmupView: WKWebView?

    private init() {}

    func warmup() {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.warmupView == nil else { return }
            let config = WKWebViewConfiguration()
            config.websiteDataStore = .nonPersistent()
            let view = WKWebView(frame: .zero, configuration: config)
            view.loadHTMLString("<!DOCTYPE html><html><body></body></html>", baseURL: nil)
            self.warmupView = view
        }
    }
}

// MARK: - Prototype scheme handler

/// Intercepts `mindbox-cache://proxy?u=<encoded-url>` requests from the webview,
/// serves from disk cache when available, falls back to network and persists the result.
///
/// Wiring:
///  - Static `src=`/`href=` attributes in the HTML are rewritten to this scheme at cache-retrieval time.
///  - Runtime `fetch()` / `XMLHttpRequest` calls are routed through this scheme via `fetchShimJS`
///    injected as a `WKUserScript` at `.atDocumentStart`.
final class InAppWebViewSchemeHandler: NSObject, WKURLSchemeHandler {

    static let scheme = "mindbox-cache"

    /// Master toggle for the runtime fetch/XHR interception + custom scheme.
    /// OFF: no scheme handler, no shim. Inline scripts (byendpoint+tracker+main) drive the popup;
    /// byendpoint's async `formsReady` continuation naturally calls `PopMechanic.onLoad` once main
    /// has set it. Online flow should work without interception. Offline still needs a way to
    /// satisfy byendpoint's runtime fetches (form data, etc.) — open problem.
    static var runtimeInterceptionEnabled = false

    static let fetchShimJS: String = """
    (function() {
      const SCHEME = 'mindbox-cache';
      const isMindboxHost = function(hostname) {
        return hostname === 'mindbox.ru' || hostname.endsWith('.mindbox.ru');
      };
      const rewrite = function(urlStr) {
        try {
          if (typeof urlStr !== 'string') return urlStr;
          const u = new URL(urlStr, location.href);
          if ((u.protocol === 'https:' || u.protocol === 'http:') && isMindboxHost(u.hostname)) {
            return SCHEME + '://proxy?u=' + encodeURIComponent(u.href);
          }
        } catch (e) {}
        return urlStr;
      };

      // fetch()
      const origFetch = window.fetch;
      if (origFetch) {
        window.fetch = function(input, init) {
          try {
            if (typeof input === 'string') {
              return origFetch.call(this, rewrite(input), init);
            }
            if (input && typeof input === 'object' && 'url' in input) {
              const rewritten = rewrite(input.url);
              if (rewritten !== input.url) {
                return origFetch.call(this, new Request(rewritten, input), init);
              }
            }
          } catch (e) {}
          return origFetch.apply(this, arguments);
        };
      }

      // XMLHttpRequest
      const Xhr = window.XMLHttpRequest;
      if (Xhr && Xhr.prototype && Xhr.prototype.open) {
        const origOpen = Xhr.prototype.open;
        Xhr.prototype.open = function(method, url) {
          const args = Array.prototype.slice.call(arguments);
          try { args[1] = rewrite(url); } catch (e) {}
          return origOpen.apply(this, args);
        };
      }

      // navigator.sendBeacon — re-route through fetch. Beacon is fire-and-forget so we return true
      // optimistically and let the rewritten fetch handle delivery (or caching if offline).
      if (navigator && typeof navigator.sendBeacon === 'function') {
        const origSendBeacon = navigator.sendBeacon.bind(navigator);
        navigator.sendBeacon = function(url, data) {
          try {
            const rewritten = rewrite(url);
            if (rewritten !== url) {
              try { fetch(rewritten, { method: 'POST', body: data, keepalive: true, credentials: 'omit' }); } catch (e) {}
              return true;
            }
          } catch (e) {}
          return origSendBeacon(url, data);
        };
      }
    })();
    """

    static func isMindboxHost(urlString: String) -> Bool {
        guard let host = URL(string: urlString)?.host?.lowercased() else { return false }
        return host == "mindbox.ru" || host.hasSuffix(".mindbox.ru")
    }

    private let cache: InAppWebViewAssetCache
    private let session: URLSession
    private let lock = NSLock()
    private var activeTasks: [ObjectIdentifier: URLSessionDataTask] = [:]

    init(cache: InAppWebViewAssetCache) {
        self.cache = cache
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil
        self.session = URLSession(configuration: config)
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let requestURL = urlSchemeTask.request.url,
              let originalURL = Self.originalURL(from: requestURL) else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }

        let method = urlSchemeTask.request.httpMethod?.uppercased() ?? "GET"

        if method == "GET", let cached = cache.cachedResource(for: originalURL.absoluteString) {
            Logger.common(message: "[WebViewCache] Cache HIT: \(originalURL.absoluteString)", level: .debug, category: .webViewInAppMessages)
            respond(to: urlSchemeTask, data: cached.data, mime: cached.mime)
            return
        }

        Logger.common(message: "[WebViewCache] Cache MISS (\(method)): \(originalURL.absoluteString)", level: .debug, category: .webViewInAppMessages)

        var request = URLRequest(url: originalURL)
        request.httpMethod = method
        request.httpBody = urlSchemeTask.request.httpBody
        request.allHTTPHeaderFields = urlSchemeTask.request.allHTTPHeaderFields

        let taskID = ObjectIdentifier(urlSchemeTask)
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }
            self.lock.lock()
            let isActive = self.activeTasks.removeValue(forKey: taskID) != nil
            self.lock.unlock()
            guard isActive else { return }

            if let error {
                Logger.common(message: "[WebViewCache] Network error for \(originalURL.absoluteString): \(error.localizedDescription)", level: .error, category: .webViewInAppMessages)
                urlSchemeTask.didFailWithError(error)
                return
            }
            guard let data, let http = response as? HTTPURLResponse else {
                urlSchemeTask.didFailWithError(URLError(.badServerResponse))
                return
            }

            let mime = http.mimeType ?? "application/octet-stream"
            if method == "GET", (200...299).contains(http.statusCode) {
                self.cache.storeResource(data: data, mime: mime, for: originalURL.absoluteString)
            }
            self.respond(to: urlSchemeTask, data: data, mime: mime, status: http.statusCode)
        }

        lock.lock()
        activeTasks[taskID] = task
        lock.unlock()
        task.resume()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        let taskID = ObjectIdentifier(urlSchemeTask)
        lock.lock()
        let task = activeTasks.removeValue(forKey: taskID)
        lock.unlock()
        task?.cancel()
    }

    // MARK: - Private

    private func respond(to urlSchemeTask: WKURLSchemeTask,
                         data: Data,
                         mime: String,
                         status: Int = 200) {
        guard let url = urlSchemeTask.request.url else { return }
        let headers: [String: String] = [
            "Content-Type": mime,
            "Content-Length": "\(data.count)",
            "Access-Control-Allow-Origin": "*"
        ]
        guard let response = HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        ) else {
            urlSchemeTask.didFailWithError(URLError(.badServerResponse))
            return
        }
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    private static func originalURL(from url: URL) -> URL? {
        guard url.scheme == scheme,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let encoded = components.queryItems?.first(where: { $0.name == "u" })?.value,
              let decoded = encoded.removingPercentEncoding,
              let target = URL(string: decoded) else {
            return nil
        }
        return target
    }
}

// MARK: - Prototype JS→native diagnostics

/// Forwards `console.log`, `window.onerror`, `unhandledrejection`, and periodic snapshots of
/// `window.PopMechanic` state from the webview to `Logger.common`. Used to locate where
/// PopMechanic's async init hangs offline.
final class InAppWebViewDiagnostics: NSObject, WKScriptMessageHandler {

    static let shared = InAppWebViewDiagnostics()

    static var enabled = true

    static let handlerName = "MindboxDebug"

    static let userScript: String = """
    (function() {
      function send(level, parts) {
        try {
          var payload = {
            level: level,
            message: Array.prototype.map.call(parts, function(a) {
              try {
                if (typeof a === 'string') return a;
                if (a instanceof Error) return (a.name || 'Error') + ': ' + a.message + (a.stack ? ('\\n' + a.stack) : '');
                return JSON.stringify(a);
              } catch (e) { return String(a); }
            }).join(' ')
          };
          if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.MindboxDebug) {
            window.webkit.messageHandlers.MindboxDebug.postMessage(payload);
          }
        } catch (e) {}
      }

      ['log', 'warn', 'error', 'info', 'debug'].forEach(function(level) {
        var orig = console[level];
        console[level] = function() { send(level, arguments); if (orig) try { orig.apply(console, arguments); } catch (e) {} };
      });

      window.addEventListener('error', function(e) {
        send('window.error', [e.message || '(no message)', e.filename || '', e.lineno || 0, e.colno || 0, (e.error && e.error.stack) || '']);
      });

      window.addEventListener('unhandledrejection', function(e) {
        var reason = e.reason;
        var msg = (reason && (reason.message || reason.toString())) || String(reason);
        var stack = (reason && reason.stack) || '';
        send('unhandledrejection', [msg, stack]);
      });

      // Resource-load errors bubble via capture phase. Log every img/link/script
      // load failure so we can see exactly which asset the offline popup is missing.
      document.addEventListener('error', function(e) {
        var t = e.target;
        if (!t || t === window) return;
        var tag = (t.tagName || '').toLowerCase();
        if (tag === 'img' || tag === 'script' || tag === 'link' || tag === 'iframe') {
          send('resource-error', [tag, t.src || t.href || '', (t.currentSrc || '')]);
        }
      }, true);

      // Log every fetch from within the page so we can enumerate missing assets.
      try {
        var origFetch = window.fetch ? window.fetch.bind(window) : null;
        if (origFetch) {
          window.fetch = function(input, init) {
            var url = '';
            try { url = (typeof input === 'string') ? input : (input && input.url) || ''; } catch (e) {}
            send('fetch', [url]);
            return origFetch(input, init).then(function(r) {
              send('fetch-ok', [url, r && r.status]);
              return r;
            }, function(err) {
              send('fetch-fail', [url, (err && err.message) || String(err)]);
              throw err;
            });
          };
        }
      } catch (e) {}

      var tick = 0;
      var heartbeat = setInterval(function() {
        tick++;
        try {
          var pm = window.PopMechanic || {};
          var initModel = pm.initModel || {};
          send('heartbeat',
            ['t=' + tick,
             'pm.loaded=' + !!pm.loaded,
             'pm.show=' + (typeof pm.show),
             'pm.onLoad=' + (typeof pm.onLoad),
             'pm.onFormShow=' + (typeof pm.onFormShow),
             'forms=' + ((initModel.forms && initModel.forms.length) || 0),
             'formsMap=' + (initModel.formsMap ? Object.keys(initModel.formsMap).length : 0),
             'bridgeReady=' + (typeof (window.bridgeMessagesHandlers && window.bridgeMessagesHandlers.emit))
            ]);
        } catch (e) { send('heartbeat-error', [e && e.message || String(e)]); }
        if (tick >= 30) clearInterval(heartbeat);
      }, 500);

      send('log', ['[diag] user script installed']);
    })();
    """

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard message.name == Self.handlerName,
              let dict = message.body as? [String: Any] else { return }
        let level = (dict["level"] as? String) ?? "log"
        let content = (dict["message"] as? String) ?? ""
        let logLevel: LogLevel = (level == "error" || level == "window.error" || level == "unhandledrejection") ? .error : .debug
        Logger.common(
            message: "[JS \(level)] \(content)",
            level: logLevel,
            category: .webViewInAppMessages
        )
    }
}
