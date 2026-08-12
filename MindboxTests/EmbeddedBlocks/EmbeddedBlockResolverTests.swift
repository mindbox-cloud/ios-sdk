//
//  EmbeddedBlockResolverTests.swift
//  MindboxTests
//
//  Created by vailence on 06.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
@testable import Mindbox

@Suite("Embedded block resolver", .tags(.embeddedBlocks))
@MainActor
struct EmbeddedBlockResolverTests {

    /// The resolver's main promise: however many blocks ask about one id, we go for the data once.
    /// While the config is synchronous this is invisible; over the network it is the difference
    /// between one request and N.
    @Test("Blocks asking for the same id at once share a single load")
    func concurrentResolvesShareOneLoad() {
        let loader = ContentLoaderSpy()
        let resolver = EmbeddedBlockResolver(load: loader.load)
        var answers: [EmbeddedBlockResolution] = []

        resolver.resolve("promo") { answers.append($0) }
        resolver.resolve("promo") { answers.append($0) }
        resolver.resolve("promo") { answers.append($0) }

        #expect(loader.requestedIds == ["promo"])
        #expect(answers.isEmpty)

        loader.answer(.content(.stub))

        #expect(answers == [.content(.stub), .content(.stub), .content(.stub)])
    }

    @Test("Different ids are loaded separately")
    func differentIdsAreLoadedSeparately() {
        let loader = ContentLoaderSpy()
        let resolver = EmbeddedBlockResolver(load: loader.load)

        resolver.resolve("promo") { _ in }
        resolver.resolve("stories") { _ in }

        #expect(loader.requestedIds == ["promo", "stories"])
    }

    @Test("Answered id comes from the cache next time")
    func answeredIdIsCached() {
        let loader = ContentLoaderSpy()
        let resolver = EmbeddedBlockResolver(load: loader.load)
        resolver.resolve("promo") { _ in }
        loader.answer(.content(.stub))

        var answer: EmbeddedBlockResolution?
        resolver.resolve("promo") { answer = $0 }

        #expect(loader.requestedIds == ["promo"])
        #expect(answer == .content(.stub))
    }

    /// A block reload must not keep pulling the old address from the cache: a block that was turned
    /// off or moved would otherwise stay broken until the app is restarted.
    @Test("Force refresh asks for the data again and replaces the cache")
    func forceRefreshBypassesTheCache() {
        let loader = ContentLoaderSpy()
        let resolver = EmbeddedBlockResolver(load: loader.load)
        resolver.resolve("promo") { _ in }
        loader.answer(.content(.stub))

        var refreshed: EmbeddedBlockResolution?
        resolver.resolve("promo", forceRefresh: true) { refreshed = $0 }
        loader.answer(.empty)

        #expect(loader.requestedIds == ["promo", "promo"])
        #expect(refreshed == .empty)

        var cached: EmbeddedBlockResolution?
        resolver.resolve("promo") { cached = $0 }
        #expect(cached == .empty)
    }

    /// The real config will answer from a background thread. The cache, the queue of waiters and the
    /// block view live on the main one, so the answer has to move there instead of being handled
    /// wherever it was delivered.
    @Test("An answer from a background thread is delivered on the main thread")
    func backgroundAnswerIsDeliveredOnTheMainThread() async {
        let resolver = EmbeddedBlockResolver(
            load: { _, completion in
                DispatchQueue.global().async { completion(.content(.stub)) }
            },
            overrides: EmbeddedBlockContentOverrides()
        )

        let deliveredOnMainThread: Bool = await withCheckedContinuation { continuation in
            resolver.resolve("promo") { _ in
                continuation.resume(returning: Thread.isMainThread)
            }
        }

        #expect(deliveredOnMainThread)

        // And the cache is already filled on the main thread: the next block gets the answer at once.
        var cached: EmbeddedBlockResolution?
        resolver.resolve("promo") { cached = $0 }
        #expect(cached == .content(.stub))
    }

    // MARK: - Debug overrides

    /// Acceptance testing switches scenarios on the fly, so the override outranks both the load and
    /// the cache.
    @Test("Debug override answers instead of the data and outranks the cache")
    func overrideOutranksEverything() {
        let loader = ContentLoaderSpy()
        let overrides = EmbeddedBlockContentOverrides()
        let resolver = EmbeddedBlockResolver(load: loader.load, overrides: overrides)
        resolver.resolve("promo") { _ in }
        loader.answer(.content(.stub))

        overrides.set(.empty, for: "promo")
        var answers: [EmbeddedBlockResolution] = []
        resolver.resolve("promo") { answers.append($0) }
        resolver.resolve("promo") { answers.append($0) }

        #expect(answers == [.empty, .empty])
        // The resolver did not go for the data: the answer came from the override.
        #expect(loader.requestedIds == ["promo"])
    }

