//
//  InAppWebViewPrewarmTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 02.07.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import Testing
import WebKit
@_spi(Internal) @testable import Mindbox

private func loadPrewarmTestConfig(_ name: String) throws -> ConfigResponse {
    let bundle = Bundle(for: MindboxTests.self)
    let url = try #require(bundle.url(forResource: name, withExtension: "json"))
    return try JSONDecoder().decode(ConfigResponse.self, from: Data(contentsOf: url))
}

@Suite("InApp WebView prewarm planning", .tags(.webView))
struct InAppWebViewPrewarmPlannerTests {

    private func webviewLayer(
        baseUrl: String? = "https://inapp.local/popup",
        contentUrl: String? = "https://mobile-static.mindbox.ru/stable/inapps/webview/content/index.html"
    ) -> WebviewContentBackgroundLayerDTO {
        WebviewContentBackgroundLayerDTO(baseUrl: baseUrl, contentUrl: contentUrl, params: nil)
    }

    // MARK: Prewarm source (partition baseURL + contentURL from one layer)

    @Test("Prewarm source is taken from the first fully showable layer")
    func prewarmSourcePicksFirstValid() throws {
        let layers = [
            webviewLayer(baseUrl: nil),
            webviewLayer(baseUrl: "https://inapp.local/popup"),
            webviewLayer(baseUrl: "https://other.example/popup")
        ]
        let source = try #require(InAppWebViewPrewarmPlanner.prewarmSource(for: layers))
        #expect(source.baseURL.absoluteString == "https://inapp.local/popup")
    }

    @Test("No layer with a usable baseUrl yields no prewarm source", arguments: [
        [] as [String?],
        [nil],
        [""]
    ])
    func prewarmSourceMissing(baseUrls: [String?]) {
        let layers = baseUrls.map { webviewLayer(baseUrl: $0) }
        #expect(InAppWebViewPrewarmPlanner.prewarmSource(for: layers) == nil)
    }

    @Test("Host-less baseUrls and layers without contentUrl don't donate a prewarm source")
    func prewarmSourceRequiresHostAndContent() throws {
        let hostless = webviewLayer(baseUrl: "popup")
        let noContent = webviewLayer(contentUrl: nil)
        let valid = webviewLayer()

        let source = try #require(InAppWebViewPrewarmPlanner.prewarmSource(for: [hostless, noContent, valid]))
        #expect(source.baseURL.host == "inapp.local")
        #expect(InAppWebViewPrewarmPlanner.prewarmSource(for: [hostless, noContent]) == nil)
    }

    @Test("Base and content URLs always come from the same layer — never mixed across layers")
    func prewarmSourceNeverMixesLayers() throws {
        // Layer A: valid contentUrl but broken baseUrl; layer B: both valid. Mixing would
        // warm A's content under B's cache partition — invisible to A's real show.
        let broken = webviewLayer(baseUrl: "not a url", contentUrl: "https://cdn.a/index.html")
        let valid = webviewLayer(baseUrl: "https://inapp.local/popup", contentUrl: "https://cdn.b/index.html")

        let source = try #require(InAppWebViewPrewarmPlanner.prewarmSource(for: [broken, valid]))
        #expect(source.baseURL.host == "inapp.local")
        #expect(source.contentURL.absoluteString == "https://cdn.b/index.html")
    }

    // MARK: Preconnect hosts

    @Test("Hosts are deduplicated, merged with API domain and learned hosts, and sorted")
    func preconnectHostsMergesAllSources() {
        let layers = [
            webviewLayer(contentUrl: "https://mobile-static.mindbox.ru/a/index.html"),
            webviewLayer(contentUrl: "https://mobile-static.mindbox.ru/b/index.html")
        ]
        let hosts = InAppWebViewPrewarmPlanner.preconnectHosts(
            layers: layers,
            apiDomain: "api.mindbox.ru",
            learnedHosts: ["web-static.mindbox.ru", "api.mindbox.ru"]
        )
        #expect(hosts == ["api.mindbox.ru", "mobile-static.mindbox.ru", "web-static.mindbox.ru"])
    }

