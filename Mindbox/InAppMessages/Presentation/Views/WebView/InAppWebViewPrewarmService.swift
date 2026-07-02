//
//  InAppWebViewPrewarmService.swift
//  Mindbox
//
//  Created by Sergei Semko on 02.07.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import WebKit
import MindboxLogger

// MARK: - Shared WebKit data store

/// The single `WKWebsiteDataStore` used by every Mindbox WebView (prewarm and shows alike).
///
/// Persistence is what makes WebKit's standard header-driven HTTP cache survive relaunches:
/// `index.html` is fetched natively under the server's own freshness policy (see `fetchHTML`
/// in `MindboxWebViewFacade`) and dictates versioned (`?v=`) resource URLs, so cached assets
/// are never mismatched with their index — a version bump is a new URL, visible as soon as
/// the current index expires.
///
/// On iOS 17+ the store is isolated from the host app's `.default()` store so Mindbox web
/// content never shares cookies/storage with the host's own WebViews; earlier systems fall
/// back to `.default()`.
///
/// The disk cache is keyed per data store (cache-key salt is per store), so prewarm and shows
/// MUST use this same instance for prewarmed entries to be visible to shows.
enum InAppWebViewDataStore {
    // Stable identifier for the isolated store; changing it orphans the previous store.
    // swiftlint:disable:next force_unwrapping
    private static let identifier = UUID(uuidString: "8F0FD79A-4A3B-4B9C-9F5E-2D6B1C6A7E01")!

    static func shared() -> WKWebsiteDataStore {
        if #available(iOS 17.0, *) {
            return WKWebsiteDataStore(forIdentifier: identifier)
        } else {
            return WKWebsiteDataStore.default()
        }
    }
}

// MARK: - User agent

/// Mindbox UA suffix shared by shows and the prewarmed instance — all inputs are static per
/// app run, so a prewarmed WebView is indistinguishable from a per-show one.
enum InAppWebViewUserAgent {
    static func build() -> String {
        let utilitiesFetcher = DI.injectOrFail(UtilitiesFetcher.self)

        let sdkVersion = utilitiesFetcher.sdkVersion ?? "unknown"
        let appVersion = utilitiesFetcher.appVerson ?? "unknown"
        let appName = utilitiesFetcher.hostApplicationName ?? "unknown"

        return "mindbox.sdk/\(sdkVersion) (\(DeviceModelHelper.os) \(DeviceModelHelper.iOSVersion); \(DeviceModelHelper.model)) \(appName)/\(appVersion)"
    }
}

// MARK: - Prewarm planning (pure, unit-tested)

/// Derives everything the prewarm needs from the in-app config. Pure functions — no WebKit.
enum InAppWebViewPrewarmPlanner {

    /// WebKit partitions its HTTP cache by the top-level document's registrable domain, which
    /// for `loadHTMLString` is the `baseURL` host. Entries cached under one host are invisible
    /// under another, so the prewarm page MUST use the same `baseUrl` the shows use — taken
    /// from the config's webview layer, never hardcoded. Only layers that can actually show
    /// (carrying a contentUrl) and baseUrls with a real host qualify.
    static func partitionBaseURL(for layers: [WebviewContentBackgroundLayerDTO]) -> URL? {
        layers.lazy
            .filter { $0.contentUrl != nil }
            .compactMap { layer -> URL? in
                guard let url = layer.baseUrl.flatMap(URL.init(string:)), url.host != nil else { return nil }
                return url
            }
            .first
    }

    /// Hosts worth opening DNS+TCP+TLS to before the first show: every webview layer's
    /// `contentUrl` host, the configured API domain, plus hosts observed during previous
    /// shows (images/runtime CDNs the config doesn't mention). Nothing is downloaded.
    static func preconnectHosts(layers: [WebviewContentBackgroundLayerDTO],
                                apiDomain: String?,
                                learnedHosts: [String]) -> [String] {
        var hosts = Set(layers.compactMap { layer -> String? in
            guard let contentUrl = layer.contentUrl, let host = URL(string: contentUrl)?.host else { return nil }
            return host
        })
        if let apiDomain, !apiDomain.isEmpty {
            hosts.insert(apiDomain)
        }
        hosts.formUnion(learnedHosts)
        return hosts.sorted()
    }

    /// A page of `<link rel="preconnect">` hints: WebKit's network process opens pooled
    /// connections to each host without downloading anything; the show reuses the pool.
    static func preconnectHTML(hosts: [String]) -> String {
        let links = hosts
            .map { "<link rel=\"preconnect\" href=\"https://\($0)\" crossorigin><link rel=\"dns-prefetch\" href=\"https://\($0)\">" }
            .joined()
        return "<html><head><meta charset=\"utf-8\">\(links)</head><body></body></html>"
    }

