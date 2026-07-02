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
@testable import Mindbox

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

    // MARK: Partition baseURL

    @Test("Partition baseURL is taken from the first layer carrying a valid baseUrl")
    func partitionBaseURLPicksFirstValid() throws {
        let layers = [
            webviewLayer(baseUrl: nil),
            webviewLayer(baseUrl: "https://inapp.local/popup"),
            webviewLayer(baseUrl: "https://other.example/popup")
        ]
        let url = try #require(InAppWebViewPrewarmPlanner.partitionBaseURL(for: layers))
        #expect(url.absoluteString == "https://inapp.local/popup")
    }

    @Test("No layer with a usable baseUrl yields no partition URL", arguments: [
        [] as [String?],
        [nil],
        [""]
    ])
    func partitionBaseURLMissing(baseUrls: [String?]) {
        let layers = baseUrls.map { webviewLayer(baseUrl: $0) }
        #expect(InAppWebViewPrewarmPlanner.partitionBaseURL(for: layers) == nil)
    }

    @Test("Host-less baseUrls and layers without contentUrl don't donate a partition URL")
    func partitionBaseURLRequiresHostAndContent() throws {
        let hostless = webviewLayer(baseUrl: "popup")
        let noContent = webviewLayer(contentUrl: nil)
        let valid = webviewLayer()

        let url = try #require(InAppWebViewPrewarmPlanner.partitionBaseURL(for: [hostless, noContent, valid]))
        #expect(url.host == "inapp.local")
        #expect(InAppWebViewPrewarmPlanner.partitionBaseURL(for: [hostless, noContent]) == nil)
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

    // MARK: Config extraction (end to end on a real parsed config)

    @Test("Webview layers and prewarm inputs are extracted from a parsed config")
    func extractsLayersFromParsedConfig() throws {
        let config = try loadPrewarmTestConfig("InAppWebviewValid")
        let layers = InAppWebViewPrewarmPlanner.webviewLayers(in: config)
        #expect(!layers.isEmpty)

        let baseURL = try #require(InAppWebViewPrewarmPlanner.partitionBaseURL(for: layers))
        #expect(baseURL.host == "inapp.local")

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

    @Test("Process warm-up creates the instance once")
    func processWarmUpIsIdempotent() async {
        service.prewarmProcess()
        service.prewarmProcess()
        await drainMainQueue()

        #expect(spy.loadedHTMLCount == 1)
    }

    @Test("A cached config with webview in-apps starts the resource prewarm at init")
    func headStartRunsFromCachedConfig() async throws {
        let suite = try Self.init(cachedConfig: loadPrewarmTestConfig("InAppWebviewValid"))

        suite.service.prewarmProcess()

        // blank + preconnect + content page
        try await suite.waitUntil(suite.spy.loadedHTMLCount == 3)
    }

    @Test("Borrow stops in-flight loading, tears the prewarm page down, and keeps the instance")
    func borrowStopsLoadingAndKeepsInstance() async {
        service.prewarmProcess()
        await drainMainQueue()

        let borrowed = service.borrowWarmWebView()

        #expect(borrowed === spy)
        #expect(spy.stopLoadingCount == 1)
        #expect(spy.loadedHTMLCount == 2) // stage-1 blank + the hard-kill blank at borrow
        #expect(service.borrowWarmWebView() === spy)
    }

    @Test("Resource prewarm never navigates a borrowed instance")
    func resourcePrewarmSkippedAfterBorrow() async throws {
        service.prewarmProcess()
        await drainMainQueue()
        _ = service.borrowWarmWebView()

        service.prewarmResources(for: try loadPrewarmTestConfig("InAppWebviewValid"))
        await drainMainQueue()
        await drainMainQueue()

        #expect(spy.loadedHTMLCount == 2) // stage-1 blank + borrow hard-kill; nothing more
    }

    @Test("Resource prewarm runs once: preconnect page, then the content page with the stub bridge")
    func resourcePrewarmRunsOnce() async throws {
        service.prewarmProcess()
        await drainMainQueue()

        let config = try loadPrewarmTestConfig("InAppWebviewValid")
        service.prewarmResources(for: config)
        service.prewarmResources(for: config)
        await drainMainQueue()
        await drainMainQueue()

        #expect(spy.loadedHTMLCount == 3) // blank + one preconnect + one content page

        // Both prewarm pages live under the shows' cache partition from the config.
        let contentBaseURL = try #require(spy.loadedBaseURLs.last ?? nil)
        #expect(contentBaseURL.host == "inapp.local")

        // The content page got the Android-style sync-bridge stub with our identifiers.
        let stub = spy.configuration.userContentController.userScripts.first { $0.source.contains("SdkBridge") }
        let stubSource = try #require(stub?.source)
        #expect(stubSource.contains("Test.Endpoint"))
        #expect(stubSource.contains("test-device-uuid"))
    }

    @Test("A config without webview in-apps releases the unused warm instance")
    func noWebviewConfigReleasesInstance() async {
        service.prewarmProcess()
        await drainMainQueue()

        service.prewarmResources(for: ConfigResponse())
        await drainMainQueue()

        #expect(service.borrowWarmWebView() == nil)
    }

    @Test("Parking an idle borrowed instance loads a blank page to stop hidden JS")
    func parkingLoadsBlankPage() async {
        service.prewarmProcess()
        await drainMainQueue()
        _ = service.borrowWarmWebView()

        service.parkWarmWebView()
        await drainMainQueue()

        #expect(spy.loadedHTMLCount == 3) // stage-1 blank + borrow hard-kill + park blank
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
