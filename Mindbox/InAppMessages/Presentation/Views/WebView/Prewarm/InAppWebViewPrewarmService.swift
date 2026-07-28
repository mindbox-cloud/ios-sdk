//
//  InAppWebViewPrewarmService.swift
//  Mindbox
//
//  Created by Sergei Semko on 06.07.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import UIKit
import WebKit
import MindboxLogger

protocol InAppWebViewPrewarmServiceProtocol: AnyObject {
    /// Stage 1, at SDK initialization: when the previous launch left a cached config with
    /// webview in-apps, creates the warm instance and starts the resource prewarm ahead of
    /// the fresh config download. Hosts without webview in-apps never pay for a
    /// web-content process — nothing is created until a config proves it's needed.
    func prewarmProcess()

    /// Stage 2, when a freshly downloaded config has been parsed: starts the resource
    /// prewarm if it hasn't run from the cached config yet, or releases the stage-1
    /// instance when the config has no webview in-apps.
    func prewarmResources(for config: ConfigResponse)

    /// Hands the warm instance to a show (borrow, not consume — the same live instance
    /// serves subsequent shows). Any prewarm page is torn down first.
    func borrowWarmWebView() -> WKWebView?

    /// Called when a show is torn down: navigates the parked instance to a blank page so
    /// the closed in-app's JS stops running hidden, keeping the process warm for the next show.
    func parkWarmWebView()

    /// Called by a show when its page is done: persists the observed resource hosts for
    /// the next launch's preconnect.
    func rememberObservedHosts(_ hosts: [String])
}

final class InAppWebViewPrewarmService: InAppWebViewPrewarmServiceProtocol {

    private let persistenceStorage: PersistenceStorage
    private let learnedHostsStore: InAppWebViewLearnedHostsStore
    private let makeWebView: () -> WKWebView
    private let fetchHTML: (URL, @escaping (String?) -> Void) -> Void
    private let loadCachedConfig: () -> ConfigResponse?

    // Main-thread confined (WKWebView requirement); all mutations hop to main. The flags
    // latch for the rest of the launch by design: after the first borrow the cache is
    // warmer than any prewarm could make it, and re-running the prewarm would navigate a
    // live show's webview.
    private var warmWebView: WKWebView?
    private var hasBeenBorrowed = false
    // Write-once, decided on the main hop: set when the resource prewarm starts OR when a
    // config-driven release fires. The release must latch too — one that lands on main
    // before the slow stage-1 hop has nothing to drop yet, and without the latch the stale
    // stage-1 block would then create the instance a fresh config already said to kill.
    private var resourcePrewarmLatched = false
    // True between borrow and park: `superview` alone can't tell (there is a window
    // between borrow and addSubview).
    private var isLentToShow = false
    private var memoryWarningObserver: NSObjectProtocol?
    // Retained here because navigationDelegate is weak; armed until the first borrow.
    private let prewarmNavigationPolicy = InAppWebViewPrewarmNavigationPolicy()

    private var lastPrewarmContentPage: (html: String, baseURL: URL)?
    private var hasHealedPrewarmContentPage = false
    private let isCacheEnabled: () -> Bool
    // Contract: must call `completion` on the main thread — the reload it sequences
    // navigates the webview. The default (`InAppWebViewDataStore.purgeCache`) guarantees it.
    private let purgeCache: (_ failedURL: String?, _ completion: @escaping () -> Void) -> Void
    private let httpErrorMonitor = PrewarmHTTPErrorMonitor()

    init(persistenceStorage: PersistenceStorage,
         makeWebView: @escaping () -> WKWebView = { InAppWebViewFactory.make() },
         fetchHTML: @escaping (URL, @escaping (String?) -> Void) -> Void = InAppWebViewPrewarmService.defaultFetchHTML,
         loadCachedConfig: @escaping () -> ConfigResponse? = InAppWebViewPrewarmService.defaultLoadCachedConfig,
         isCacheEnabled: @escaping () -> Bool = { InAppWebViewDataStore.isCacheFeatureEnabled },
         purgeCache: @escaping (_ failedURL: String?, _ completion: @escaping () -> Void) -> Void = InAppWebViewDataStore.purgeCache) {
        self.persistenceStorage = persistenceStorage
        self.learnedHostsStore = InAppWebViewLearnedHostsStore(persistenceStorage: persistenceStorage)
        self.makeWebView = makeWebView
        self.fetchHTML = fetchHTML
        self.loadCachedConfig = loadCachedConfig
        self.isCacheEnabled = isCacheEnabled
        self.purgeCache = purgeCache
        startMemoryWarningObserver()
        httpErrorMonitor.onHTTPError = { [weak self] url, status in
            self?.healPrewarmContentPage(failedURL: url, status: status)
        }
    }