    @Test("Invalid content URLs and an absent API domain contribute nothing")
    func preconnectHostsSkipsUnusableSources() {
        let layers = [webviewLayer(contentUrl: nil), webviewLayer(contentUrl: "")]
        let hosts = InAppWebViewPrewarmPlanner.preconnectHosts(layers: layers, apiDomain: nil, learnedHosts: [])
        #expect(hosts.isEmpty)

        let emptyDomain = InAppWebViewPrewarmPlanner.preconnectHosts(layers: layers, apiDomain: "", learnedHosts: [])
        #expect(emptyDomain.isEmpty)
    }

    // MARK: Preconnect page

    @Test("Preconnect page hints every host and downloads nothing")
    func preconnectHTMLContainsHints() {
        let html = InAppWebViewPrewarmPlanner.preconnectHTML(hosts: ["a.example", "b.example"])
        #expect(html.contains("<link rel=\"preconnect\" href=\"https://a.example\" crossorigin>"))
        #expect(html.contains("<link rel=\"dns-prefetch\" href=\"https://b.example\">"))
        #expect(!html.contains("<script"))
        #expect(!html.contains("<img"))
    }

    // MARK: Prewarm content baseURL (official web prewarm contract)

    @Test("Prewarm content baseURL carries the official prewarm query parameters")
    func prewarmContentBaseURLAppendsContract() throws {
        let baseURL = try #require(URL(string: "https://inapp.local/popup"))

        let url = InAppWebViewPrewarmPlanner.prewarmContentBaseURL(
            from: baseURL, endpoint: "Mpush-test.WebView", deviceUUID: "abc-123"
        )

        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.host == "inapp.local")
        #expect(components.path == "/popup")
        let query = try #require(components.queryItems)
        #expect(query.contains(URLQueryItem(name: "prewarm", value: "1")))
        #expect(query.contains(URLQueryItem(name: "endpointId", value: "Mpush-test.WebView")))
        #expect(query.contains(URLQueryItem(name: "deviceUuid", value: "abc-123")))
    }

    @Test("Existing baseURL query survives and unsafe values are percent-encoded")
    func prewarmContentBaseURLKeepsQueryAndEncodes() throws {
        let baseURL = try #require(URL(string: "https://inapp.local/popup?keep=me"))

        let url = InAppWebViewPrewarmPlanner.prewarmContentBaseURL(
            from: baseURL, endpoint: "End point&x", deviceUUID: "uuid"
        )

        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let query = try #require(components.queryItems)
        #expect(query.contains(URLQueryItem(name: "keep", value: "me")))
        // URLComponents decodes on read; the raw string must not leak a bare '&' into the query.
        #expect(query.contains(URLQueryItem(name: "endpointId", value: "End point&x")))
        #expect(url.absoluteString.contains("endpointId=End%20point%26x"))
    }

    // MARK: Config extraction (end to end on a real parsed config)

    @Test("Webview layers and prewarm inputs are extracted from a parsed config")
    func extractsLayersFromParsedConfig() throws {
        let config = try loadPrewarmTestConfig("InAppWebviewValid")
        let layers = InAppWebViewPrewarmPlanner.webviewLayers(in: config)
        #expect(!layers.isEmpty)

        let source = try #require(InAppWebViewPrewarmPlanner.prewarmSource(for: layers))
        #expect(source.baseURL.host == "inapp.local")

        let hosts = InAppWebViewPrewarmPlanner.preconnectHosts(layers: layers, apiDomain: "api.mindbox.ru", learnedHosts: [])
        let contentUrl = try #require(layers.first?.contentUrl)
        let contentHost = try #require(URL(string: contentUrl)?.host)
        #expect(hosts.contains("api.mindbox.ru"))
        #expect(hosts.contains(contentHost))
    }

    @Test("Configs without webview layers plan nothing", arguments: [
        "InAppLayerUnknownType",
        "InAppFormVariantUnknownType"
    ])
    func noWebviewLayersInNonWebviewConfig(fixture: String) throws {
        let config = try loadPrewarmTestConfig(fixture)
        #expect(InAppWebViewPrewarmPlanner.webviewLayers(in: config).isEmpty)
    }
}

