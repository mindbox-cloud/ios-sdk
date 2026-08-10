//
//  EmbeddedBlockWebViewProviderTests.swift
//  MindboxTests
//
//  Created by vailence on 03.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import UIKit
@testable import Mindbox

@Suite("Embedded block web view provider", .tags(.embeddedBlocks))
@MainActor
struct EmbeddedBlockWebViewProviderTests {

    // MARK: - Loading

    @Test("Start resolves the id and loads the resolved content")
    func startResolvesAndLoads() {
        let bed = EmbeddedBlockTestBed(id: "promo")
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.start()

        #expect(bed.resolver.resolvedIds == ["promo"])
        #expect(bed.pageFactory.contents == [.stub])
        #expect(bed.page?.loadCount == 1)
        #expect(states == [.loading])
        // До готовности страницы контента нет: контейнеру нечего показывать.
        #expect(bed.provider.contentView == nil)
    }

    @Test("Second start does not resolve or load again")
    func secondStartDoesNothing() {
        let bed = EmbeddedBlockTestBed()

        bed.provider.start()
        bed.provider.start()

        #expect(bed.resolver.resolveCount == 1)
        #expect(bed.page?.loadCount == 1)
    }

    /// Выключенный в админке или неизвестный блок — не ошибка: страницу для него даже не создаём.
    @Test("Empty resolution needs no page at all")
    func emptyResolutionCreatesNoPage() {
        let bed = EmbeddedBlockTestBed(resolution: .empty)
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.start()

        #expect(states == [.loading, .empty])
        #expect(bed.pageFactory.pages.isEmpty)
        #expect(bed.provider.contentView == nil)
    }

    // MARK: - Readiness

    /// О готовности говорит только сама страница — это единственный источник истины.
    @Test("Page ready makes the content available")
    func pageReadyMakesContentAvailable() {
        let bed = EmbeddedBlockTestBed()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.start()
        bed.page?.send(.ready(height: 104))

        #expect(states == [.loading, .ready])
        #expect(bed.provider.contentView === bed.page?.view)
    }

    /// Молчащая страница готовой не становится: загруженный документ ничего не говорит о том, есть
    /// ли блоку что показать. Такой блок добьёт таймаут контейнера.
    @Test("Silent page never becomes ready on its own")
    func silentPageStaysLoading() {
        let bed = EmbeddedBlockTestBed()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.start()

        #expect(states == [.loading])
        #expect(bed.provider.contentView == nil)
    }

    /// Странице без контента честнее сказать `empty`, поэтому нулевая высота — сломанная вёрстка.
    @Test("Zero height in ready is a failure")
    func zeroHeightIsFailure() {
        let bed = EmbeddedBlockTestBed()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.start()
        bed.page?.send(.ready(height: 0))

        #expect(states.last == .failed)
        #expect(bed.provider.contentView == nil)
    }

    /// Высотой владеет хост: сообщение в контракте есть, но вёрстку оно не трогает.
    @Test("Height change leaves the state alone")
    func heightChangeChangesNothing() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.page?.send(.ready(height: 104))
        bed.page?.send(.heightChanged(height: 132))

