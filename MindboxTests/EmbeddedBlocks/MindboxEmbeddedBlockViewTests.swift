//
//  MindboxEmbeddedBlockViewTests.swift
//  MindboxTests
//
//  Created by vailence on 03.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import UIKit
@testable import Mindbox

@Suite("MindboxEmbeddedBlockView container", .tags(.embeddedBlocks))
@MainActor
struct MindboxEmbeddedBlockViewTests {

    // MARK: - Height

    /// Место под блок занимается сразу: высоту назначил хост, и до исхода загрузки она не меняется —
    /// иначе контейнер прыгал бы в вёрстке хоста.
    @Test("Loading block keeps the height given at creation")
    func loadingKeepsGivenHeight() {
        let block = BlockFixture()

        #expect(block.view.intrinsicContentSize.height == 120)
        // Ширина — дело хоста, контейнер её не заявляет.
        #expect(block.view.intrinsicContentSize.width == UIView.noIntrinsicMetric)
    }

    @Test("Shown block keeps the same height")
    func shownBlockKeepsHeight() {
        let block = BlockFixture()
        block.attachToWindow()

        block.page?.send(.ready(height: 96))

        #expect(block.view.intrinsicContentSize.height == 120)
    }

    /// Контейнер — единственный источник высоты, поэтому хост на фреймах обязан получить то же
    /// число через ту точку, которой пользуется он.
    @Test("sizeThatFits reports the same height as intrinsicContentSize")
    func sizeThatFitsMatchesIntrinsicHeight() {
        let block = BlockFixture(height: 96)

        let fitted = block.view.sizeThatFits(CGSize(width: 320, height: CGFloat.greatestFiniteMagnitude))

        #expect(fitted.height == 96)
        #expect(fitted.width == 320)
    }

    @Test("Failed block collapses the container")
    func failedBlockCollapses() {
        let block = BlockFixture()
        block.attachToWindow()

        block.page?.failLoad()

        #expect(block.view.intrinsicContentSize.height == 0)
    }

    /// Ошибку можно показать вместо схлопывания — тогда блок остаётся той же высоты.
    @Test("Failed block with an error view keeps its height")
    func failedBlockWithErrorViewKeepsHeight() {
        let block = BlockFixture()
        let errorView = UIView()
        block.view.errorView = errorView
        block.attachToWindow()

        block.page?.failLoad()

        #expect(block.view.intrinsicContentSize.height == 120)
        #expect(errorView.superview === block.view)
    }

    /// Хост уже забрал место схлопнутого блока — раскрывать его задним числом значит дёргать
    /// вёрстку. Поздний errorView только запоминается.
    @Test("Error view assigned after the collapse does not expand the block")
    func lateErrorViewDoesNotExpandCollapsedBlock() {
        let block = BlockFixture()
        block.attachToWindow()
        block.page?.failLoad()

        let errorView = UIView()
        block.view.errorView = errorView

        #expect(block.view.intrinsicContentSize.height == 0)
        #expect(errorView.superview == nil)
    }

    /// Запомненный errorView вступает в силу со следующей загрузки: новая попытка, снова провал —
    /// и теперь блок показывает ошибку вместо схлопывания.
    @Test("Error view assigned after the collapse applies on the next load")
    func lateErrorViewAppliesOnNextLoad() {
        let block = BlockFixture()
        block.attachToWindow()
        block.page?.failLoad()
        let errorView = UIView()
        block.view.errorView = errorView

        block.view.reload()
        block.page?.failLoad()

        #expect(block.view.intrinsicContentSize.height == 120)
        #expect(errorView.superview === block.view)
    }

    /// Пустой блок сворачивается всегда: показывать нечего, а ошибки не было.
    @Test("Empty block collapses even with an error view set")
    func emptyBlockAlwaysCollapses() {
        let block = BlockFixture()
        block.view.errorView = UIView()
        block.attachToWindow()

        block.page?.send(.empty)

        #expect(block.view.intrinsicContentSize.height == 0)
    }