@MainActor
@Suite("InApp WebView prewarm service guards", .tags(.webView))
struct InAppWebViewPrewarmServiceGuardTests {

    private final class SpyWebView: WKWebView {
        private(set) var loadedHTMLCount = 0
        private(set) var loadedBaseURLs: [URL?] = []
        private(set) var stopLoadingCount = 0
        var stubbedIsLoading = false

        override var isLoading: Bool { stubbedIsLoading }

        override func loadHTMLString(_ string: String, baseURL: URL?) -> WKNavigation? {
            loadedHTMLCount += 1
            loadedBaseURLs.append(baseURL)
            return nil // spy only — keep WebKit from actually navigating in unit tests
        }

        override func stopLoading() {
            stopLoadingCount += 1
        }
    }

    private let spy: SpyWebView
    private let service: InAppWebViewPrewarmService

    init() throws {
        self = try Self.init(cachedConfig: nil)
    }

    private init(cachedConfig: ConfigResponse?) throws {
        let spy = SpyWebView(frame: .zero, configuration: WKWebViewConfiguration())
        self.spy = spy

        let storage = MockPersistenceStorage()
        storage.configuration = try MBConfiguration(endpoint: "Test.Endpoint", domain: "api.mindbox.ru")
        storage.deviceUUID = "test-device-uuid"
        let defaults = try #require(UserDefaults(suiteName: "PrewarmGuardTests-\(UUID().uuidString)"))

        service = InAppWebViewPrewarmService(
            persistenceStorage: storage,
            learnedHostsStore: InAppWebViewLearnedHostsStore(defaults: defaults),
            makeWebView: { spy },
            fetchHTML: { _, completion in completion("<html><body>content</body></html>") },
            loadCachedConfig: { cachedConfig }
        )
    }