        #expect(states == [.ready])
    }

    @Test("Page empty collapses the block")
    func pageEmptyCollapsesTheBlock() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.page?.send(.ready(height: 104))
        bed.page?.send(.empty)

        #expect(states == [.ready, .empty])
        #expect(bed.provider.contentView == nil)
    }

    // MARK: - Debug readiness

    /// Обычное правило: загруженный документ ничего не говорит о том, есть ли блоку что показать.
    @Test("Loaded document alone does not make the block ready")
    func loadFinishAloneChangesNothing() {
        let bed = EmbeddedBlockTestBed()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.start()
        bed.page?.finishLoad()

        #expect(states == [.loading])
        #expect(bed.provider.contentView == nil)
    }

    /// Со включённой подменой блок показывается по загруженному документу — так проверяется UI,
    /// пока страница не умеет присылать `ready`.
    @Test("With the debug override a loaded document shows the block")
    func loadFinishMakesBlockReadyWithOverride() {
        let bed = EmbeddedBlockTestBed(treatsLoadedPageAsReady: true)
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.start()
        bed.page?.finishLoad()

        #expect(states == [.loading, .ready])
        #expect(bed.provider.contentView === bed.page?.view)
    }

    /// Страница, которая контракт умеет, ведёт себя с подменой так же, как без неё: `ready` уже
    /// показал блок, и второго показа документ не добавляет.
    @Test("A page that sent ready is not shown twice by the override")
    func readyBeforeLoadFinishIsNotDuplicated() {
        let bed = EmbeddedBlockTestBed(treatsLoadedPageAsReady: true)
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.start()
        bed.page?.send(.ready(height: 104))
        bed.page?.finishLoad()

        #expect(states == [.loading, .ready])
    }

    /// Подмена не сильнее страницы: сказанное ей «показывать нечего» сворачивает блок и со
    /// включённым флагом.
    @Test("The override does not swallow an empty from the page")
    func overrideDoesNotSwallowEmpty() {
        let bed = EmbeddedBlockTestBed(treatsLoadedPageAsReady: true)
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.start()
        bed.page?.finishLoad()
        bed.page?.send(.empty)

        #expect(states == [.loading, .ready, .empty])
        #expect(bed.provider.contentView == nil)
    }

    /// После `stop()` провайдер молчит целиком — подмена этого не меняет.
    @Test("Loaded document after a stop is ignored even with the override")
    func loadFinishAfterStopIsIgnored() {
        let bed = EmbeddedBlockTestBed(treatsLoadedPageAsReady: true)
        bed.provider.start()
        bed.provider.stop()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.page?.finishLoad()

        #expect(states.isEmpty)
        #expect(bed.provider.contentView == nil)
    }

    /// Выброшенная перезагрузкой страница не должна показать себя и через подмену.
    @Test("The dropped page cannot show itself through the override")
    func droppedPageCannotFinishIntoTheNewAttempt() {
        let bed = EmbeddedBlockTestBed(treatsLoadedPageAsReady: true)
        bed.provider.start()
        let firstPage = bed.page
        bed.provider.reload()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        firstPage?.finishLoad()

        #expect(states.isEmpty)
        #expect(bed.provider.contentView == nil)
    }

    // MARK: - Load failure

    /// Провал загрузки — единственное, о чём судит навигация.
    @Test("Load failure fails the block")
    func loadFailureFailsTheBlock() {
        let bed = EmbeddedBlockTestBed()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.start()
        bed.page?.failLoad()

        #expect(states == [.loading, .failed])
        #expect(bed.provider.contentView == nil)
    }

    @Test("Load failure after a stop is ignored")
    func loadFailureAfterStopIsIgnored() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.provider.stop()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.page?.failLoad()

        #expect(states.isEmpty)
    }

    // MARK: - Page actions

    /// Ядро словаря страницы не знает: всё сверх core-слоя уходит обработчику как есть и состояние
    /// контейнера не трогает.
    @Test("Page action is routed to the handler and changes no state")
    func actionIsRouted() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        let action = EmbeddedBlockPageAction(type: "openUrl", payload: ["url": "https://mindbox.ru"])
        bed.page?.send(.action(action))

        #expect(bed.actionHandler.handledActions == [action])
        #expect(states.isEmpty)
    }

    /// Остановленный провайдер молчит целиком — в том числе не будит обработчик действий.
    @Test("Actions after a stop do not reach the handler")
    func actionsAfterStopAreIgnored() {
        let bed = EmbeddedBlockTestBed()

        bed.provider.start()
        bed.provider.stop()
        bed.page?.send(.action(EmbeddedBlockPageAction(type: "openUrl", payload: [:])))

        #expect(bed.actionHandler.handledActions.isEmpty)
    }

    @Test("Action from a shown block is routed")
    func actionFromShownBlockIsRouted() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.send(.ready(height: 104))

        bed.page?.send(.action(.openUrlStub))

        #expect(bed.actionHandler.handledActions == [.openUrlStub])
    }

    /// Схлопнутый блок не убивает страницу — она жива и может досылать то, что запланировала. Но за
    /// невидимым блоком не стоит ни одного касания пользователя, а `openUrl` увёл бы его из
    /// приложения на пустом месте.
    @Test("Actions from a block collapsed as empty do not reach the handler")
    func actionsAfterEmptyAreIgnored() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()

        bed.page?.send(.empty)
        bed.page?.send(.action(.openUrlStub))

        #expect(bed.actionHandler.handledActions.isEmpty)
    }

    @Test("Actions from a failed block do not reach the handler")
    func actionsAfterFailureAreIgnored() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()

        bed.page?.failLoad()
        bed.page?.send(.action(.openUrlStub))

        #expect(bed.actionHandler.handledActions.isEmpty)
    }

    /// Сломанная вёрстка — тот же непоказанный блок: действия из него тоже не выполняются.
    @Test("Actions from a block broken by a zero height do not reach the handler")
    func actionsAfterZeroHeightAreIgnored() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()

        bed.page?.send(.ready(height: 0))
        bed.page?.send(.action(.openUrlStub))

        #expect(bed.actionHandler.handledActions.isEmpty)
    }

    /// Запрет держится на исходе попытки, а не на странице: новая попытка снова живая.
    @Test("A new attempt after a failure accepts actions again")
    func retryAfterFailureAcceptsActions() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.failLoad()

        bed.provider.stop()
        bed.provider.start()
        bed.page?.send(.action(.openUrlStub))

        #expect(bed.actionHandler.handledActions == [.openUrlStub])
    }

    // MARK: - Stop and restart

    /// После `stop()` провайдер обязан молчать — на это опирается контейнер, когда сворачивает
    /// просроченный контент по своему таймауту.
    @Test("Stop cancels the page and ignores what it says afterwards")
    func stopCancelsThePage() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.stop()
        bed.page?.send(.ready(height: 104))

        #expect(bed.page?.cancelCount == 1)
        #expect(states.isEmpty)
        #expect(bed.provider.contentView == nil)
    }

    /// Контейнер зовёт `start()` каждый раз, когда возвращается в окно: пересоздавать вебвью и
    /// заново спрашивать резолвер на каждое возвращение незачем.
    @Test("Restart reuses the same page without resolving again")
    func restartReusesThePage() {
        let bed = EmbeddedBlockTestBed()

        bed.provider.start()
        bed.provider.stop()
        bed.provider.start()
        bed.page?.send(.ready(height: 104))

        #expect(bed.resolver.resolveCount == 1)
        #expect(bed.pageFactory.pages.count == 1)
        #expect(bed.page?.loadCount == 2)
        #expect(bed.provider.contentView === bed.page?.view)
    }

    /// Блок уехал с экрана уже показанным — на возврате он не должен грузиться заново: страница
    /// осталась в памяти, показываем её как есть.
    @Test("Page rendered before the block left the window is shown again without a reload")
    func renderedPageIsShownAgainWithoutReload() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.send(.ready(height: 104))
        bed.provider.stop()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.start()

        #expect(states == [.ready])
        #expect(bed.page?.loadCount == 1)
        #expect(bed.resolver.resolveCount == 1)
        #expect(bed.provider.contentView === bed.page?.view)
    }

    /// А вот блок, который показать не удалось, получает на возврате новую попытку — это
    /// единственный ретрай, который у блока пока есть.
    @Test("Failed block tries again when it comes back")
    func failedBlockTriesAgainOnReturn() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.failLoad()
        bed.provider.stop()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.start()

        #expect(states == [.loading])
        #expect(bed.page?.loadCount == 2)
    }

    // MARK: - Live blocks

    /// Счётчик живых блоков общий на процесс, поэтому у каждого теста свой id: иначе тесты, идущие
    /// параллельно, считали бы блоки друг друга.
    @Test("Live count follows the life of a block")
    func liveCountFollowsBlockLife() {
        let id = "live-count-single"
        #expect(EmbeddedBlockWebViewProvider.liveCount(for: id) == 0)

        do {
            let provider = makeProvider(id: id)
            withExtendedLifetime(provider) {
                #expect(EmbeddedBlockWebViewProvider.liveCount(for: id) == 1)
            }
        }

        #expect(EmbeddedBlockWebViewProvider.liveCount(for: id) == 0)
    }

    @Test("Blocks sharing an id are counted together")
    func liveCountSumsBlocksOfTheSameId() {
        let id = "live-count-shared"

        do {
            let first = makeProvider(id: id)
            let second = makeProvider(id: id)
            withExtendedLifetime((first, second)) {
                #expect(EmbeddedBlockWebViewProvider.liveCount(for: id) == 2)
            }
        }

        #expect(EmbeddedBlockWebViewProvider.liveCount(for: id) == 0)
    }

    @Test("Blocks with different ids are counted apart")
    func liveCountKeepsIdsApart() {
        let promo = "live-count-promo"
        let stories = "live-count-stories"

        let provider = makeProvider(id: promo)
        withExtendedLifetime(provider) {
            #expect(EmbeddedBlockWebViewProvider.liveCount(for: promo) == 1)
            #expect(EmbeddedBlockWebViewProvider.liveCount(for: stories) == 0)
        }
    }

    private func makeProvider(id: String) -> EmbeddedBlockWebViewProvider {
        EmbeddedBlockWebViewProvider(id: id,
                                     resolver: EmbeddedBlockResolverMock(),
                                     actionHandler: EmbeddedBlockActionHandlerMock(),
                                     makePage: { _ in EmbeddedBlockPageMock() })
    }

    /// Резолв мог доехать уже после остановки — тогда он относится к прошлой попытке.
    @Test("Resolution arriving after a stop creates nothing")
    func lateResolutionAfterStopIsIgnored() {
        let bed = EmbeddedBlockTestBed()
        bed.resolver.isDeferred = true
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.start()
        bed.provider.stop()
        bed.resolver.flush()

        #expect(bed.pageFactory.pages.isEmpty)
        #expect(states == [.loading])
    }

    // MARK: - Reload

    @Test("Reload asks for the content again bypassing the cache and builds a new page")
    func reloadRefetchesTheContent() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.send(.ready(height: 104))
        let firstPage = bed.page
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.resolver.resolution = .content(.other)
        bed.provider.reload()

        #expect(bed.resolver.forceRefreshHistory == [false, true])
        #expect(bed.pageFactory.contents == [.stub, .other])
        #expect(bed.pageFactory.pages.count == 2)
        #expect(bed.page !== firstPage)
        #expect(firstPage?.cancelCount == 1)
        #expect(states == [.loading])
        // Готовность начинается с нуля: новая страница ещё ничего не сказала.
        #expect(bed.provider.contentView == nil)
    }

    /// Прежняя страница уже не имеет отношения к делу — её запоздавшие сообщения не должны
    /// показать выброшенный контент.
    @Test("The dropped page cannot report into the new attempt")
    func droppedPageIsSilenced() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.send(.ready(height: 104))
        let firstPage = bed.page
        bed.provider.reload()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        firstPage?.send(.ready(height: 104))
        firstPage?.failLoad()

        #expect(states.isEmpty)
        #expect(bed.provider.contentView == nil)
    }

    /// Резолв прошлой попытки не должен подменить страницу новой.
    @Test("Resolution arriving after a reload does not add a second page")
    func lateResolutionAfterReloadIsIgnored() {
        let bed = EmbeddedBlockTestBed()
        bed.resolver.isDeferred = true
        bed.provider.start()

        bed.provider.reload()
        bed.resolver.flush()

        #expect(bed.resolver.resolveCount == 2)
        #expect(bed.pageFactory.pages.count == 1)
    }

    @Test("Reloaded block becomes ready through the same path")
    func reloadedBlockBecomesReady() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.send(.ready(height: 104))

        bed.provider.reload()
        bed.page?.send(.ready(height: 104))

        #expect(bed.provider.contentView === bed.page?.view)
    }
}