    @Test("Removing the override brings the real content back")
    func removingOverrideRestoresContent() {
        let loader = ContentLoaderSpy()
        let overrides = EmbeddedBlockContentOverrides()
        let resolver = EmbeddedBlockResolver(load: loader.load, overrides: overrides)
        overrides.set(.empty, for: "promo")
        resolver.resolve("promo") { _ in }

        overrides.remove(for: "promo")
        var answer: EmbeddedBlockResolution?
        resolver.resolve("promo") { answer = $0 }
        loader.answer(.content(.stub))

        #expect(loader.requestedIds == ["promo"])
        #expect(answer == .content(.stub))
    }

    @Test("Override applies only to its own id")
    func overrideAppliesToItsIdOnly() {
        let loader = ContentLoaderSpy()
        let overrides = EmbeddedBlockContentOverrides()
        let resolver = EmbeddedBlockResolver(load: loader.load, overrides: overrides)
        overrides.set(.empty, for: "promo")

        var answer: EmbeddedBlockResolution?
        resolver.resolve("promo") { _ in }
        resolver.resolve("stories") { answer = $0 }
        loader.answer(.content(.stub))

        #expect(loader.requestedIds == ["stories"])
        #expect(answer == .content(.stub))
    }

    @Test("Overridden content carries the page markup as it was given")
    func overrideCarriesMarkup() {
        let overrides = EmbeddedBlockContentOverrides()
        overrides.set(.content(EmbeddedBlockWebContent(html: "<html>empty page</html>")), for: "promo")

        guard case .content(let content) = overrides.resolution(for: "promo"),
              case .html(let html) = content.source else {
            Issue.record("Expected the override to carry inline html")
            return
        }
        #expect(html == "<html>empty page</html>")
    }

    /// The stub in place of the config: while there is none, any id leads to the stories feed page.
    @Test("The stubbed loader resolves any id to the stories page")
    func stubbedLoaderResolvesToTheStoriesPage() {
        var resolution: EmbeddedBlockResolution?

        EmbeddedBlockResolver.loadStubbedStoriesPage("whatever") { resolution = $0 }

        guard case .content(let content) = resolution, case .url(let url) = content.source else {
            Issue.record("Expected the stub to resolve into a page url, got \(String(describing: resolution))")
            return
        }
        #expect(url.absoluteString.hasSuffix("stories.html"))
    }
}

/// A loader that answers only when asked to: this is how the resolver's behaviour while a load is
/// still in flight gets tested.
private final class ContentLoaderSpy {

    private(set) var requestedIds: [String] = []

    private var completions: [(EmbeddedBlockResolution) -> Void] = []

    func load(_ id: String, completion: @escaping (EmbeddedBlockResolution) -> Void) {
        requestedIds.append(id)
        completions.append(completion)
    }

    func answer(_ resolution: EmbeddedBlockResolution) {
        let pending = completions
        completions = []
        pending.forEach { $0(resolution) }
    }

    /// Отвечает с фоновой очереди — так ответит настоящий конфиг, разобранный не на главном потоке.
    func answerOffMain(_ resolution: EmbeddedBlockResolution) {
        let pending = completions
        completions = []
        DispatchQueue.global().async {
            pending.forEach { $0(resolution) }
        }
    }
}

/// На каком потоке резолвер отдал ответ. Отдельный тип вместо `Bool` — чтобы упавший тест сразу
/// говорил, что именно разъехалось.
private enum DeliveryThread {
    case main
    case other
}

/// Ждёт ответов резолвера и запоминает, на каком потоке каждый пришёл.
///
/// Читают и пишут его только с главного потока — если это перестанет быть правдой, тест как раз и
/// упадёт на `threads`.
private final class DeliveryRecorder {

    private(set) var answers: [EmbeddedBlockResolution] = []
    private(set) var threads: [DeliveryThread] = []

    private var expectedCount = 0
    private var continuation: CheckedContinuation<Void, Never>?

    func record(_ resolution: EmbeddedBlockResolution) {
        answers.append(resolution)
        threads.append(Thread.isMainThread ? .main : .other)

        guard answers.count >= expectedCount, let continuation else { return }
        self.continuation = nil
        continuation.resume()
    }

    /// Загрузку запускает сам ожидающий: начни её раньше — и ответ мог бы приехать до того, как
    /// тест встал ждать, а ожидание повисло бы навсегда.
    func waitForAnswers(count: Int, _ startLoading: () -> Void) async {
        expectedCount = count
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            startLoading()
        }
    }
}