    static func webviewLayers(in config: ConfigResponse) -> [WebviewContentBackgroundLayerDTO] {
        var result: [WebviewContentBackgroundLayerDTO] = []
        for inapp in config.inapps?.elements ?? [] {
            for variant in inapp.form.variants ?? [] {
                let layers: [ContentBackgroundLayerDTO]?
                switch variant {
                case .modal(let modal): layers = modal.content?.background?.layers
                case .snackbar(let snackbar): layers = snackbar.content?.background?.layers
                case .unknown: layers = nil
                }
                for layer in layers ?? [] {
                    if case .webview(let webview) = layer {
                        result.append(webview)
                    }
                }
            }
        }
        return result
    }

    /// JS evaluated in a shown WebView to collect the distinct https hosts its resources
    /// actually came from. Host names only — no URLs, no payloads; blob:/data:/non-https
    /// entries are dropped so they can't occupy learned-hosts slots.
    static let observedHostsScript = """
    Array.from(new Set(performance.getEntriesByType('resource').map(function (r) {
      try { var u = new URL(r.name); return u.protocol === 'https:' ? u.host : null } catch (e) { return null }
    }).filter(Boolean)))
    """
}

// MARK: - Learned hosts store

/// Persists resource hosts observed during real shows, per endpoint. These are the hosts the
/// config cannot know (image CDNs, the web runtime's static hosts, font providers), and they
/// make the next launch's preconnect cover the heavy part of the page. A stale entry is
/// harmless — preconnect to an unused host is a no-op.
final class InAppWebViewLearnedHostsStore {
    static let maxHosts = 12
    private static let keyPrefix = "MBInAppWebViewLearnedHosts."

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func hosts(endpoint: String) -> [String] {
        defaults.stringArray(forKey: Self.keyPrefix + endpoint) ?? []
    }

    /// Appends newly observed hosts, keeping insertion order and dropping the oldest beyond
    /// the cap so a runaway page can't grow the preconnect list without bound.
    func remember(_ observed: [String], endpoint: String) {
        guard !observed.isEmpty else { return }
        var merged = hosts(endpoint: endpoint)
        for host in observed where !host.isEmpty && !merged.contains(host) {
            merged.append(host)
        }
        if merged.count > Self.maxHosts {
            merged.removeFirst(merged.count - Self.maxHosts)
        }
        defaults.set(merged, forKey: Self.keyPrefix + endpoint)
    }
}

// MARK: - Prewarm service

protocol InAppWebViewPrewarmServiceProtocol: AnyObject {
    /// Stage 1, at SDK initialization: spins up the WebKit web-content process with a blank
    /// page so the first show doesn't pay process startup (~0.5s cold).
    func prewarmProcess()

    /// Stage 2, when the in-app config has been parsed: if the config contains webview
    /// in-apps, loads a preconnect page (derived from the config + learned hosts) into the
    /// warm instance under the shows' cache partition. If it contains none, the stage-1
    /// instance is released — most host apps never show webview in-apps and must not pay
    /// for an idle web-content process.
    func prewarmConnections(for config: ConfigResponse)

    /// Hands the warm instance to a show. The reference is kept (borrow, not consume) so the
    /// same live instance serves subsequent shows too. Never returns an instance with a
    /// prewarm navigation still able to reach the show's delegate.
    func borrowWarmWebView() -> WKWebView?

    /// Called when a show is torn down: navigates the parked instance to a blank page so the
    /// closed in-app's JS (timers, polling) stops running hidden, while the live web-content
    /// process and pooled connections stay warm for the next show.
    func parkWarmWebView()

    /// Called by a show when its page is done: persists the observed resource hosts for the
    /// next launch's preconnect.
    func rememberObservedHosts(_ hosts: [String])
}

final class InAppWebViewPrewarmService: InAppWebViewPrewarmServiceProtocol {

    private let persistenceStorage: PersistenceStorage
    private let learnedHostsStore: InAppWebViewLearnedHostsStore
    private let makeWebView: () -> WKWebView

    // Main-thread confined (WKWebView requirement); all mutations below hop to main.
    // The borrowed/preconnect flags latch for the rest of the launch by design: after the
    // first borrow the pooled connections are warmer than any preconnect page could make
    // them, and re-running stage 2 would navigate a live show's webview.
    private var warmWebView: WKWebView?
    private var hasBeenBorrowed = false
    private var hasLoadedPreconnect = false

