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

    /// Главное обещание резолвера: сколько блоков ни спросило бы про один id, за данными идём один
    /// раз. Пока конфиг синхронный это незаметно, с сетью — это разница между одним и N запросами.
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

    /// Перезагрузка блока не должна вечно брать из кэша прежний адрес: выключенный или
    /// переехавший блок иначе не починится до перезапуска приложения.
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

    // MARK: - Threading

    /// Настоящий конфиг ответит с очереди, на которой его разбирали, а за completion стоят создание
    /// вебвью и правка вёрстки контейнера. Возвращаться на главный поток обязан сам резолвер: иначе
    /// это пришлось бы помнить каждому вызывающему, а забытый хоп проявился бы порчей вёрстки.
    @Test("An answer from a background queue reaches every waiting block on the main thread")
    func backgroundAnswerIsDeliveredOnMain() async {
        let loader = ContentLoaderSpy()
        let resolver = EmbeddedBlockResolver(load: loader.load)
        let delivery = DeliveryRecorder()

        resolver.resolve("promo") { delivery.record($0) }
        resolver.resolve("promo") { delivery.record($0) }

        await delivery.waitForAnswers(count: 2) {
            loader.answerOffMain(.content(.stub))
        }

        #expect(delivery.answers == [.content(.stub), .content(.stub)])
        #expect(delivery.threads == [.main, .main])
    }

    /// Кэш заполняется в том же прыжке, что и доставка, поэтому пришедший с фона ответ виден
    /// следующим блокам как обычное попадание в кэш — синхронно и без второй загрузки.
    @Test("An answer from a background queue lands in the cache as usual")
    func backgroundAnswerIsCached() async {
        let loader = ContentLoaderSpy()
        let resolver = EmbeddedBlockResolver(load: loader.load)
        let delivery = DeliveryRecorder()

        resolver.resolve("promo") { delivery.record($0) }
        await delivery.waitForAnswers(count: 1) {
            loader.answerOffMain(.content(.stub))
        }

        var cached: EmbeddedBlockResolution?
        resolver.resolve("promo") { cached = $0 }

        #expect(cached == .content(.stub))
        #expect(loader.requestedIds == ["promo"])
    }

    /// Спрашивать резолвер положено с главного потока, но чужой вызов с другого не должен ни ронять
    /// хост, ни утаскивать кэш и доставку на постороннюю очередь.
    @Test("A resolve asked off the main thread still answers on it")
    func offMainResolveAnswersOnMain() async {
        // Вызов со стороны — то, что тест и проверяет, поэтому проверку Sendable для этих двух
        // ссылок снимаем вручную: после прыжка обе снова трогаются только с главного потока.
        nonisolated(unsafe) let resolver = EmbeddedBlockResolver(load: { _, completion in completion(.content(.stub)) })
        nonisolated(unsafe) let delivery = DeliveryRecorder()

        await delivery.waitForAnswers(count: 1) {
            DispatchQueue.global().async {
                resolver.resolve("promo") { delivery.record($0) }
            }
        }

        #expect(delivery.answers == [.content(.stub)])
        #expect(delivery.threads == [.main])
    }

    // MARK: - Debug overrides

    /// Приёмка переключает сценарий на ходу, поэтому подмена сильнее и загрузки, и кэша.
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
        // За данными резолвер не ходил: ответ пришёл из подмены.
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

    /// Заглушка на месте конфига: пока его нет, любой id ведёт на страницу ленты сторизов.
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

/// Загрузчик, который отвечает только когда его попросят: так проверяется поведение резолвера, пока
/// загрузка ещё идёт.
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