    /// The service hops its mutations through `DispatchQueue.main.async`; one more hop
    /// behind them guarantees they have run.
    private func drainMainQueue() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async { continuation.resume() }
        }
    }

    /// The cached-config head start hops through a background queue first — poll for its
    /// main-queue effects instead of assuming scheduling order.
    private func waitUntil(_ condition: @autoclosure () -> Bool) async throws {
        for _ in 0..<100 where !condition() {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        #expect(condition())
    }

    @Test("Without a cached webview config nothing is created at init")
    func initWithoutCachedConfigCreatesNothing() async {
        service.prewarmProcess()
        service.prewarmProcess()
        await drainMainQueue()
        await drainMainQueue()

        // Hosts that don't use webview in-apps must never pay for a web-content process.
        #expect(spy.loadedHTMLCount == 0)
        #expect(service.borrowWarmWebView() == nil)
    }

    @Test("A cached config with webview in-apps starts the resource prewarm at init")
    func headStartRunsFromCachedConfig() async throws {
        let suite = try Self.init(cachedConfig: loadPrewarmTestConfig("InAppWebviewValid"))

        suite.service.prewarmProcess()

        // preconnect + content page (the instance is created lazily by the prewarm itself)
        try await suite.waitUntil(suite.spy.loadedHTMLCount == 2)
    }

    @Test("Borrow stops in-flight loading, tears the prewarm page down, and keeps the instance")
    func borrowStopsLoadingAndKeepsInstance() async throws {
        let suite = try Self.init(cachedConfig: loadPrewarmTestConfig("InAppWebviewValid"))
        suite.service.prewarmProcess()
        try await suite.waitUntil(suite.spy.loadedHTMLCount == 2)

        let borrowed = suite.service.borrowWarmWebView()

        #expect(borrowed === suite.spy)
        #expect(suite.spy.stopLoadingCount == 1)
        #expect(suite.spy.loadedHTMLCount == 3) // preconnect + content + the hard-kill blank at borrow

        // While lent to a live show the instance must never be stolen by a second borrow —
        // presentation is serialized upstream, but that flag has known races.
        #expect(suite.service.borrowWarmWebView() == nil)

        // After the show parks it, the same instance serves the next show.
        suite.service.parkWarmWebView()
        await suite.drainMainQueue()
        #expect(suite.service.borrowWarmWebView() === suite.spy)
    }

    @Test("Borrow refuses an instance whose prewarm navigation hasn't settled and parks it for the next show")
    func borrowRefusesMidNavigationInstance() async throws {
        let suite = try Self.init(cachedConfig: loadPrewarmTestConfig("InAppWebviewValid"))
        suite.service.prewarmProcess()
        try await suite.waitUntil(suite.spy.loadedHTMLCount == 2)
        suite.spy.stubbedIsLoading = true

        // A mid-navigation document must never reach a show: its didFinish can fire before
        // module scripts evaluate and the ready check would close a healthy in-app.
        #expect(suite.service.borrowWarmWebView() == nil)
        // The prewarm page is still torn down so it can't compete with the show's bandwidth.
        #expect(suite.spy.stopLoadingCount == 1)
        #expect(suite.spy.loadedHTMLCount == 3) // head start (2) + park blank

        // Once the parked blank settles, the same instance serves the next show.
        suite.spy.stubbedIsLoading = false
        #expect(suite.service.borrowWarmWebView() === suite.spy)
    }

    @Test("Resource prewarm never navigates a borrowed instance")
    func resourcePrewarmSkippedAfterBorrow() async throws {
        let suite = try Self.init(cachedConfig: loadPrewarmTestConfig("InAppWebviewValid"))
        suite.service.prewarmProcess()
        try await suite.waitUntil(suite.spy.loadedHTMLCount == 2)
        _ = suite.service.borrowWarmWebView()

        suite.service.prewarmResources(for: try loadPrewarmTestConfig("InAppWebviewValid"))
        await suite.drainMainQueue()
        await suite.drainMainQueue()

        #expect(suite.spy.loadedHTMLCount == 3) // head start + borrow hard-kill; nothing more
    }

    @Test("A show starting before any prewarm blocks later resource prewarms")
    func showBeforePrewarmBlocksLaterPrewarm() async throws {
        #expect(service.borrowWarmWebView() == nil)

        service.prewarmResources(for: try loadPrewarmTestConfig("InAppWebviewValid"))
        await drainMainQueue()
        await drainMainQueue()

        // The show already owns the network; a late prewarm must not compete with it.
        #expect(spy.loadedHTMLCount == 0)
    }

    @Test("Resource prewarm runs once: preconnect page, then the content page with the prewarm params")
    func resourcePrewarmRunsOnce() async throws {
        let config = try loadPrewarmTestConfig("InAppWebviewValid")
        service.prewarmResources(for: config)
        service.prewarmResources(for: config)
        await drainMainQueue()
        await drainMainQueue()

        #expect(spy.loadedHTMLCount == 2) // one preconnect + one content page

        // Both prewarm pages live under the shows' cache partition from the config,
        // and the content page carries the official prewarm contract parameters.
        let contentBaseURL = try #require(spy.loadedBaseURLs.last ?? nil)
        #expect(contentBaseURL.host == "inapp.local")
        let query = try #require(URLComponents(url: contentBaseURL, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(query.contains(URLQueryItem(name: "prewarm", value: "1")))
        #expect(query.contains(URLQueryItem(name: "endpointId", value: "Test.Endpoint")))
        #expect(query.contains(URLQueryItem(name: "deviceUuid", value: "test-device-uuid")))

        // The prewarm injects nothing into the page: user scripts persist across
        // navigations and would leak into the borrowed instance's shows.
        #expect(spy.configuration.userContentController.userScripts.isEmpty)
    }

    @Test("A config without webview in-apps releases the unused warm instance")
    func noWebviewConfigReleasesInstance() async throws {
        let suite = try Self.init(cachedConfig: loadPrewarmTestConfig("InAppWebviewValid"))
        suite.service.prewarmProcess()
        try await suite.waitUntil(suite.spy.loadedHTMLCount == 2)

        suite.service.prewarmResources(for: ConfigResponse())
        await suite.drainMainQueue()

        // Symmetric with the memory-warning path: an in-flight prewarm navigation must
        // not keep burning bandwidth if anything briefly retains the dropped instance.
        #expect(suite.spy.stopLoadingCount == 1)
        #expect(suite.service.borrowWarmWebView() == nil)
    }

    @Test("The prewarm instance is pinned by the navigation policy until a show takes over")
    func prewarmArmsNavigationPolicy() async throws {
        let suite = try Self.init(cachedConfig: loadPrewarmTestConfig("InAppWebviewValid"))
        suite.service.prewarmProcess()
        try await suite.waitUntil(suite.spy.loadedHTMLCount == 2)

        // Hidden instance: page-initiated navigation must be refused by policy (the show
        // path installs its own delegate — the bridge — at borrow).
        #expect(suite.spy.navigationDelegate is InAppWebViewPrewarmNavigationPolicy)
    }

    @Test("Parking an idle borrowed instance loads a blank page to stop hidden JS")
    func parkingLoadsBlankPage() async throws {
        let suite = try Self.init(cachedConfig: loadPrewarmTestConfig("InAppWebviewValid"))
        suite.service.prewarmProcess()
        try await suite.waitUntil(suite.spy.loadedHTMLCount == 2)
        _ = suite.service.borrowWarmWebView()

        suite.service.parkWarmWebView()
        await suite.drainMainQueue()

        #expect(suite.spy.loadedHTMLCount == 4) // head start (2) + borrow hard-kill + park blank
    }

    @Test("A memory warning frees the parked instance; the disk cache keeps the prewarm benefit")
    func memoryWarningFreesParkedInstance() async throws {
        let suite = try Self.init(cachedConfig: loadPrewarmTestConfig("InAppWebviewValid"))
        suite.service.prewarmProcess()
        try await suite.waitUntil(suite.spy.loadedHTMLCount == 2)

        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        await suite.drainMainQueue()

        #expect(suite.spy.stopLoadingCount == 1)
        // The next show creates its own WKWebView on the shared store instead.
        #expect(suite.service.borrowWarmWebView() == nil)
    }

    @Test("A memory warning never touches an instance lent to a live show")
    func memoryWarningSparesLentInstance() async throws {
        let suite = try Self.init(cachedConfig: loadPrewarmTestConfig("InAppWebviewValid"))
        suite.service.prewarmProcess()
        try await suite.waitUntil(suite.spy.loadedHTMLCount == 2)
        _ = suite.service.borrowWarmWebView()

        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        await suite.drainMainQueue()

        // Still owned by the show and still reusable after it closes.
        suite.service.parkWarmWebView()
        await suite.drainMainQueue()
        #expect(suite.service.borrowWarmWebView() === suite.spy)
    }
}