    /// Хост, попросивший отрицательную высоту, не должен получить неразрешимый набор констрейнтов.
    @Test("Negative height given by the host is clamped to zero")
    func negativeHeightIsClamped() {
        let block = BlockFixture(height: -50)

        #expect(block.view.intrinsicContentSize.height == 0)
    }

    // MARK: - Content view

    @Test("Shown content is attached and pinned to the container")
    func shownContentIsPinned() throws {
        let block = BlockFixture()
        block.attachToWindow()

        block.page?.send(.ready(height: 96))

        let content = try #require(block.page?.view)
        #expect(content.superview === block.view)
        #expect(content.translatesAutoresizingMaskIntoConstraints == false)
        // Четыре края: контент всегда заполняет контейнер, который ему дали.
        #expect(block.view.constraints.count == 4)
    }

    @Test("Failed content is detached")
    func failedContentIsDetached() throws {
        let block = BlockFixture()
        block.attachToWindow()

        block.page?.send(.ready(height: 96))
        let content = try #require(block.page?.view)
        block.page?.failLoad()

        #expect(content.superview == nil)
        #expect(block.view.intrinsicContentSize.height == 0)
    }

    @Test("Empty content is detached")
    func emptyContentIsDetached() throws {
        let block = BlockFixture()
        block.attachToWindow()

        block.page?.send(.ready(height: 96))
        let content = try #require(block.page?.view)
        block.page?.send(.empty)

        #expect(content.superview == nil)
    }

    /// Перезагруженный блок не должен тащить в новую попытку вью выброшенной страницы.
    @Test("Reload detaches the content of the dropped page")
    func reloadDetachesOldContent() throws {
        let block = BlockFixture()
        block.attachToWindow()
        block.page?.send(.ready(height: 96))
        let oldContent = try #require(block.page?.view)

        block.view.reload()

        #expect(oldContent.superview == nil)
    }

    // MARK: - Events

    /// Публичных исходов два — показан и не показан; загрузка не исход, и хост о ней не слышит.
    @Test("Loading is silent: the delegate hears only outcomes")
    func loadingReportsNothing() async {
        let block = BlockFixture()
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate

        block.attachToWindow()
        await mainQueueTurn()

        #expect(delegate.events.isEmpty)
    }

    /// Блок, который так и не попал в окно, ничего не грузит — и сообщать ему нечего.
    @Test("Block outside a window reports nothing and loads nothing")
    func blockOutsideWindowDoesNothing() async {
        let block = BlockFixture()
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate

        await mainQueueTurn()

        #expect(delegate.events.isEmpty)
        #expect(block.bed.resolver.resolveCount == 0)
    }

    @Test("Shown block reports didLoad")
    func shownBlockReportsDidLoad() async {
        let block = BlockFixture()
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate
        block.attachToWindow()
        await mainQueueTurn()

        block.page?.send(.ready(height: 96))
        await mainQueueTurn()

        #expect(delegate.events == [.loaded])
    }

    @Test("Failed block reports didFail")
    func failedBlockReportsDidFail() async {
        let block = BlockFixture()
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate
        block.attachToWindow()
        await mainQueueTurn()

        block.page?.failLoad()
        await mainQueueTurn()

        #expect(delegate.events == [.failed])
    }

    /// «Пусто» для хоста — тот же непоказ, что и провал: отдельного события у него нет.
    @Test("Empty block reports didFail")
    func emptyBlockReportsDidFail() async {
        let block = BlockFixture(resolution: .empty)
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate

        block.attachToWindow()
        await mainQueueTurn()

        #expect(delegate.events == [.failed])
    }

    /// Хост, назначающий делегата в `viewDidLoad`, иначе пропустил бы уже случившийся исход.
    @Test("Delegate assigned after the outcome still receives it")
    func lateDelegateStillReceivesOutcome() async {
        let block = BlockFixture()
        block.attachToWindow()
        block.page?.failLoad()
        await mainQueueTurn()

        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate
        await mainQueueTurn()

        #expect(delegate.events == [.failed])
    }

