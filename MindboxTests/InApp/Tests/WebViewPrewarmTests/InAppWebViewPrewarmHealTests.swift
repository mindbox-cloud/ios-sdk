import Foundation
import Testing
import WebKit
@testable import Mindbox

@MainActor
@Suite("InApp WebView prewarm poisoned-cache heal", .tags(.webView))
struct InAppWebViewPrewarmHealTests {

    private final class SpyWebView: WKWebView {
        private(set) var loadedHTMLCount = 0

        override func loadHTMLString(_ string: String, baseURL: URL?) -> WKNavigation? {
            loadedHTMLCount += 1
            return nil // spy only — keep WebKit from actually navigating in unit tests
        }

        override func stopLoading() {}
    }

    private final class PurgeSpy {
        private(set) var purgedURLs: [String?] = []
        var pendingCompletions: [() -> Void] = []
        var completesImmediately = true

        func purge(_ failedURL: String?, completion: @escaping () -> Void) {
            purgedURLs.append(failedURL)
            if completesImmediately {
                completion()
            } else {
                pendingCompletions.append(completion)
            }
        }
    }

    private let spy: SpyWebView
    private let purgeSpy: PurgeSpy
    private let service: InAppWebViewPrewarmService

    init() throws {
        self = try Self.init(cacheEnabled: true)
    }

    private init(cacheEnabled: Bool) throws {
        let spy = SpyWebView(frame: .zero, configuration: WKWebViewConfiguration())
        self.spy = spy
        let purgeSpy = PurgeSpy()
        self.purgeSpy = purgeSpy

        let storage = MockPersistenceStorage()
        storage.configuration = try MBConfiguration(endpoint: "Test.Endpoint", domain: "api.mindbox.ru")
        storage.deviceUUID = "test-device-uuid"

        service = InAppWebViewPrewarmService(
            persistenceStorage: storage,
            makeWebView: { spy },
            fetchHTML: { _, completion in completion("<html><body>content</body></html>") },
            loadCachedConfig: { nil },
            isCacheEnabled: { cacheEnabled },
            purgeCache: { url, completion in purgeSpy.purge(url, completion: completion) }
        )
    }

    private func drainMainQueue() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async { continuation.resume() }
        }
    }

    private func runPrewarm() async throws {
        service.prewarmResources(for: try loadPrewarmTestConfig("InAppWebviewValid"))
        await drainMainQueue()
        await drainMainQueue()
        #expect(spy.loadedHTMLCount == 2) // preconnect + content page
    }

    private var poisonedScript: String { "https://web-static.mindbox.ru/js/byendpoint/x.webview.js" }

    @Test("A recoverable script error purges the host and reloads the content page exactly once")
    func healsOncePerContentLoad() async throws {
        try await runPrewarm()

        service.healPrewarmContentPage(failedURL: poisonedScript, status: 404)
        #expect(purgeSpy.purgedURLs.count == 1)
        #expect(purgeSpy.purgedURLs.first == poisonedScript)
        #expect(spy.loadedHTMLCount == 3)

        // One-shot: the same (or another) error must not loop the reload.
        service.healPrewarmContentPage(failedURL: poisonedScript, status: 404)
        #expect(purgeSpy.purgedURLs.count == 1)
        #expect(spy.loadedHTMLCount == 3)
    }

    @Test("The reload is sequenced strictly after the purge completes")
    func reloadWaitsForThePurge() async throws {
        try await runPrewarm()
        purgeSpy.completesImmediately = false

        service.healPrewarmContentPage(failedURL: poisonedScript, status: 404)
        #expect(spy.loadedHTMLCount == 2) // purge still in flight — no reload yet

        purgeSpy.pendingCompletions.forEach { $0() }
        #expect(spy.loadedHTMLCount == 3)
    }

    @Test("Non-recoverable errors do not trigger the heal")
    func ignoresNonRecoverableErrors() async throws {
        try await runPrewarm()

        service.healPrewarmContentPage(failedURL: "https://cdn.test/banner.png", status: 404)
        service.healPrewarmContentPage(failedURL: poisonedScript, status: 200)

        #expect(purgeSpy.purgedURLs.isEmpty)
        #expect(spy.loadedHTMLCount == 2)
    }

    @Test("Cache feature off: the page is not retained and the heal is disarmed")
    func cacheOffDisarmsTheHeal() async throws {
        let suite = try Self.init(cacheEnabled: false)
        suite.service.prewarmResources(for: try loadPrewarmTestConfig("InAppWebviewValid"))
        await suite.drainMainQueue()
        await suite.drainMainQueue()
        #expect(suite.spy.loadedHTMLCount == 2)

        suite.service.healPrewarmContentPage(failedURL: poisonedScript, status: 404)

        #expect(suite.purgeSpy.purgedURLs.isEmpty)
        #expect(suite.spy.loadedHTMLCount == 2)
    }

    @Test("After a borrow the prewarm never heals — the show runs its own retry policy")
    func borrowDisarmsTheHeal() async throws {
        try await runPrewarm()

        _ = service.borrowWarmWebView()
        service.healPrewarmContentPage(failedURL: poisonedScript, status: 404)

        #expect(purgeSpy.purgedURLs.isEmpty)
        // borrow itself parks the page with one blank load; the heal must add nothing.
        #expect(spy.loadedHTMLCount == 3)
    }
}