    init(persistenceStorage: PersistenceStorage,
         learnedHostsStore: InAppWebViewLearnedHostsStore = InAppWebViewLearnedHostsStore(),
         makeWebView: @escaping () -> WKWebView = InAppWebViewPrewarmService.makeDefaultWebView) {
        self.persistenceStorage = persistenceStorage
        self.learnedHostsStore = learnedHostsStore
        self.makeWebView = makeWebView
    }

    func prewarmProcess() {
        DispatchQueue.main.async {
            guard self.warmWebView == nil else { return }
            self.warmWebView = self.makeWebView()
            // Blank page, no baseURL: nothing is fetched, so the cache partition is
            // irrelevant here — this only starts the web-content process.
            self.warmWebView?.loadHTMLString(Self.blankPage, baseURL: nil)
            Logger.common(message: "[WebView] Prewarm: web-content process warm-up started",
                          level: .info, category: .webViewInAppMessages)
        }
    }

    func prewarmConnections(for config: ConfigResponse) {
        let layers = InAppWebViewPrewarmPlanner.webviewLayers(in: config)
        guard !layers.isEmpty else {
            releaseUnusedWarmWebView()
            return
        }

        guard let configuration = persistenceStorage.configuration else { return }
        guard let baseURL = InAppWebViewPrewarmPlanner.partitionBaseURL(for: layers) else {
            Logger.common(message: "[WebView] Prewarm: webview layers carry no usable baseUrl — skipping preconnect",
                          level: .info, category: .webViewInAppMessages)
            return
        }

        let hosts = InAppWebViewPrewarmPlanner.preconnectHosts(
            layers: layers,
            apiDomain: configuration.domain,
            learnedHosts: learnedHostsStore.hosts(endpoint: configuration.endpoint)
        )
        guard !hosts.isEmpty else { return }

        DispatchQueue.main.async {
            // Config arrival and the first show race on the main queue: never navigate an
            // instance a show has borrowed, and load the preconnect page at most once —
            // after a real show the pooled connections are warmer than any preconnect.
            guard !self.hasBeenBorrowed, !self.hasLoadedPreconnect else { return }
            self.hasLoadedPreconnect = true
            if self.warmWebView == nil {
                self.warmWebView = self.makeWebView()
            }
            self.warmWebView?.loadHTMLString(InAppWebViewPrewarmPlanner.preconnectHTML(hosts: hosts), baseURL: baseURL)
            Logger.common(message: "[WebView] Prewarm: preconnect to \(hosts.joined(separator: ",")) under \(baseURL.absoluteString)",
                          level: .info, category: .webViewInAppMessages)
        }
    }

    func borrowWarmWebView() -> WKWebView? {
        assert(Thread.isMainThread, "borrowWarmWebView() must be called on the main thread")
        guard let webView = warmWebView else { return nil }
        hasBeenBorrowed = true
        // The instance belongs to the show from here. stopLoading() kills an in-flight
        // prewarm navigation; the blank load tears down an already-loaded prewarm page —
        // its JS (in-flight fetches, timers) must not compete with the show for bandwidth.
        // The show's own load supersedes the blank one, and the bridge's staleness filter
        // ignores both leftovers' callbacks.
        webView.stopLoading()
        webView.loadHTMLString(Self.blankPage, baseURL: nil)
        webView.removeFromSuperview()
        return webView
    }

    func parkWarmWebView() {
        DispatchQueue.main.async {
            // Only park an instance no live show is presenting. Late navigation callbacks
            // from this blank load are ignored by the next show's bridge (staleness filter).
            guard let webView = self.warmWebView, webView.superview == nil else { return }
            webView.loadHTMLString(Self.blankPage, baseURL: nil)
        }
    }

    func rememberObservedHosts(_ hosts: [String]) {
        guard let configuration = persistenceStorage.configuration else { return }
        learnedHostsStore.remember(hosts, endpoint: configuration.endpoint)
    }

    /// Most Mindbox host apps have no webview in-apps: once the config proves that, drop the
    /// stage-1 instance so they don't keep an idle web-content process for the app lifetime.
    /// A later config with webview layers recreates it (or the show creates its own on the
    /// same shared store).
    private func releaseUnusedWarmWebView() {
        DispatchQueue.main.async {
            guard !self.hasBeenBorrowed, !self.hasLoadedPreconnect, self.warmWebView != nil else { return }
            self.warmWebView = nil
            Logger.common(message: "[WebView] Prewarm: no webview in-apps in config — releasing the warm instance",
                          level: .info, category: .webViewInAppMessages)
        }
    }

    private static let blankPage = "<html><head><meta charset=\"utf-8\"></head><body></body></html>"

    private static func makeDefaultWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = InAppWebViewDataStore.shared()
        config.applicationNameForUserAgent = InAppWebViewUserAgent.build()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        return WKWebView(frame: .zero, configuration: config)
    }
}