    /// Хост штатно переприсваивает делегата на каждой переиспользованной ячейке. Отдавать ему на это
    /// уже услышанный исход нельзя: на исход он перестраивает вёрстку, а перестройка вёрстки снова
    /// переприсваивает делегата — и блок укатился бы в цикл на скролле.
    @Test("Reassigning the same delegate does not repeat the outcome")
    func sameDelegateReassignedHearsTheOutcomeOnce() async {
        let block = BlockFixture()
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate
        block.attachToWindow()
        await mainQueueTurn()
        block.page?.failLoad()
        await mainQueueTurn()

        block.view.delegate = delegate
        await mainQueueTurn()
        block.view.delegate = delegate
        await mainQueueTurn()

        #expect(delegate.events == [.failed])
    }

    /// А другой делегат — это другой подписчик, и уже случившийся исход он обязан услышать.
    @Test("A delegate replacing another one still receives the outcome")
    func replacingDelegateReceivesTheOutcome() async {
        let block = BlockFixture()
        let first = EmbeddedBlockViewDelegateMock()
        block.view.delegate = first
        block.attachToWindow()
        await mainQueueTurn()
        block.page?.failLoad()
        await mainQueueTurn()

        let second = EmbeddedBlockViewDelegateMock()
        block.view.delegate = second
        await mainQueueTurn()

        #expect(first.events == [.failed])
        #expect(second.events == [.failed])
    }

    /// Контент может упасть снова на возвращении в окно — это не повод превращать исход в поток
    /// одинаковых событий.
    @Test("Repeated failure is reported once")
    func repeatedFailureIsReportedOnce() async {
        let block = BlockFixture()
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate
        block.attachToWindow()
        await mainQueueTurn()

        block.page?.failLoad()
        await mainQueueTurn()
        block.page?.failLoad()
        await mainQueueTurn()

        #expect(delegate.events == [.failed])
    }

    @Test("Block that fails after being shown reports both outcomes in order")
    func failureAfterLoadReportsBothOutcomes() async {
        let block = BlockFixture()
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate
        block.attachToWindow()
        await mainQueueTurn()

        block.page?.send(.ready(height: 96))
        await mainQueueTurn()
        block.page?.failLoad()
        await mainQueueTurn()

        #expect(delegate.events == [.loaded, .failed])
    }

    // MARK: - Presentation for the SwiftUI wrapper