/// A hidden prewarm WebView must never be able to wander off: without a delegate, a
/// page-initiated redirect could keep the instance fetching arbitrary URLs under the
/// shows' cache partition for the whole app lifetime.
@Suite("InApp WebView prewarm navigation policy", .tags(.webView))
@MainActor
struct InAppWebViewPrewarmNavigationPolicyTests {

    private let policy = InAppWebViewPrewarmNavigationPolicy()

    @Test("SDK-issued documents are allowed; anything else on the main frame is cancelled")
    func pinsMainFrameToIssuedDocuments() throws {
        let issued = try #require(URL(string: "https://inapp.local/popup?prewarm=1"))
        policy.allow(issued)

        #expect(policy.decision(for: issued, targetIsMainFrame: true) == .allow)
        #expect(policy.decision(for: URL(string: "https://evil.example/landing"), targetIsMainFrame: true) == .cancel)
        // The park/borrow blank load is always ours.
        #expect(policy.decision(for: URL(string: "about:blank"), targetIsMainFrame: true) == .allow)
    }

    @Test("Subframes stay the page's own business; a nil target frame (window.open) is pinned")
    func subframesAllowedNilTargetPinned() {
        #expect(policy.decision(for: URL(string: "https://ads.example/frame"), targetIsMainFrame: false) == .allow)
        #expect(policy.decision(for: URL(string: "https://popup.example/win"), targetIsMainFrame: nil) == .cancel)
    }
}

