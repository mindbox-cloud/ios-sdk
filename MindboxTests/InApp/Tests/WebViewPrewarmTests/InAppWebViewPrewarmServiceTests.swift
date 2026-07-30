//
//  InAppWebViewPrewarmServiceTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 06.07.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import Testing
import WebKit
@testable import Mindbox

@MainActor
@Suite("InApp WebView prewarm service guards", .tags(.webView))
struct InAppWebViewPrewarmServiceTests {

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

        service = InAppWebViewPrewarmService(
            persistenceStorage: storage,
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

    @Test("Resource prewarm runs once: preconnect page, then the content page with the prewarm params")
    func resourcePrewarmRunsOnce() async throws {
        let config = try loadPrewarmTestConfig("InAppWebviewValid")
        service.prewarmResources(for: config)
        service.prewarmResources(for: config)
        await drainMainQueue()
        await drainMainQueue()

        #expect(spy.loadedHTMLCount == 2) // one preconnect + one content page

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

    @Test("The prewarm instance is pinned by the navigation policy until a show takes over")
    func prewarmArmsNavigationPolicy() async throws {
        let suite = try Self.init(cachedConfig: loadPrewarmTestConfig("InAppWebviewValid"))
        suite.service.prewarmProcess()
        try await suite.waitUntil(suite.spy.loadedHTMLCount == 2)

        #expect(suite.spy.navigationDelegate is InAppWebViewPrewarmNavigationPolicy)
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

        // While lent to a live show the instance must never be stolen by a second borrow.
        #expect(suite.service.borrowWarmWebView() == nil)

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

        // A mid-navigation document must never reach a show: its didFinish can fire
        // before module scripts evaluate.
        #expect(suite.service.borrowWarmWebView() == nil)
        #expect(suite.spy.stopLoadingCount == 1)
        #expect(suite.spy.loadedHTMLCount == 3) // head start (2) + park blank

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

        #expect(spy.loadedHTMLCount == 0)
    }

    @Test("A config without webview in-apps releases the unused warm instance")
    func noWebviewConfigReleasesInstance() async throws {
        let suite = try Self.init(cachedConfig: loadPrewarmTestConfig("InAppWebviewValid"))
        suite.service.prewarmProcess()
        try await suite.waitUntil(suite.spy.loadedHTMLCount == 2)

        suite.service.prewarmResources(for: ConfigResponse())
        await suite.drainMainQueue()

        // An in-flight prewarm navigation must not keep burning bandwidth if anything
        // briefly retains the dropped instance.
        #expect(suite.spy.stopLoadingCount == 1)
        #expect(suite.service.borrowWarmWebView() == nil)
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

    @Test("An off-main borrow is refused without touching the warm instance")
    func offMainBorrowRefusedSafely() async throws {
        let suite = try Self.init(cachedConfig: loadPrewarmTestConfig("InAppWebviewValid"))
        suite.service.prewarmProcess()
        try await suite.waitUntil(suite.spy.loadedHTMLCount == 2)

        // Deliberate off-main access — exactly what the guard under test refuses.
        nonisolated(unsafe) let service = suite.service
        let refused = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            DispatchQueue.global().async {
                continuation.resume(returning: service.borrowWarmWebView() == nil)
            }
        }

        #expect(refused)
        // Main-confined state untouched: the instance still serves a main-thread borrow.
        #expect(suite.service.borrowWarmWebView() === suite.spy)
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

        suite.service.parkWarmWebView()
        await suite.drainMainQueue()
        #expect(suite.service.borrowWarmWebView() === suite.spy)
    }

    @Test("Observed hosts are persisted under the configuration endpoint")
    func rememberObservedHostsPersistsUnderEndpoint() throws {
        let storage = MockPersistenceStorage()
        storage.configuration = try MBConfiguration(endpoint: "Test.Endpoint", domain: "api.mindbox.ru")
        let service = InAppWebViewPrewarmService(
            persistenceStorage: storage,
            makeWebView: { SpyWebView(frame: .zero, configuration: WKWebViewConfiguration()) },
            fetchHTML: { _, completion in completion(nil) },
            loadCachedConfig: { nil }
        )

        service.rememberObservedHosts(["a.example", "b.example"])

        #expect(storage.webViewLearnedHosts?["Test.Endpoint"] == ["a.example", "b.example"])
    }

    @Test("A content-page fetch failure degrades to preconnect-only")
    func contentFetchFailureLeavesPreconnectOnly() async throws {
        let storage = MockPersistenceStorage()
        storage.configuration = try MBConfiguration(endpoint: "Test.Endpoint", domain: "api.mindbox.ru")
        let spy = SpyWebView(frame: .zero, configuration: WKWebViewConfiguration())
        let service = InAppWebViewPrewarmService(
            persistenceStorage: storage,
            makeWebView: { spy },
            fetchHTML: { _, completion in completion(nil) },
            loadCachedConfig: { nil }
        )

        service.prewarmResources(for: try loadPrewarmTestConfig("InAppWebviewValid"))
        await drainMainQueue()
        await drainMainQueue()

        // Preconnect page loaded; the failed content fetch adds nothing.
        #expect(spy.loadedHTMLCount == 1)
    }

    // MARK: Feature toggle

    /// The valid webview config with an explicit `featureToggles` section.
    private static func config(prewarmToggle: Bool?) throws -> ConfigResponse {
        let base = try loadPrewarmTestConfig("InAppWebviewValid")
        let toggles = Settings.FeatureToggles(
            shouldSendInAppShowError: nil,
            shouldSendInAppTags: nil,
            shouldPrewarmInAppWebView: prewarmToggle,
            shouldCacheInAppWebView: nil
        )
        let settings = Settings(
            operations: nil, ttl: nil, slidingExpiration: nil,
            inapp: nil, featureToggles: toggles, baseAddresses: nil
        )
        return ConfigResponse(inapps: base.inapps, settings: settings)
    }

    @Test("Prewarm toggle off in the cached config skips the head start")
    func prewarmToggleOffSkipsHeadStart() async throws {
        let suite = try Self.init(cachedConfig: Self.config(prewarmToggle: false))

        suite.service.prewarmProcess()
        try await Task.sleep(nanoseconds: 100_000_000)
        await suite.drainMainQueue()

        #expect(suite.spy.loadedHTMLCount == 0)
        #expect(suite.service.borrowWarmWebView() == nil)
    }

    @Test("Prewarm toggle off in the fresh config releases the stage-1 instance")
    func prewarmToggleOffReleasesStageOneInstance() async throws {
        service.prewarmResources(for: try loadPrewarmTestConfig("InAppWebviewValid"))
        await drainMainQueue()
        #expect(spy.loadedHTMLCount == 2)

        service.prewarmResources(for: try Self.config(prewarmToggle: false))
        await drainMainQueue()

        #expect(spy.stopLoadingCount >= 1)
        #expect(service.borrowWarmWebView() == nil)
    }

    @Test("A present section without the key, or an explicit true, keeps the prewarm on",
          arguments: [nil, true] as [Bool?])
    func prewarmToggleAbsentOrTrueKeepsFeatureOn(_ toggle: Bool?) async throws {
        service.prewarmResources(for: try Self.config(prewarmToggle: toggle))
        await drainMainQueue()

        #expect(spy.loadedHTMLCount == 2)
    }

    @Test("A toggle-off release that beats the slow stage-1 hop still kills the head start")
    func releaseBeforeStageOneBlocksHeadStart() async throws {
        let suite = try Self.init(cachedConfig: loadPrewarmTestConfig("InAppWebviewValid"))

        suite.service.prewarmResources(for: try Self.config(prewarmToggle: false))
        await suite.drainMainQueue()

        suite.service.prewarmProcess()
        try await Task.sleep(nanoseconds: 100_000_000)
        await suite.drainMainQueue()

        #expect(suite.spy.loadedHTMLCount == 0)
        #expect(suite.service.borrowWarmWebView() == nil)
    }

    @Test("A no-layers release also blocks a late stage-1 hop")
    func noLayersReleaseBlocksLateStageOne() async throws {
        let suite = try Self.init(cachedConfig: loadPrewarmTestConfig("InAppWebviewValid"))

        suite.service.prewarmResources(for: ConfigResponse())
        await suite.drainMainQueue()

        suite.service.prewarmProcess()
        try await Task.sleep(nanoseconds: 100_000_000)
        await suite.drainMainQueue()

        #expect(suite.spy.loadedHTMLCount == 0)
    }
}

/// A hidden prewarm WebView must never be able to wander off to arbitrary URLs.
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