    /// SwiftUI не читает `intrinsicContentSize` у представимой вью и рисует слои хоста сам, поэтому
    /// обёртке нужны и высота, и слой — и то, что она получает, обязано совпадать с тем, что
    /// контейнер действительно показывает.
    @Test("Every change is pushed to the SwiftUI wrapper as a layer and a height")
    func presentationChangesArePushedToWrapper() {
        let block = BlockFixture()
        block.attachToWindow()
        var reported: [EmbeddedBlockPresentation] = []
        block.view.onPresentationChange = { reported.append($0) }

        block.page?.send(.ready(height: 96))
        block.page?.send(.empty)

        #expect(reported == [EmbeddedBlockPresentation(layer: .content, height: 120),
                             EmbeddedBlockPresentation(layer: .nothing, height: 0)])
    }

    /// Провал без экрана ошибки для обёртки — тот же схлопнутый блок, что и пустой: рисовать нечего.
    @Test("Failed block without an error view reports nothing to show")
    func failedBlockReportsNothingToShow() {
        let block = BlockFixture()
        block.attachToWindow()
        var reported: [EmbeddedBlockPresentation] = []
        block.view.onPresentationChange = { reported.append($0) }

        block.page?.failLoad()

        #expect(reported == [EmbeddedBlockPresentation(layer: .nothing, height: 0)])
    }

    /// Согласие на экран ошибки контейнер видит по назначенному `errorView` — и только тогда просит
    /// обёртку нарисовать её слой.
    @Test("Failed block with an error view reports the error layer")
    func failedBlockWithErrorViewReportsErrorLayer() {
        let block = BlockFixture()
        block.view.errorView = UIView()
        block.attachToWindow()
        var reported: [EmbeddedBlockPresentation] = []
        block.view.onPresentationChange = { reported.append($0) }

        block.page?.failLoad()

        #expect(reported == [EmbeddedBlockPresentation(layer: .errorView, height: 120)])
    }

    /// Перезагрузка возвращает блок в загрузку — обёртка обязана снова показать плейсхолдер.
    @Test("Reload reports the placeholder layer again")
    func reloadReportsPlaceholderLayer() {
        let block = BlockFixture()
        block.attachToWindow()
        block.page?.send(.ready(height: 96))
        var reported: [EmbeddedBlockPresentation] = []
        block.view.onPresentationChange = { reported.append($0) }

        block.view.reload()

        #expect(reported == [EmbeddedBlockPresentation(layer: .placeholder, height: 120)])
    }

    // MARK: - Lifecycle

    /// Хост никогда не запускает и не останавливает контент руками: единственный триггер — окно.
    @Test("Entering and leaving a window starts and stops the content")
    func windowMembershipDrivesTheContent() {
        let block = BlockFixture()

        #expect(block.bed.resolver.resolveCount == 0)

        block.attachToWindow()
        #expect(block.page?.loadCount == 1)
        #expect(block.page?.cancelCount == 0)

        block.removeFromWindow()
        #expect(block.page?.cancelCount == 1)
    }

    /// Блок ездит по экрану в ленте и переживает переключение табов: каждый такой проход не должен
    /// стоить перезагрузки, мигания шиммером и повторных событий хосту.
    @Test("Block returning to the window keeps its content as it was")
    func returningBlockKeepsItsContent() async throws {
        let block = BlockFixture()
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate
        block.attachToWindow()
        await mainQueueTurn()
        block.page?.send(.ready(height: 96))
        await mainQueueTurn()
        let content = try #require(block.page?.view)

        block.removeFromWindow()
        block.attachToWindow()
        await mainQueueTurn()

        #expect(block.page?.loadCount == 1)
        #expect(content.superview === block.view)
        #expect(block.view.subviews.contains { $0 is EmbeddedBlockShimmerView } == false)
        #expect(block.view.intrinsicContentSize.height == 120)
        #expect(delegate.events == [.loaded])
    }

    /// Блок, который показать не удалось, на возвращении в окно пробует снова — но место, которое
    /// хост у него уже забрал, попытка назад не отыгрывает. Иначе схлопнутый блок дёргал бы вёрстку
    /// на свою высоту и мигал шиммером на каждый свой проход по экрану, ничего в итоге не показывая.
    @Test("Collapsed block stays collapsed while it tries again")
    func collapsedBlockDoesNotReExpandWhileRetrying() async {
        let block = BlockFixture()
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate
        block.attachToWindow()
        await mainQueueTurn()
        block.page?.failLoad()
        await mainQueueTurn()

        block.removeFromWindow()
        block.attachToWindow()
        await mainQueueTurn()

        // Попытка действительно новая — страница грузится заново...
        #expect(block.page?.loadCount == 2)
        // ...но контейнер под неё места не занимает и шиммером не мигает.
        #expect(block.view.intrinsicContentSize.height == 0)
        #expect(block.view.subviews.isEmpty)
        #expect(delegate.events == [.failed])
    }

    /// Разворачивает блок только показанный контент — и тогда высота возвращается, а хост слышит,
    /// что блок наконец появился.
    @Test("Retry that succeeds gives the block its height back")
    func successfulRetryExpandsTheBlock() async {
        let block = BlockFixture()
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate
        block.attachToWindow()
        await mainQueueTurn()
        block.page?.failLoad()
        await mainQueueTurn()

        block.removeFromWindow()
        block.attachToWindow()
        block.page?.send(.ready(height: 96))
        await mainQueueTurn()

        #expect(block.view.intrinsicContentSize.height == 120)
        #expect(delegate.events == [.failed, .loaded])
    }

    /// Перезагрузка — явное согласие хоста на полный цикл заново, поэтому она место занимает: блок
    /// снова показывает плейсхолдер, даже если до неё был схлопнут.
    @Test("Reload after a collapse shows the placeholder again")
    func reloadAfterCollapseShowsThePlaceholder() {
        let block = BlockFixture()
        block.attachToWindow()
        block.page?.failLoad()

        block.view.reload()

        #expect(block.view.intrinsicContentSize.height == 120)
        #expect(block.view.subviews.contains { $0 is EmbeddedBlockShimmerView })
    }

    /// Пустой блок сворачивается так же — и так же не отыгрывает место назад.
    @Test("Empty block stays collapsed when it returns to the window")
    func emptyBlockStaysCollapsedOnReturn() async {
        let block = BlockFixture(resolution: .empty)
        block.attachToWindow()
        await mainQueueTurn()

        block.removeFromWindow()
        block.attachToWindow()
        await mainQueueTurn()

        #expect(block.view.intrinsicContentSize.height == 0)
        #expect(block.view.subviews.isEmpty)
    }

    // MARK: - Timeout

    /// Контейнер, а не контент, гарантирует, что вёрстка хоста не будет ждать вечно: молчащая
    /// страница за бюджетом сворачивается и сообщает об ошибке.
    @Test("Silent block times out, collapses and reports didFail")
    func silentBlockTimesOut() async {
        let block = BlockFixture()
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate

        block.attachToWindow()
        block.expireTimeout()
        await mainQueueTurn()

        #expect(block.view.intrinsicContentSize.height == 0)
        #expect(delegate.events == [.failed])
        // Контент остановлен, поэтому оживить просроченный блок он уже не может.
        #expect(block.page?.cancelCount == 1)
    }

    @Test("Block shown in time is not failed by the timeout")
    func shownBlockIsNotTimedOut() async {
        let block = BlockFixture()
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate

        block.attachToWindow()
        block.page?.send(.ready(height: 96))
        // Показанный блок снял бюджет, поэтому объявленное «время вышло» его уже не касается.
        block.expireTimeout()
        await mainQueueTurn()

        #expect(block.view.intrinsicContentSize.height == 120)
        #expect(delegate.events == [.loaded])
        #expect(block.page?.cancelCount == 0)
    }

    /// Уход из окна уже остановил контент — снятый таймаут не должен валить то, что не работает.
    @Test("Leaving the window disarms the timeout")
    func leavingWindowDisarmsTimeout() async {
        let block = BlockFixture()
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate

        block.attachToWindow()
        block.removeFromWindow()
        block.expireTimeout()
        await mainQueueTurn()

        #expect(delegate.events.isEmpty)
        #expect(block.view.intrinsicContentSize.height == 120)
    }

    /// Бюджет на загрузку считает время ожидания пользователя, а не календарное: в фоне блока никто
    /// не ждёт, и схлопывать его там незачем — иначе пользователь вернётся к блоку, который сдался,
    /// ни разу не побывав на экране. Что бюджет при этом продолжается с остатка, а не выдаётся
    /// заново, проверяют тесты самого `EmbeddedBlockReadyTimeout`.
    @Test("Timeout pauses in the background and resumes on return")
    func timeoutPausesInBackground() async {
        let block = BlockFixture()
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate
        block.attachToWindow()

        block.enterBackground()
        block.expireTimeout()
        await mainQueueTurn()

        #expect(block.view.intrinsicContentSize.height == 120)
        #expect(delegate.events.isEmpty)

        block.enterForeground()
        block.expireTimeout()
        await mainQueueTurn()

        #expect(block.view.intrinsicContentSize.height == 0)
        #expect(delegate.events == [.failed])
    }

    /// Блок вне окна ничего не грузит, поэтому и бюджет ему не нужен.
    @Test("Returning from the background does not arm a timeout outside a window")
    func foregroundOutsideWindowArmsNothing() async {
        let block = BlockFixture()
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate

        block.enterForeground()
        block.expireTimeout()
        await mainQueueTurn()

        // Отсчёт не просто не сработал — его вовсе не заводили.
        #expect(block.timeoutBed.scheduler.lastDelay == nil)
        #expect(delegate.events.isEmpty)
        #expect(block.view.intrinsicContentSize.height == 120)
    }

    // MARK: - Reload

    /// Перезагрузка идёт тем же путём, что и первый запуск: блок возвращается в загрузку, а хост
    /// слышит новый исход целиком, даже если он совпал с прошлым.
    @Test("Reload restarts the block and reports the outcome again")
    func reloadRestartsTheBlock() async {
        let block = BlockFixture()
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate
        block.attachToWindow()
        await mainQueueTurn()
        block.page?.send(.ready(height: 96))
        await mainQueueTurn()

        block.view.reload()
        await mainQueueTurn()
        block.page?.send(.ready(height: 96))
        await mainQueueTurn()

        #expect(block.bed.resolver.forceRefreshHistory == [false, true])
        #expect(delegate.events == [.loaded, .loaded])
        #expect(block.view.intrinsicContentSize.height == 120)
    }

    /// Контент живёт только пока блок в окне: перезагружать невидимый блок нечего.
    @Test("Reload outside a window does nothing")
    func reloadOutsideWindowDoesNothing() {
        let block = BlockFixture()

        block.view.reload()

        #expect(block.bed.resolver.resolveCount == 0)
        #expect(block.bed.pageFactory.pages.isEmpty)
    }

    /// Новая попытка получает и новый бюджет — иначе перезагруженный блок висел бы в загрузке вечно.
    @Test("Reload arms the timeout again")
    func reloadArmsTheTimeoutAgain() async {
        let block = BlockFixture()
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate
        block.attachToWindow()
        block.page?.send(.ready(height: 96))

        block.view.reload()
        block.expireTimeout()
        await mainQueueTurn()

        #expect(block.view.intrinsicContentSize.height == 0)
        #expect(delegate.events.last == .failed)
    }

    // MARK: - Helpers

    /// Исходы отдаются на следующем витке главной очереди, поэтому блок, поставленный в очередь
    /// после них, продолжится только когда они отработают — очередь последовательная и FIFO.
    private func mainQueueTurn() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                continuation.resume()
            }
        }
    }
}