/// The staleness filter is the confirmed first-show-race fix: a reused (pre-warmed)
/// WebView delivers navigation callbacks from previous owners' loads, and the ready check
/// closes the in-app on the first didFinish it sees — leftovers must never reach the
/// show's delegate.
@Suite("MindboxWebBridge navigation staleness", .tags(.webView))
@MainActor
struct MindboxWebBridgeStalenessTests {

    private final class DelegateSpy: WebBridgeNavigationDelegate {
        private(set) var startCount = 0
        private(set) var finishCount = 0
        private(set) var failCount = 0
        private(set) var finishURLs: [URL?] = []

        func webBridge(_ bridge: MindboxWebBridge, didStartProvisionalNavigation url: URL?) { startCount += 1 }
        func webBridge(_ bridge: MindboxWebBridge, didFinishNavigation url: URL?) {
            finishCount += 1
            finishURLs.append(url)
        }
        func webBridge(_ bridge: MindboxWebBridge, didFailProvisionalNavigation url: URL?, error: Error) { failCount += 1 }
        func webBridge(_ bridge: MindboxWebBridge, decidePolicyFor url: URL?, navigationType: WKNavigationType,
                       decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }
    }

    private let webView: WKWebView
    private let bridge: MindboxWebBridge
    private let spy: DelegateSpy
    // Source of REAL, distinct WKNavigation objects (unsafe casts of NSObject trap in
    // debug). Separate from `webView` so its loads' async delegate callbacks can never
    // pollute the spy's counters.
    private let navigationFactory = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())

    init() {
        webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        bridge = MindboxWebBridge(webView: webView)
        spy = DelegateSpy()
        bridge.navigationDelegate = spy
    }

    private func makeNavigation() -> WKNavigation {
        // swiftlint:disable:next force_unwrapping
        navigationFactory.loadHTMLString("<html></html>", baseURL: nil)!
    }

    @Test("Before the show's own load every navigation callback is stale")
    func everythingIsStaleBeforeContentLoad() {
        // A leftover prewarm/blank navigation finishing right after the bridge attaches.
        bridge.webView(webView, didStartProvisionalNavigation: makeNavigation())
        bridge.webView(webView, didFinish: makeNavigation())

        #expect(spy.startCount == 0)
        #expect(spy.finishCount == 0)
    }

    @Test("Only the expected navigation's callbacks reach the delegate; strangers are filtered")
    func strangerNavigationsAreFiltered() {
        let expected = makeNavigation()
        bridge.expectContentNavigation(expected)

        let stranger = makeNavigation()
        bridge.webView(webView, didStartProvisionalNavigation: stranger)
        bridge.webView(webView, didFinish: stranger)
        #expect(spy.startCount == 0)
        #expect(spy.finishCount == 0)

        bridge.webView(webView, didStartProvisionalNavigation: expected)
        bridge.webView(webView, didFinish: expected)
        #expect(spy.startCount == 1)
        #expect(spy.finishCount == 1)
    }

    @Test("After the expected navigation finished the filter opens for page-initiated navigations")
    func filterOpensAfterExpectedFinish() {
        let expected = makeNavigation()
        bridge.expectContentNavigation(expected)
        bridge.webView(webView, didFinish: expected)
        #expect(spy.finishCount == 1)

        // e.g. an in-page reload / SPA navigation initiated by the shown page itself.
        bridge.webView(webView, didFinish: makeNavigation())
        #expect(spy.finishCount == 2)
    }

    @Test("A nil expected navigation (loadHTMLString returned nil) fails open, not closed")
    func nilExpectedNavigationFailsOpen() {
        bridge.expectContentNavigation(nil)

        bridge.webView(webView, didFinish: makeNavigation())

        // Filtering everything here would strand the show (no didFinish → no ready check).
        #expect(spy.finishCount == 1)
    }

    @Test("Stale failure callbacks never close the show")
    func staleFailuresAreFiltered() {
        bridge.expectContentNavigation(makeNavigation())

        bridge.webView(webView, didFailProvisionalNavigation: makeNavigation(),
                       withError: NSError(domain: "test", code: 1))

        #expect(spy.failCount == 0)
    }

    @Test("A nil CALLBACK navigation fails open, mirroring the nil-expected case")
    func nilCallbackNavigationFailsOpen() {
        bridge.expectContentNavigation(makeNavigation())

        // WebKit occasionally delivers nil navigations (early provisional failures).
        // Treating them as stale would swallow a real failure and hang the show
        // invisibly until the init timeout.
        bridge.webView(webView, didFailProvisionalNavigation: nil, withError: NSError(domain: "test", code: 2))
        #expect(spy.failCount == 1)

        bridge.webView(webView, didFinish: nil)
        #expect(spy.finishCount == 1)
    }

    @Test("Only the show's own finish reports the content URL; page navigations report their real URL")
    func finishReportsPerNavigationURL() {
        let contentURL = URL(string: "https://content.mindbox.ru/index.html")
        bridge.updateContentURL(contentURL)
        let expected = makeNavigation()
        bridge.expectContentNavigation(expected)

        bridge.webView(webView, didFinish: expected)
        // A page-initiated navigation after the filter opened: its URL is the webView's
        // actual URL (nil on this unloaded test instance), NOT the content URL — otherwise
        // the ready-check dedupe would key two different documents to one string.
        bridge.webView(webView, didFinish: makeNavigation())

        #expect(spy.finishURLs.count == 2)
        #expect(spy.finishURLs.first == contentURL)
        #expect(spy.finishURLs.last == URL?.none)
    }
}