    deinit {
        // Block-based observers are not auto-removed. The token is optional solely
        // because its block captures self and can't be created during two-phase init.
        if let memoryWarningObserver {
            NotificationCenter.default.removeObserver(memoryWarningObserver)
        }
    }

    /// Frees the parked warm instance under memory pressure: the HTTP cache is disk-level
    /// and survives, so the next show only re-pays the web-content process spin-up. An
    /// instance lent to a live show is left alone — the show owns it.
    private func startMemoryWarningObserver() {
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, let webView = self.warmWebView, !self.isLentToShow else { return }
            webView.stopLoading()
            self.warmWebView = nil
            self.lastPrewarmContentPage = nil
            Logger.common(message: "[WebView] Prewarm: memory warning — releasing the parked warm instance",
                          level: .info, category: .webViewInAppMessages)
        }
    }

    func prewarmProcess() {
        // Boots from the PREVIOUS launch's cached config: waiting for the fresh one would
        // lose the race to a launch-triggered show. A stale URL is harmless — the next
        // launch picks up the fresh config.
        DispatchQueue.global(qos: .utility).async { [weak self] in
            // Warm the cache-toggle latch here: its initializer reads and decodes the
            // cached config, and every other first-access path runs on the main thread.
            _ = InAppWebViewDataStore.isCacheFeatureEnabled
            guard let self, let config = self.loadCachedConfig() else { return }
            guard Self.isPrewarmEnabled(in: config) else { return }
            let layers = InAppWebViewPrewarmPlanner.webviewLayers(in: config)
            guard !layers.isEmpty else { return }
            self.startResourcePrewarm(layers: layers)
        }
    }

    func prewarmResources(for config: ConfigResponse) {
        // A fresh config that turns the toggle off also kills a stage-1 instance started
        // under the previous launch's config.
        guard Self.isPrewarmEnabled(in: config) else {
            releaseUnusedWarmWebView(reason: .featureToggleOff)
            return
        }
        let layers = InAppWebViewPrewarmPlanner.webviewLayers(in: config)
        guard !layers.isEmpty else {
            releaseUnusedWarmWebView(reason: .noWebviewInApps)
            return
        }
        startResourcePrewarm(layers: layers)
    }

    /// The prewarm half of the WebView feature toggles, read from the config each stage
    /// works with: stage 1 sees the previous launch's cached toggles, stage 2 the fresh
    /// ones. An absent key or section means "enabled" — a kill switch, not an opt-in.
    private static func isPrewarmEnabled(in config: ConfigResponse) -> Bool {
        config.settings?.featureToggles?.shouldPrewarmInAppWebView
            ?? FeatureFlag.shouldPrewarmInAppWebView.defaultValue
    }

    func borrowWarmWebView() -> WKWebView? {
        // Never trap in a host app: an off-main caller just doesn't get the warm
        // instance — returning nil is always correct (the show creates its own WebView
        // on the shared store) and touches none of the main-confined state.
        guard Thread.isMainThread else {
            Logger.common(message: "[WebView] Prewarm: borrowWarmWebView() called off the main thread — ignoring",
                          level: .error, category: .webViewInAppMessages)
            return nil
        }
        // Latch even when there is nothing to hand out: a show is starting, and a
        // resource prewarm kicked off after this point would compete with it.
        hasBeenBorrowed = true
        // The prewarm's healing days are over (the show runs its own retry policy);
        // don't keep the page HTML reachable for the rest of the process.
        lastPrewarmContentPage = nil
        guard let webView = warmWebView else { return nil }
        // Presentation is serialized upstream, but that flag has known races — never let
        // a second show steal the instance out of an on-screen in-app.
        guard !isLentToShow else { return nil }
        // Never hand out an instance mid-navigation: the show's load would land on a
        // half-committed document and its didFinish can fire before the page's module
        // scripts evaluate. Park it instead; the show creates a fresh WKWebView on the
        // same shared store (pays process spin-up, keeps the HTTP cache).
        guard !webView.isLoading else {
            webView.stopLoading()
            webView.loadHTMLString(Self.blankPage, baseURL: nil)
            Logger.common(message: "[WebView] Prewarm: instance is mid-navigation at borrow — parking it, the show gets a fresh WebView",
                          level: .info, category: .webViewInAppMessages)
            return nil
        }
        // The instance belongs to the show from here; the blank load tears down the
        // prewarm page so its JS can't compete with the show for bandwidth. The bridge's
        // staleness filter ignores both leftovers' callbacks.
        webView.stopLoading()
        webView.loadHTMLString(Self.blankPage, baseURL: nil)
        webView.removeFromSuperview()
        isLentToShow = true
        return webView
    }

    func parkWarmWebView() {
        DispatchQueue.main.async {
            guard let webView = self.warmWebView else {
                self.isLentToShow = false
                return
            }
            // Only park an instance no live show is presenting (a newer show may have
            // borrowed it before this teardown arrived).
            guard webView.superview == nil else { return }
            self.isLentToShow = false
            // Fully detach the finished show: WKUserContentController retains its script
            // handlers, so the previous show's bridge would otherwise stay on the
            // parked instance until the next show replaces it.
            if #available(iOS 14.0, *) {
                webView.configuration.userContentController.removeAllScriptMessageHandlers()
            } else {
                webView.configuration.userContentController.removeScriptMessageHandler(forName: Constants.WebViewBridgeJS.handlerName)
                webView.configuration.userContentController.removeScriptMessageHandler(forName: Constants.WebViewHTTPErrorJS.handlerName)
            }
            webView.loadHTMLString(Self.blankPage, baseURL: nil)
        }
    }

    func rememberObservedHosts(_ hosts: [String]) {
        guard let configuration = persistenceStorage.configuration else { return }
        learnedHostsStore.remember(hosts, endpoint: configuration.endpoint)
    }

    // MARK: Resource prewarm

    /// Two loads on the warm instance, both under the shows' cache partition (`baseUrl`
    /// from the config's webview layer): a preconnect page (DNS+TCP+TLS to every known
    /// host), then the real content page with the official prewarm parameters on its
    /// baseURL — a runtime that knows the contract downloads its bundles straight into
    /// the HTTP cache; an older runtime degrades to a plain page warm.
    private func startResourcePrewarm(layers: [WebviewContentBackgroundLayerDTO]) {
        guard let configuration = persistenceStorage.configuration,
              let (baseURL, contentURL) = InAppWebViewPrewarmPlanner.prewarmSource(for: layers) else { return }

        let hosts = InAppWebViewPrewarmPlanner.preconnectHosts(
            layers: layers,
            apiDomain: configuration.domain,
            learnedHosts: learnedHostsStore.hosts(endpoint: configuration.endpoint)
        )
        let endpoint = configuration.endpoint
        let deviceUUID = persistenceStorage.deviceUUID ?? ""

        DispatchQueue.main.async {
            guard !self.hasBeenBorrowed, !self.resourcePrewarmLatched else { return }
            self.resourcePrewarmLatched = true
            if self.warmWebView == nil {
                self.warmWebView = self.makeWebView()
                self.warmWebView?.navigationDelegate = self.prewarmNavigationPolicy
                self.installHTTPErrorMonitor(on: self.warmWebView)
            }
            if !hosts.isEmpty {
                self.prewarmNavigationPolicy.allow(baseURL)
                self.warmWebView?.loadHTMLString(InAppWebViewPrewarmPlanner.preconnectHTML(hosts: hosts), baseURL: baseURL)
                Logger.common(message: "[WebView] Prewarm: preconnect to \(hosts.joined(separator: ",")) under \(baseURL.absoluteString)",
                              level: .info, category: .webViewInAppMessages)
            }
            self.fetchHTML(contentURL) { html in
                DispatchQueue.main.async { [weak self] in
                    self?.loadPrewarmContentPage(html: html, baseURL: baseURL, endpoint: endpoint, deviceUUID: deviceUUID)
                }
            }
        }
    }

    private func loadPrewarmContentPage(html: String?, baseURL: URL, endpoint: String, deviceUUID: String) {
        guard let html else {
            // No retry by design (the latch stands): this launch degrades to preconnect-only.
            Logger.common(message: "[WebView] Prewarm: content page fetch failed, launch degrades to preconnect-only",
                          level: .info, category: .webViewInAppMessages)
            return
        }
        // The instance can be gone by now — borrowed by a show, or dropped by a
        // config-driven release that landed while the fetch was in flight. Either way there
        // is nothing to warm, and logging success would misreport it.
        guard !hasBeenBorrowed, let warmWebView else { return }
        let prewarmBaseURL = InAppWebViewPrewarmPlanner.prewarmContentBaseURL(
            from: baseURL, endpoint: endpoint, deviceUUID: deviceUUID
        )
        prewarmNavigationPolicy.allow(prewarmBaseURL)
        lastPrewarmContentPage = isCacheEnabled() ? (html, prewarmBaseURL) : nil
        hasHealedPrewarmContentPage = false
        warmWebView.loadHTMLString(html, baseURL: prewarmBaseURL)
        Logger.common(message: "[WebView] Prewarm: content page under \(prewarmBaseURL.absoluteString), endpoint \(endpoint)",
                      level: .info, category: .webViewInAppMessages)
    }

    private func installHTTPErrorMonitor(on webView: WKWebView?) {
        guard let controller = webView?.configuration.userContentController else { return }
        // Idempotent remove-then-add, same as the bridge: never crash on a leftover handler.
        controller.removeScriptMessageHandler(forName: Constants.WebViewHTTPErrorJS.handlerName)
        controller.add(httpErrorMonitor, name: Constants.WebViewHTTPErrorJS.handlerName)
    }

    func healPrewarmContentPage(failedURL: String?, status: Int?) {
        guard InAppWebViewHTTPError.isRecoverable(url: failedURL, status: status) else { return }
        guard !hasBeenBorrowed, !hasHealedPrewarmContentPage,
              warmWebView != nil, let page = lastPrewarmContentPage else { return }
        hasHealedPrewarmContentPage = true
        Logger.common(message: "[WebView] Prewarm: HTTP \(status.map(String.init) ?? "?") for script \(failedURL ?? "nil") — purging its host's cache and reloading the content page",
                      level: .info, category: .webViewInAppMessages)
        purgeCache(failedURL) { [weak self] in
            // Re-check after the async purge: a show may have borrowed the instance (or a
            // release dropped it) while the purge was in flight — the prewarm must never
            // navigate a webview it no longer owns.
            guard let self, !self.hasBeenBorrowed, let warmWebView = self.warmWebView else { return }
            warmWebView.loadHTMLString(page.html, baseURL: page.baseURL)
        }
    }

    private enum ReleaseReason: String {
        case featureToggleOff = "the prewarm feature toggle is off"
        case noWebviewInApps = "no webview in-apps in config"
    }

    /// Most host apps have no webview in-apps: once the config proves that, drop the
    /// stage-1 instance so they don't keep an idle web-content process. The prewarm does
    /// not restart within this launch — a show then simply creates its own WebView.
    private func releaseUnusedWarmWebView(reason: ReleaseReason) {
        DispatchQueue.main.async {
            // Latch before the guard: even with nothing to drop yet, a stage-1 hop that
            // lands after this release must not start a prewarm the config just killed.
            self.resourcePrewarmLatched = true
            self.lastPrewarmContentPage = nil
            guard !self.hasBeenBorrowed, let webView = self.warmWebView else { return }
            webView.stopLoading()
            self.warmWebView = nil
            Logger.common(message: "[WebView] Prewarm: \(reason.rawValue) — releasing the warm instance",
                          level: .info, category: .webViewInAppMessages)
        }
    }

    // The empty-page skeleton is exactly a preconnect page with no hosts — reuse the
    // planner so the parked/teardown markup can never drift from the preconnect markup.
    private static let blankPage = InAppWebViewPrewarmPlanner.preconnectHTML(hosts: [])

    /// One transport with the shows' fetch (`InAppWebViewHTMLFetcher`): the prewarm must
    /// fill exactly the cache the shows read.
    private static func defaultFetchHTML(url: URL, completion: @escaping (String?) -> Void) {
        let (session, request) = InAppWebViewHTMLFetcher.sessionAndRequest(for: url)
        session.dataTask(with: request) { data, response, _ in
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode),
                  let data, let html = String(data: data, encoding: .utf8) else {
                completion(nil)
                return
            }
            completion(html)
        }.resume()
    }

    private static func defaultLoadCachedConfig() -> ConfigResponse? {
        InAppConfigurationRepository().fetchDecodedConfigFromCache()
    }
}

private final class PrewarmHTTPErrorMonitor: NSObject, WKScriptMessageHandler {

    var onHTTPError: ((_ url: String?, _ status: Int?) -> Void)?

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard message.name == Constants.WebViewHTTPErrorJS.handlerName,
              let httpError = InAppWebViewHTTPError.message(from: message.body) else { return }
        onHTTPError?(httpError.url, httpError.status)
    }
}
