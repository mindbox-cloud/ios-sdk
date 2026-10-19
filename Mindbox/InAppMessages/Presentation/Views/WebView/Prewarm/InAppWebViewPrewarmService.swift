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
    func prewarmProcess()

    func prewarmResources(for config: ConfigResponse)

    func borrowWarmWebView() -> WKWebView?

    func parkWarmWebView()

    func returnWarmWebView(_ webView: WKWebView)

    func rememberObservedHosts(_ hosts: [String])
}

final class InAppWebViewPrewarmService: InAppWebViewPrewarmServiceProtocol {

    private let persistenceStorage: PersistenceStorage
    private let learnedHostsStore: InAppWebViewLearnedHostsStore
    private let makeWebView: () -> WKWebView
    private let fetchHTML: (URL, @escaping (String?) -> Void) -> Void
    private let loadCachedConfig: () -> ConfigResponse?

    private var warmWebView: WKWebView?
    private var hasBeenBorrowed = false
    private var resourcePrewarmLatched = false
    private var isLentToShow = false
    private var isSettlingToBlank = false
    private var memoryWarningObserver: NSObjectProtocol?
    private let prewarmNavigationPolicy = InAppWebViewPrewarmNavigationPolicy()

    private var lastPrewarmContentPage: (html: String, baseURL: URL)?
    private var healAttemptsUsed = 0
    private var healPurgeRemovedEntry = false
    private var isHealPurgeInFlight = false
    private static let maxHealAttempts = WebViewNoCacheRetryPolicy.maxAttempts
    private let isCacheEnabled: () -> Bool
    // Must call completion on main: the reload it sequences navigates the web view.
    private let purgeCache: (_ failedURL: String?, _ completion: @escaping (_ didRemoveAnything: Bool) -> Void) -> Void
    private let httpErrorMonitor = PrewarmHTTPErrorMonitor()

    init(persistenceStorage: PersistenceStorage,
         makeWebView: @escaping () -> WKWebView = { InAppWebViewFactory.make() },
         fetchHTML: @escaping (URL, @escaping (String?) -> Void) -> Void = InAppWebViewPrewarmService.defaultFetchHTML,
         loadCachedConfig: @escaping () -> ConfigResponse? = InAppWebViewPrewarmService.defaultLoadCachedConfig,
         isCacheEnabled: @escaping () -> Bool = { InAppWebViewDataStore.isCacheFeatureEnabled },
         purgeCache: @escaping (_ failedURL: String?, _ completion: @escaping (_ didRemoveAnything: Bool) -> Void) -> Void = InAppWebViewDataStore.purgeCache) {
        self.persistenceStorage = persistenceStorage
        self.learnedHostsStore = InAppWebViewLearnedHostsStore(persistenceStorage: persistenceStorage)
        self.makeWebView = makeWebView
        self.fetchHTML = fetchHTML
        self.loadCachedConfig = loadCachedConfig
        self.isCacheEnabled = isCacheEnabled
        self.purgeCache = purgeCache
        startMemoryWarningObserver()
        httpErrorMonitor.onHTTPError = { [weak self] url in
            self?.healPrewarmContentPage(failedURL: url)
        }
    }