/// Navigations have the staleness filter; script MESSAGES need their own gate. Until the
/// show's own document commits, a reused WebView's previous document (e.g. a dying prewarm
/// page retrying its handshake) can still post to the freshly attached handler — answering
/// it could flash the prewarm page as a phantom presentation.
@Suite("MindboxWebBridge message gate", .tags(.webView))
@MainActor
struct MindboxWebBridgeMessageGateTests {

    private final class MessageSpy: WebBridgeMessageDelegate {
        private(set) var received: [BridgeMessage] = []
        func webBridge(_ bridge: MindboxWebBridge, didReceiveBridgeMessage message: BridgeMessage) {
            received.append(message)
        }
    }

    /// WKScriptMessage's real initializer is WebKit-internal; the bridge only reads
    /// `name` and `body`, so an override-based fake is a safe stand-in.
    private final class FakeScriptMessage: WKScriptMessage {
        private let fakeName: String
        private let fakeBody: Any

        init(name: String, body: Any) {
            self.fakeName = name
            self.fakeBody = body
            super.init()
        }

        override var name: String { fakeName }
        override var body: Any { fakeBody }
    }

    private let webView: WKWebView
    private let bridge: MindboxWebBridge
    private let spy: MessageSpy
    // Real, distinct WKNavigation objects; separate instance so its async delegate
    // callbacks can't reach the bridge under test.
    private let navigationFactory = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())

    init() {
        webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        bridge = MindboxWebBridge(webView: webView)
        spy = MessageSpy()
        bridge.messageDelegate = spy
    }

    private func makeNavigation() -> WKNavigation {
        // swiftlint:disable:next force_unwrapping
        navigationFactory.loadHTMLString("<html></html>", baseURL: nil)!
    }

    private func postValidMessage() throws {
        let message = try #require(BridgeMessage(type: .request, action: "log", payload: "hi"))
        let body = try #require(message.jsonString())
        bridge.userContentController(
            webView.configuration.userContentController,
            didReceive: FakeScriptMessage(name: Constants.WebViewBridgeJS.handlerName, body: body)
        )
    }

    @Test("Messages are dropped until the show's own navigation commits")
    func messagesGatedUntilExpectedCommit() throws {
        // Before any load is issued: whoever posts is not this show's page.
        try postValidMessage()
        #expect(spy.received.isEmpty)

        let expected = makeNavigation()
        bridge.expectContentNavigation(expected)

        // Load issued but the old document still owns the web process until commit.
        try postValidMessage()
        #expect(spy.received.isEmpty)

        // A stale (stranger) commit must not open the gate either.
        bridge.webView(webView, didCommit: makeNavigation())
        try postValidMessage()
        #expect(spy.received.isEmpty)

        // The expected commit swaps the document: messages are the show's from here.
        bridge.webView(webView, didCommit: expected)
        try postValidMessage()
        #expect(spy.received.count == 1)
    }

    @Test("A nil expected navigation opens the gate at the first commit (fail-open)")
    func nilExpectedNavigationGateOpensOnCommit() throws {
        bridge.expectContentNavigation(nil)

        try postValidMessage()
        #expect(spy.received.isEmpty)

        bridge.webView(webView, didCommit: makeNavigation())
        try postValidMessage()
        #expect(spy.received.count == 1)
    }
}

