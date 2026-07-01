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
        // MEASUREMENT (throwaway): caching prototype toggle + instance reuse.
        //   -MBWVPersistentStore → persistent WebKit data store (cache ON).
        //   -MBWVReuseInstance   → reuse the pre-warmed WKWebView (live process) instead of a fresh one.
        let usesPersistentStore = WebViewShowProfiler.usesPersistentStore
        let webView: WKWebView
        if let warm = WebViewShowProfiler.borrowWarmWebView() {
            // Reused: same live instance/process is kept across shows (hidden, not destroyed).
            webView = warm
            WebViewShowProfiler.shared.setMode((usesPersistentStore ? "persistent" : "ephemeral") + "+reuse")
        } else {
            let config = WKWebViewConfiguration()
            config.websiteDataStore = usesPersistentStore ? .default() : .nonPersistent()
            config.applicationNameForUserAgent = userAgent
            config.allowsInlineMediaPlayback = true
            config.mediaTypesRequiringUserActionForPlayback = []
            webView = WKWebView(frame: .zero, configuration: config)
            WebViewShowProfiler.shared.setMode(usesPersistentStore ? "persistent" : "ephemeral")
        }

        // MEASUREMENT (throwaway): inject the timing probe + its handler. Idempotent
        // (remove-then-add) so reusing the same instance across shows never duplicates a handler.
        let ucc = webView.configuration.userContentController
        ucc.removeScriptMessageHandler(forName: "MBProfiler")
        ucc.removeAllUserScripts()
        ucc.add(WebViewProfilerScriptHandler(), name: "MBProfiler")
        ucc.addUserScript(
            WKUserScript(source: WebViewShowProfiler.probeJS, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        )
        WebViewShowProfiler.shared.mark("webViewCreated")
        #if DEBUG
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        #endif
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
        WebViewShowProfiler.shared.mark("loadHTMLStart")
        let url = URL(string: baseUrl)
        let contentURL = URL(string: contentUrl)
        bridge.updateContentURL(contentURL)

        fetchHTML(from: contentUrl) { [weak webView] html in
            guard let webView else {
                DispatchQueue.main.async {
                    onFailure()
                }
                return
            }

            if let html {
                DispatchQueue.main.async {
                    WebViewShowProfiler.shared.mark("loadHTMLString")
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
            params[PayloadKey.firstInitializationDateTime] = firstInitDate.toString(withFormat: .utc)
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

            WebViewShowProfiler.shared.mark("htmlFetchEnd")
            self?.log("HTML loaded successfully (\(htmlString.count) chars)")
            completion(htmlString)
        }

        WebViewShowProfiler.shared.mark("htmlFetchStart")
        task.resume()
    }
}

// swiftlint:disable file_length
// MARK: - MEASUREMENT / THROWAWAY profiling harness
//
// Records per-step timestamps for ONE WebView in-app show and emits a single
// `[WVProfile] SUMMARY` line for offline analysis. This is profiling scaffolding for the
// caching prototype, NOT production code — remove before ship. Lives in this file (already
// in the build) to avoid pbxproj surgery for a throwaway class.
//
// Native marks (ms from t0 = viewDidLoad):
//   begin → setupWebView → webViewCreated → loadHTMLStart → htmlFetchStart →
//   htmlFetchEnd → loadHTMLString → navStart → navFinish → jsReadyCheck → initMessage
// JS marks (from the injected probe, stitched onto the native timeline at navStart):
//   firstPaint / fcp / lcp (best-effort; WebKit may not emit), domContentLoaded,
//   domComplete, loadEventEnd, largestImgEnd — the last two are the robust
//   "content actually visible/loaded" signals (heavy images load AFTER navFinish).

final class WebViewShowProfiler {

    static let shared = WebViewShowProfiler()

    private let lock = NSLock()
    private var t0: CFAbsoluteTime?
    private var marks: [(label: String, ms: Double)] = []
    private var jsMarks: [String: Int] = [:]
    private var mode = "?"
    private var finalized = false

    private init() {}

    /// Caching mode in effect for this show (persistent / ephemeral). Set at WKWebView creation.
    func setMode(_ mode: String) {
        lock.lock(); self.mode = mode; lock.unlock()
    }

    /// Resets the timeline and sets t0. Call once at the very start of the show (viewDidLoad).
    func begin() {
        // MEASUREMENT (throwaway): force os_log to capture our .info marks without UI taps.
        if ProcessInfo.processInfo.arguments.contains("-MBWVForceInfoLog") {
            MBLogger.shared.logLevel = .info
        }
        let now = CFAbsoluteTimeGetCurrent()
        lock.lock()
        t0 = now
        marks = [(label: "begin", ms: 0)]
        jsMarks = [:]
        finalized = false
        lock.unlock()
        Logger.common(message: "[WVProfile] mark begin +0ms", level: .info, category: .webViewInAppMessages)
    }

    /// Records a native lifecycle mark. Safe to call from any thread.
    func mark(_ label: String) {
        let now = CFAbsoluteTimeGetCurrent()
        lock.lock()
        if t0 == nil { t0 = now; marks = []; jsMarks = [:]; finalized = false }
        let ms = (now - (t0 ?? now)) * 1000
        marks.append((label: label, ms: ms))
        lock.unlock()
        Logger.common(message: "[WVProfile] mark \(label) +\(Int(ms))ms", level: .info, category: .webViewInAppMessages)
    }

    /// Ingests the consolidated JS payload from the injected probe and emits the SUMMARY.
    func ingestJS(_ body: Any) {
        guard let dict = body as? [String: Any] else {
            Logger.common(message: "[WVProfile] JS payload not a dict: \(body)", level: .info, category: .webViewInAppMessages)
            return
        }
        lock.lock()
        for (key, value) in dict {
            if let number = value as? NSNumber { jsMarks[key] = number.intValue }
        }
        lock.unlock()
        logSummary()
    }

    private func logSummary() {
        lock.lock()
        guard !finalized, t0 != nil else { lock.unlock(); return }
        finalized = true

        let navStart = Int(marks.first(where: { $0.label == "navStart" })?.ms ?? 0)
        let nativeStr = marks.map { "\($0.label)=\(Int($0.ms))" }.joined(separator: " ")

        // JS timings are document-relative → stitch onto the native timeline at navStart.
        let jsOrder = ["firstPaint", "fcp", "lcp", "domContentLoaded", "domComplete", "loadEventEnd", "lastImageEnd", "lastResourceEnd"]
        let jsStr = jsOrder
            .compactMap { key in jsMarks[key].map { "\(key)=\(navStart + $0)" } }
            .joined(separator: " ")
        let extra = ["resourceCount", "imageCount", "transferBytes", "lcpSize", "finalizedByCap"]
            .compactMap { key in jsMarks[key].map { "\(key)=\($0)" } }
            .joined(separator: " ")
        let currentMode = mode
        lock.unlock()

        Logger.common(
            message: "[WVProfile] SUMMARY mode=\(currentMode) | NATIVE \(nativeStr) | JS(from t0) \(jsStr) | \(extra)",
            level: .info,
            category: .webViewInAppMessages
        )
    }

    /// `true` when launched with `-MBWVPersistentStore` → use a persistent WebKit data store.
    static var usesPersistentStore: Bool {
        ProcessInfo.processInfo.arguments.contains("-MBWVPersistentStore")
    }

    // MEASUREMENT (throwaway): a session-persistent warm WKWebView. Created once at in-app
    // subsystem start, loads a local "cacher" page (pulls tracker.js into the persistent cache
    // and keeps the web-content process alive). Two modes:
    //   -MBWVPrewarm       → hold a throwaway warm WebView (WebKit reuses its prewarmed process).
    //   -MBWVReuseInstance → hold it AND reuse the SAME live instance for EVERY show — it is
    //                        borrowed (not consumed) and kept across shows (hidden, not destroyed),
    //                        so show #2, #3… stay as fast as show #1.
    private static var warmWebView: WKWebView?
    private static var warmIsForReuse = false

    /// Local cacher page: warms the process and seeds the persistent cache with the SHARED static
    /// runtime (tracker.js + main.js + fonts). These are the resources every WebView in-app shares.
    /// NOTE: byendpoint.js is NOT cacheable this way — it is loaded by the runtime per endpoint at
    /// show time, so caching it needs the "load content without formId" approach (no form renders,
    /// but the runtime pulls byendpoint). Prototype: URLs hardcoded to what this test in-app uses;
    /// a shipped cacher would be a bundled/backend page knowing the current versions.
    private static let cacherResources = [
        "https://api.mindbox.ru/scripts/v1/tracker.js?v=1.0.29",
        "https://mobile-static.mindbox.ru/stable/inapps/webview/content/main.js?v=1.0.29"
    ]
    private static let cacherFontsCSS = "https://fonts.googleapis.com/css2?family=Source+Sans+3:ital,wght@0,200..900;1,200..900&display=swap"
    private static var cacherHTML: String {
        let scripts = cacherResources.map { "<script src=\"\($0)\"></script>" }.joined()
        return "<html><head><meta charset=\"utf-8\"><link rel=\"stylesheet\" href=\"\(cacherFontsCSS)\">\(scripts)</head><body></body></html>"
    }

    static func prewarmIfRequested() {
        let reuse = ProcessInfo.processInfo.arguments.contains("-MBWVReuseInstance")
        let prewarmOnly = ProcessInfo.processInfo.arguments.contains("-MBWVPrewarm")
        guard reuse || prewarmOnly else { return }
        DispatchQueue.main.async {
            guard warmWebView == nil else { return }
            let config = WKWebViewConfiguration()
            config.websiteDataStore = usesPersistentStore ? .default() : .nonPersistent()
            config.applicationNameForUserAgent = measurementUserAgent()
            config.allowsInlineMediaPlayback = true
            config.mediaTypesRequiringUserActionForPlayback = []
            let webView = WKWebView(frame: .zero, configuration: config)
            webView.loadHTMLString(cacherHTML, baseURL: URL(string: "https://inapp.local/popup"))
            warmWebView = webView
            warmIsForReuse = reuse
            Logger.common(message: "[WVProfile] prewarm: cacher loaded, warming process (reuse=\(reuse), store=\(usesPersistentStore ? "persistent" : "ephemeral"))",
                          level: .info, category: .webViewInAppMessages)
        }
    }

    /// Borrows the persistent warm WebView for a show WITHOUT consuming it — the reference is
    /// kept so the same live instance/process serves the next show too. Detaches it from any
    /// previous show's view hierarchy first. nil unless -MBWVReuseInstance.
    static func borrowWarmWebView() -> WKWebView? {
        guard warmIsForReuse, let webView = warmWebView else { return nil }
        webView.removeFromSuperview()
        return webView
    }

    /// Same UA formula as WebViewController.createUserAgent() — all inputs are static per app run,
    /// so the prewarmed WebView's UA matches the show's.
    private static func measurementUserAgent() -> String {
        let uf = DI.injectOrFail(UtilitiesFetcher.self)
        let sdkVersion = uf.sdkVersion ?? "unknown"
        let appVersion = uf.appVerson ?? "unknown"
        let appName = uf.hostApplicationName ?? "unknown"
        return "mindbox.sdk/\(sdkVersion) (\(DeviceModelHelper.os) \(DeviceModelHelper.iOSVersion); \(DeviceModelHelper.model)) \(appName)/\(appVersion)"
    }

    /// JS injected at documentStart. Installs paint/LCP observers and, after window load,
    /// posts ONE consolidated timing payload to the native `MBProfiler` handler.
    static let probeJS = """
    (function () {
      var marks = {};
      var lastResAt = 0;      // performance.now() when the most recent resource finished
      var loaded = false;
      var done = false;
      function rec(k, v) { if (typeof v === 'number' && isFinite(v)) marks[k] = Math.round(v); }
      try {
        new PerformanceObserver(function (l) {
          l.getEntries().forEach(function (e) {
            if (e.name === 'first-paint') rec('firstPaint', e.startTime);
            if (e.name === 'first-contentful-paint') rec('fcp', e.startTime);
          });
        }).observe({ type: 'paint', buffered: true });
      } catch (e) {}
      try {
        new PerformanceObserver(function (l) {
          var es = l.getEntries(); var last = es[es.length - 1];
          rec('lcp', last.startTime); rec('lcpSize', last.size);
        }).observe({ type: 'largest-contentful-paint', buffered: true });
      } catch (e) {}
      try {
        new PerformanceObserver(function (l) {
          l.getEntries().forEach(function (r) { if (r.responseEnd > lastResAt) lastResAt = r.responseEnd; });
        }).observe({ type: 'resource', buffered: true });
      } catch (e) {}
      function finalize(byCap) {
        if (done) return; done = true;
        try {
          var nav = performance.getEntriesByType('navigation')[0];
          if (nav) {
            rec('domContentLoaded', nav.domContentLoadedEventEnd);
            rec('domComplete', nav.domComplete);
            rec('loadEventEnd', nav.loadEventEnd);
          }
          var res = performance.getEntriesByType('resource');
          rec('resourceCount', res.length);
          var imgs = res.filter(function (r) {
            return r.initiatorType === 'img' || r.initiatorType === 'css' ||
                   /\\.(png|jpe?g|webp|gif|svg)(\\?|$)/i.test(r.name);
          });
          rec('imageCount', imgs.length);
          // Cross-origin resources report 0 bytes (no Timing-Allow-Origin), but responseEnd
          // timing IS available — use the latest finish time as the "content loaded" signal.
          var lastResEnd = 0, lastImgEnd = 0, bytes = 0;
          res.forEach(function (r) { if (r.responseEnd > lastResEnd) lastResEnd = r.responseEnd; bytes += (r.transferSize || r.encodedBodySize || 0); });
          imgs.forEach(function (r) { if (r.responseEnd > lastImgEnd) lastImgEnd = r.responseEnd; });
          rec('lastResourceEnd', lastResEnd);
          if (imgs.length) rec('lastImageEnd', lastImgEnd);
          rec('transferBytes', bytes);
          rec('finalizedByCap', byCap ? 1 : 0);
          window.webkit.messageHandlers.MBProfiler.postMessage(marks);
        } catch (e) {
          try { window.webkit.messageHandlers.MBProfiler.postMessage({ jsError: String(e) }); } catch (_) {}
        }
      }
      // Finalize when the network goes idle (no new resource for 1200ms after load), capped at 9s.
      var startedAt = performance.now();
      var iv = setInterval(function () {
        var now = performance.now();
        if (done) { clearInterval(iv); return; }
        if (loaded && (now - lastResAt) > 1200) { clearInterval(iv); finalize(false); }
        else if (now - startedAt > 9000) { clearInterval(iv); finalize(true); }
      }, 250);
      function onLoad() { loaded = true; lastResAt = Math.max(lastResAt, performance.now()); }
      if (document.readyState === 'complete') { onLoad(); }
      else { window.addEventListener('load', onLoad); }
    })();
    """
}

/// Forwards the JS probe's consolidated payload to the profiler. MEASUREMENT-ONLY.
final class WebViewProfilerScriptHandler: NSObject, WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        WebViewShowProfiler.shared.ingestJS(message.body)
    }
}