    deinit {
        if let memoryWarningObserver {
            NotificationCenter.default.removeObserver(memoryWarningObserver)
        }
    }

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
        DispatchQueue.global(qos: .utility).async { [weak self] in
            // Pays the latch's cached-config decode here, off the main thread.
            _ = InAppWebViewDataStore.isCacheFeatureEnabled
            guard let self, let config = self.loadCachedConfig() else { return }
            guard Self.isPrewarmEnabled(in: config) else { return }
            let layers = InAppWebViewPrewarmPlanner.webviewLayers(in: config)
            guard !layers.isEmpty else { return }
            self.startResourcePrewarm(layers: layers)
        }
    }

    func prewarmResources(for config: ConfigResponse) {
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

    private static func isPrewarmEnabled(in config: ConfigResponse) -> Bool {
        config.settings?.featureToggles?.shouldPrewarmInAppWebView
            ?? FeatureFlag.shouldPrewarmInAppWebView.defaultValue
    }

    func borrowWarmWebView() -> WKWebView? {
        guard Thread.isMainThread else {
            Logger.common(message: "[WebView] Prewarm: borrowWarmWebView() called off the main thread — ignoring",
                          level: .error, category: .webViewInAppMessages)
            return nil
        }
        hasBeenBorrowed = true
        lastPrewarmContentPage = nil
        guard let webView = warmWebView else { return nil }
        guard !isLentToShow else { return nil }
        guard !webView.isLoading || isSettlingToBlank else {
            webView.stopLoading()
            loadBlank(on: webView)
            Logger.common(message: "[WebView] Prewarm: instance is mid-navigation at borrow — parking it, the show gets a fresh WebView",
                          level: .info, category: .webViewInAppMessages)
            return nil
        }
        webView.stopLoading()
        loadBlank(on: webView)
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
            guard self.isLentToShow, webView.superview == nil else { return }
            self.park(webView)
        }
    }

    func returnWarmWebView(_ webView: WKWebView) {
        guard Thread.isMainThread else {
            Logger.common(message: "[WebView] Prewarm: returnWarmWebView() called off the main thread — ignoring",
                          level: .error, category: .webViewInAppMessages)
            return
        }
        guard isLentToShow, webView === warmWebView else { return }

        park(webView)
    }

    private func park(_ webView: WKWebView) {
        webView.removeFromSuperview()
        isLentToShow = false
        if #available(iOS 14.0, *) {
            webView.configuration.userContentController.removeAllScriptMessageHandlers()
        } else {
            webView.configuration.userContentController.removeScriptMessageHandler(forName: Constants.WebViewBridgeJS.handlerName)
            webView.configuration.userContentController.removeScriptMessageHandler(forName: Constants.WebViewHTTPErrorJS.handlerName)
        }
        webView.navigationDelegate = nil
        loadBlank(on: webView)
    }

    func rememberObservedHosts(_ hosts: [String]) {
        guard let configuration = persistenceStorage.configuration else { return }
        learnedHostsStore.remember(hosts, endpoint: configuration.endpoint)
    }

    // MARK: Resource prewarm

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
                self.isSettlingToBlank = false
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
            Logger.common(message: "[WebView] Prewarm: content page fetch failed, launch degrades to preconnect-only",
                          level: .info, category: .webViewInAppMessages)
            return
        }
        guard !hasBeenBorrowed, let warmWebView else { return }
        let prewarmBaseURL = InAppWebViewPrewarmPlanner.prewarmContentBaseURL(
            from: baseURL, endpoint: endpoint, deviceUUID: deviceUUID
        )
        prewarmNavigationPolicy.allow(prewarmBaseURL)
        lastPrewarmContentPage = isCacheEnabled() ? (html, prewarmBaseURL) : nil
        healAttemptsUsed = 0
        healPurgeRemovedEntry = false
        isHealPurgeInFlight = false
        loadContentPage(html, baseURL: prewarmBaseURL, on: warmWebView)
        Logger.common(message: "[WebView] Prewarm: content page under \(prewarmBaseURL.absoluteString), endpoint \(endpoint)",
                      level: .info, category: .webViewInAppMessages)
    }

    private func loadContentPage(_ html: String, baseURL: URL, on webView: WKWebView) {
        isSettlingToBlank = false
        webView.loadHTMLString(html, baseURL: baseURL)
        settleContentPage(after: Self.contentPageSettleBudget)
    }

    private func settleContentPage(after budget: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + budget) { [weak self] in
            guard let self, !self.hasBeenBorrowed, let warmWebView = self.warmWebView else { return }
            guard warmWebView.isLoading else { return }

            warmWebView.stopLoading()
            self.loadBlank(on: warmWebView)
            Logger.common(message: "[WebView] Prewarm: content page still loading after \(budget)s — settling the instance so a show can reuse it",
                          level: .info, category: .webViewInAppMessages)
        }
    }

    private static let contentPageSettleBudget: TimeInterval = 5

    private func loadBlank(on webView: WKWebView) {
        isSettlingToBlank = true
        webView.loadHTMLString(Self.blankPage, baseURL: nil)
    }

    private func installHTTPErrorMonitor(on webView: WKWebView?) {
        guard let controller = webView?.configuration.userContentController else { return }
        controller.removeScriptMessageHandler(forName: Constants.WebViewHTTPErrorJS.handlerName)
        controller.add(httpErrorMonitor, name: Constants.WebViewHTTPErrorJS.handlerName)
    }

    func healPrewarmContentPage(failedURL: String?) {
        Logger.common(message: "[WebView] Prewarm: subresource error — \(InAppWebViewHTTPError.loadFailureDescription) for \(failedURL ?? "nil")",
                      level: .debug, category: .webViewInAppMessages)
        guard InAppWebViewHTTPError.isRecoverable(url: failedURL) else { return }
        guard !hasBeenBorrowed, !healPurgeRemovedEntry, !isHealPurgeInFlight,
              healAttemptsUsed < Self.maxHealAttempts,
              warmWebView != nil, let page = lastPrewarmContentPage else { return }
        healAttemptsUsed += 1
        isHealPurgeInFlight = true
        Logger.common(message: "[WebView] Prewarm: \(InAppWebViewHTTPError.loadFailureDescription) for script \(failedURL ?? "nil")"
                        + " — purging its host's cache and reloading the content page (attempt \(healAttemptsUsed)/\(Self.maxHealAttempts))",
                      level: .info, category: .webViewInAppMessages)
        purgeCache(failedURL) { [weak self] didRemoveAnything in
            guard let self else { return }
            self.isHealPurgeInFlight = false
            if didRemoveAnything { self.healPurgeRemovedEntry = true }
            guard !self.hasBeenBorrowed, let warmWebView = self.warmWebView else { return }
            self.loadContentPage(page.html, baseURL: page.baseURL, on: warmWebView)
        }
    }

    private enum ReleaseReason: String {
        case featureToggleOff = "the prewarm feature toggle is off"
        case noWebviewInApps = "no webview in-apps in config"
    }

    private func releaseUnusedWarmWebView(reason: ReleaseReason) {
        DispatchQueue.main.async {
            self.resourcePrewarmLatched = true
            self.lastPrewarmContentPage = nil
            guard !self.hasBeenBorrowed, let webView = self.warmWebView else { return }
            webView.stopLoading()
            self.warmWebView = nil
            Logger.common(message: "[WebView] Prewarm: \(reason.rawValue) — releasing the warm instance",
                          level: .info, category: .webViewInAppMessages)
        }
    }

    private static let blankPage = InAppWebViewPrewarmPlanner.preconnectHTML(hosts: [])

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

    var onHTTPError: ((_ url: String?) -> Void)?

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard message.name == Constants.WebViewHTTPErrorJS.handlerName,
              let failedURL = InAppWebViewHTTPError.failedResourceURL(from: message.body) else { return }
        onHTTPError?(failedURL)
    }
}