@Suite("InApp WebView learned hosts store", .tags(.webView))
struct InAppWebViewLearnedHostsStoreTests {

    private let defaults: UserDefaults
    private let suiteName: String

    init() throws {
        suiteName = "InAppWebViewLearnedHostsStoreTests-\(UUID().uuidString)"
        defaults = try #require(UserDefaults(suiteName: suiteName))
    }

    private func cleanUp() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test("Observed hosts merge in order without duplicates")
    func mergesWithoutDuplicates() {
        defer { cleanUp() }
        let store = InAppWebViewLearnedHostsStore(defaults: defaults)

        store.remember(["a.example", "b.example"], endpoint: "Endpoint")
        store.remember(["b.example", "c.example", ""], endpoint: "Endpoint")

        #expect(store.hosts(endpoint: "Endpoint") == ["a.example", "b.example", "c.example"])
    }

    @Test("The oldest hosts are dropped beyond the cap")
    func capsAtMaximumDroppingOldest() {
        defer { cleanUp() }
        let store = InAppWebViewLearnedHostsStore(defaults: defaults)
        let cap = InAppWebViewLearnedHostsStore.maxHosts

        store.remember((0..<cap).map { "host\($0).example" }, endpoint: "Endpoint")
        store.remember(["overflow.example"], endpoint: "Endpoint")

        let hosts = store.hosts(endpoint: "Endpoint")
        #expect(hosts.count == cap)
        #expect(hosts.first == "host1.example")
        #expect(hosts.last == "overflow.example")
    }

    @Test("Remembering nothing changes nothing")
    func emptyObservationIsNoOp() {
        defer { cleanUp() }
        let store = InAppWebViewLearnedHostsStore(defaults: defaults)

        store.remember([], endpoint: "Endpoint")

        #expect(store.hosts(endpoint: "Endpoint").isEmpty)
        #expect(defaults.object(forKey: "MBInAppWebViewLearnedHosts.Endpoint") == nil)
    }

    @Test("Page-controlled strings that are not bare hosts are rejected on write")
    func rejectsNonHostStrings() {
        defer { cleanUp() }
        let store = InAppWebViewLearnedHostsStore(defaults: defaults)

        // The values come from page JS and are later interpolated into preconnect HTML —
        // anything that doesn't round-trip as a bare https host must never be persisted.
        store.remember(
            [
                "cdn.ok.example",
                "x\"><script>alert(1)</script>",
                "bad host with spaces",
                "https://full.url/path",
                "host/with/path",
                "evil.example\"><link>",
                ""
            ],
            endpoint: "Endpoint"
        )

        #expect(store.hosts(endpoint: "Endpoint") == ["cdn.ok.example"])
    }

    @Test("Hosts are scoped per endpoint")
    func endpointsAreIsolated() {
        defer { cleanUp() }
        let store = InAppWebViewLearnedHostsStore(defaults: defaults)

        store.remember(["a.example"], endpoint: "First")
        store.remember(["b.example"], endpoint: "Second")

        #expect(store.hosts(endpoint: "First") == ["a.example"])
        #expect(store.hosts(endpoint: "Second") == ["b.example"])
    }
}