/// Блок со всеми подменёнными зависимостями и живым окном: окно обязано жить не меньше теста,
/// иначе вью вылетит из окна на середине проверки и контент остановится сам собой.
@MainActor
private final class BlockFixture {

    let bed: EmbeddedBlockTestBed

    /// Бюджет отдаётся вью снаружи, поэтому «время вышло» здесь наступает по команде теста, а не
    /// через сон: `expireTimeout()`.
    let timeoutBed: EmbeddedBlockTimeoutBed

    let view: MindboxEmbeddedBlockView

    private let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))

    var page: EmbeddedBlockPageMock? { bed.page }

    init(height: CGFloat = 120,
         resolution: EmbeddedBlockResolution = .content(.stub)) {
        let bed = EmbeddedBlockTestBed(resolution: resolution)
        let timeoutBed = EmbeddedBlockTimeoutBed()
        self.bed = bed
        self.timeoutBed = timeoutBed
        self.view = MindboxEmbeddedBlockView(id: "block-id",
                                             height: height,
                                             contentProvider: bed.provider,
                                             timeout: timeoutBed.timeout)
    }

    func attachToWindow() {
        window.addSubview(view)
    }

    func removeFromWindow() {
        view.removeFromSuperview()
    }

    /// Объявляет, что бюджет ожидания вышел.
    func expireTimeout() {
        timeoutBed.scheduler.fireAll()
    }

    func enterBackground() {
        timeoutBed.enterBackground()
    }

    func enterForeground() {
        timeoutBed.enterForeground()
    }
}
