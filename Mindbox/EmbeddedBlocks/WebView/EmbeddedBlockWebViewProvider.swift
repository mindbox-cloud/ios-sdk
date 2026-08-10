//
//  EmbeddedBlockWebViewProvider.swift
//  Mindbox
//
//  Created by vailence on 03.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit
import MindboxLogger

/// Контент встроенного блока — веб-страница, найденная по id блока.
///
/// Провайдер не рисует контент и не знает механик: он спрашивает у резолвера, что стоит за id,
/// переводит core-сообщения страницы в состояния контейнера, а действия сверх core-слоя отдаёт
/// универсальному обработчику.
///
/// Экземпляр принадлежит одному контейнеру, поэтому `start()` и `stop()` просто повторяют его
/// видимость и могут вызываться по кругу. После `stop()` провайдер обязан молчать до следующего
/// `start()` — на это опирается контейнер, когда сворачивает просроченный блок.
final class EmbeddedBlockWebViewProvider {

    /// Сообщает каждую смену состояния на главном потоке. Ставится контейнером.
    var onStateChange: ((EmbeddedBlockState) -> Void)?

    var contentView: UIView? { isReady ? page?.view : nil }

    private let id: String
    private let resolver: EmbeddedBlockResolving
    private let actionHandler: EmbeddedBlockActionHandling
    private let readinessOverrides: EmbeddedBlockReadinessOverriding
    private let makePage: (EmbeddedBlockWebContent) -> EmbeddedBlockPageHosting

    /// Страница переживает рестарты: контейнер стартует и останавливает блок по видимости, и
    /// пересоздавать вебвью на каждое возвращение в окно незачем.
    private var page: EmbeddedBlockPageHosting?

    private var isStarted = false

    /// Чем кончилась текущая попытка: `nil` — ещё ничем.
    ///
    /// Исход переживает `stop()`: он свойство страницы, а не факта нахождения в окне. Провал и
    /// `empty` при этом не убивают страницу — она жива и может продолжать говорить, — поэтому
    /// известный исход нужен и как признак того, что блока на экране больше нет.
    private var outcome: EmbeddedBlockState?

    private var isReady: Bool { outcome == .ready }

    /// Номер текущей попытки загрузки. Резолв может ответить уже после `stop()` или после
    /// перезагрузки — по номеру видно, что ответ относится к прошлой попытке, и его надо выбросить.
    private var loadGeneration = 0

    init(id: String,
         resolver: EmbeddedBlockResolving,
         actionHandler: EmbeddedBlockActionHandling,
         readinessOverrides: EmbeddedBlockReadinessOverriding = EmbeddedBlockReadinessOverrides.shared,
         makePage: @escaping (EmbeddedBlockWebContent) -> EmbeddedBlockPageHosting) {
        self.id = id
        self.resolver = resolver
        self.actionHandler = actionHandler
        self.readinessOverrides = readinessOverrides
        self.makePage = makePage

        EmbeddedBlockWebViewProvider.blockCreated(id: id)
    }

    deinit {
        EmbeddedBlockWebViewProvider.blockReleased(id: id)
    }

    func start() {
        start(forceRefresh: false)
    }

    func stop() {
        guard isStarted else { return }

        isStarted = false
        // Исход не сбрасываем: он свойство страницы, а не факта нахождения в окне. Иначе каждый
        // проход блока по экрану стоил бы полной перезагрузки.
        loadGeneration += 1
        page?.cancel()
    }

    /// Начинает загрузку с нуля: страница выбрасывается, а адрес запрашивается заново в обход кэша
    /// резолвера — иначе переехавший или выключенный блок вечно доставал бы прежний адрес.
    func reload() {
        Logger.common(message: "[EmbeddedBlock] Block '\(id)' is reloading", category: .embeddedBlocks)

        // Прежняя страница больше не имеет отношения к делу — сначала отключаем её от себя, чтобы
        // её запоздавшие сообщения не попали в новую попытку.
        page?.onMessage = nil
        page?.onLoadFailure = nil
        page?.onLoadFinish = nil
        page?.cancel()
        page = nil

        isStarted = false
        outcome = nil
        loadGeneration += 1

        start(forceRefresh: true)
    }

    func handle(_ message: EmbeddedBlockPageMessage) {
        guard isStarted else { return }

        switch message {
        case .ready(let height):
            apply(height: height)
        case .heightChanged(let height):
            // Высотой владеет хост — сообщение остаётся в контракте страницы, но на нативной
            // стороне ни на что не влияет.
            Logger.common(message: "[EmbeddedBlock] Ignored heightChanged(\(height)): the host owns the container height", category: .embeddedBlocks)
        case .empty:
            outcome = .empty
            onStateChange?(.empty)
        case .action(let action):
            // Блока на экране нет, а страница жива и продолжает работать — например, досылает то,
            // что запланировал её `setTimeout`. Выполнять её действия в этот момент нельзя: за
            // невидимым блоком не стоит ни одного касания пользователя, а `openUrl` увёл бы его из
            // приложения на пустом месте.
            guard isShown else {
                Logger.common(message: "[EmbeddedBlock] Block '\(id)': ignored action '\(action.type)' from a block that is not shown",
                              category: .embeddedBlocks)
                return
            }

            actionHandler.handle(action)
        }
    }

    func handleLoadFailure() {
        guard isStarted else { return }

        outcome = .failed
        onStateChange?(.failed)
    }

    /// Пока исхода нет, страница ещё грузится — её сообщения относятся к живому блоку.
    private var isShown: Bool {
        outcome == nil || outcome == .ready
    }

    /// Загруженный документ сам по себе ничего не значит: показать блок по нему разрешает только
    /// отладочная подмена — для страниц, которые ещё не умеют присылать `ready`.
    func handleLoadFinish() {
        guard isStarted, !isReady, readinessOverrides.treatsLoadedPageAsReady else { return }

        Logger.common(message: "[EmbeddedBlock] Block '\(id)': debug readiness is ON, showing the loaded page without a 'ready' from it",
                      level: .default,
                      category: .embeddedBlocks)
        outcome = .ready
        onStateChange?(.ready)
    }

    private func start(forceRefresh: Bool) {
        guard !isStarted else { return }

        isStarted = true

        // Страница уже отрендерилась и никуда не делась — показываем её как есть. Возврат блока
        // в окно не стоит ни сети, ни шиммера, ни повторных событий хосту.
        if isReady, page != nil {
            Logger.common(message: "[EmbeddedBlock] Block '\(id)': showing the page rendered earlier",
                          category: .embeddedBlocks)
            onStateChange?(.ready)
            return
        }

        onStateChange?(.loading)
        // Началась новая попытка: чем кончилась прошлая, больше не важно — в том числе и для того,
        // выполнять ли действия страницы.
        outcome = nil

        if let page {
            page.load()
            return
        }

        let generation = loadGeneration
        resolver.resolve(id, forceRefresh: forceRefresh) { [weak self] resolution in
            guard let self, self.isStarted, self.loadGeneration == generation else { return }

            switch resolution {
            case .empty:
                Logger.common(message: "[EmbeddedBlock] Block id '\(self.id)' resolved as empty",
                              category: .embeddedBlocks)
                self.onStateChange?(.empty)
            case .content(let content):
                let page = self.makePage(content)
                page.onMessage = { [weak self] message in
                    self?.handle(message)
                }
                page.onLoadFailure = { [weak self] in
                    self?.handleLoadFailure()
                }
                page.onLoadFinish = { [weak self] in
                    self?.handleLoadFinish()
                }
                self.page = page
                page.load()
            }
        }
    }

    private func apply(height: CGFloat) {
        // «Показывать нечего» страница сообщает явным `empty`, поэтому нулевая высота — это
        // сломанная вёрстка, то есть ошибка.
        guard height > 0 else {
            Logger.common(message: "[EmbeddedBlock] Block '\(id)': page reported zero height, treating as broken", category: .embeddedBlocks)
            outcome = .failed
            onStateChange?(.failed)
            return
        }

        Logger.common(message: "[EmbeddedBlock] Block '\(id)': page is ready", category: .embeddedBlocks)
        outcome = .ready
        onStateChange?(.ready)
    }
}

// MARK: - Live blocks

/// Сколько блоков с каждым id живо прямо сейчас.
///
/// Диагностика, а не механика: два блока с одним id — законный случай, оба покажут один и тот же
/// контент. Но чаще это либо скопированный id, либо переиспользованная ячейка, в которую попал
/// контейнер от другой строки, — а у обоих случаев нет заметных симптомов, кроме «блок оказался не
/// там, где ждали». Поэтому SDK говорит об этом в лог.
///
/// Счётчик общий на процесс, потому что вопрос тоже общий: одинаковые id ищутся не внутри блока, а
/// между блоками. Живых блоков он не удерживает — хранит только числа.
extension EmbeddedBlockWebViewProvider {

    private static var liveBlocks: [String: Int] = [:]

    /// Блоки создаются и умирают с UIKit-вью, то есть на главном потоке. Замок стоит на случай, если
    /// это когда-нибудь перестанет быть правдой: диагностика не должна ронять SDK.
    private static let liveBlocksLock = NSLock()

    static func liveCount(for id: String) -> Int {
        liveBlocksLock.lock()
        defer { liveBlocksLock.unlock() }

        return liveBlocks[id] ?? 0
    }

    fileprivate static func blockCreated(id: String) {
        liveBlocksLock.lock()
        let count = (liveBlocks[id] ?? 0) + 1
        liveBlocks[id] = count
        liveBlocksLock.unlock()

        Logger.common(message: "[EmbeddedBlock] Block '\(id)' is created, \(count) live with this id",
                      category: .embeddedBlocks)

        guard count > 1 else { return }

        Logger.common(message: """
        [EmbeddedBlock] \(count) live blocks share id '\(id)'. They show the same content, \
        each rendered on its own. If that is unexpected, check that a reusable cell is not carrying \
        a block container from another row: a block is created for one id and cannot be repointed.
        """, category: .embeddedBlocks)
    }

    fileprivate static func blockReleased(id: String) {
        liveBlocksLock.lock()
        let remaining = max(0, (liveBlocks[id] ?? 1) - 1)
        if remaining > 0 {
            liveBlocks[id] = remaining
        } else {
            liveBlocks.removeValue(forKey: id)
        }
        liveBlocksLock.unlock()

        Logger.common(message: "[EmbeddedBlock] Block '\(id)' is released, \(remaining) live with this id",
                      category: .embeddedBlocks)
    }
}
