//
//  EmbeddedBlockReadyTimeout.swift
//  Mindbox
//
//  Created by vailence on 10.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit
import MindboxLogger

/// Сколько блоку дано на то, чтобы показаться, — и учёт этого времени.
///
/// Бюджет принадлежит контейнеру, а не контенту: чем бы блок ни оказался внутри, вёрстка хоста не
/// ждёт его вечно. Не уложился — контейнер сворачивает блок.
///
/// Считается время ожидания пользователя, а не календарное: пока блока никто не ждёт — приложение
/// в фоне, контейнер вне окна — отсчёт стоит. Иначе пользователь возвращался бы в приложение к
/// блоку, который сдался, пока его никто не видел.
///
/// Но именно стоит, а не начинается заново: потраченное запоминается, и попытка продолжает бюджет
/// с того места, где её прервали. Пауза, отдающая полный бюджет заново, не заканчивается никогда —
/// пользователь, переключающийся между приложениями каждые пять секунд, продлевал бы ожидание
/// блока бесконечно, и вёрстка хоста ждала бы его вечно. Ровно то, против чего бюджет и заведён.
/// Полный бюджет заново получает только новая попытка — `reset()`.
///
/// Загрузку пауза не трогает: она идёт своим чередом, в фоне её тормозит система, а не SDK.

/// Кто выполнит работу, когда истечёт заданный остаток бюджета.
typealias EmbeddedBlockTimeoutScheduling = (TimeInterval, DispatchWorkItem) -> Void

final class EmbeddedBlockReadyTimeout {

    /// Нужен ли отсчёт прямо сейчас: исход ещё неизвестен и блок на виду. Спрашивается заново на
    /// каждом заводе, потому что за время паузы могло измениться и то, и другое.
    var isNeeded: () -> Bool = { false }

    /// Время вышло. Вызывается на главном потоке.
    var onExpire: () -> Void = {}

    var isRunning: Bool { workItem != nil }

    private let blockId: String
    private let duration: TimeInterval

    /// Часы отдельным швом: считать потраченное без них нельзя, а тесты не могут ждать бюджет
    /// целиком — им нужно уметь сказать, что время прошло.
    private let now: () -> Date

    /// Нотификации отдельным швом по той же причине, что и часы: на глобальном центре уход в фон
    /// проверить нельзя — тестовое уведомление долетело бы до блоков из тестов, идущих рядом.
    private let notificationCenter: NotificationCenter

    /// Планировщик тем же швом и по той же причине: зашитая очередь заставляла бы тесты бюджета
    /// ждать его настоящим временем — то есть спать на каждую проверку и флакать на нагруженной
    /// машине.
    private let schedule: EmbeddedBlockTimeoutScheduling

    private var workItem: DispatchWorkItem?

    /// Сколько бюджета съели прошлые отрезки ожидания.
    private var consumed: TimeInterval = 0

    /// Когда начался идущий отрезок. `nil` — отсчёт не идёт.
    private var resumedAt: Date?

    private var remaining: TimeInterval { max(0, duration - consumed) }

    init(blockId: String,
         duration: TimeInterval,
         now: @escaping () -> Date = { Date() },
         notificationCenter: NotificationCenter = .default,
         schedule: @escaping EmbeddedBlockTimeoutScheduling = { delay, work in
             DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
         }) {
        self.blockId = blockId
        self.duration = duration
        self.now = now
        self.notificationCenter = notificationCenter
        self.schedule = schedule

        notificationCenter.addObserver(self,
                                       selector: #selector(applicationDidEnterBackground),
                                       name: UIApplication.didEnterBackgroundNotification,
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(applicationWillEnterForeground),
                                       name: UIApplication.willEnterForegroundNotification,
                                       object: nil)
    }

    deinit {
        notificationCenter.removeObserver(self)
        workItem?.cancel()
    }

    /// Заводит отсчёт на остаток бюджета, если он нужен и ещё не идёт. Звать можно сколько угодно
    /// раз: лишние вызовы ничего не делают, поэтому вход в окно, возврат из фона и перезагрузка
    /// обходятся одним и тем же вызовом.
    func armIfNeeded() {
        guard workItem == nil, isNeeded() else { return }

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }

            self.workItem = nil
            self.resumedAt = nil
            // Бюджет израсходован целиком: если блок почему-то заведут снова, ждать ему уже нечего.
            self.consumed = self.duration

            Logger.common(message: "[EmbeddedBlock] Block '\(self.blockId)' timed out after \(self.duration)s of waiting",
                          category: .embeddedBlocks)
            self.onExpire()
        }

        // Работа записывается в свойство до того, как её заведут: планировщик вправе выполнить её
        // тут же, и она должна застать бюджет в согласованном состоянии.
        resumedAt = now()
        workItem = work
        schedule(remaining, work)
    }

    /// Останавливает отсчёт, запомнив потраченное. Попытку это не отменяет: `armIfNeeded()`
    /// продолжит её с остатка.
    func pause() {
        guard let resumedAt else { return }

        consumed += now().timeIntervalSince(resumedAt)
        self.resumedAt = nil
        workItem?.cancel()
        workItem = nil
    }

    /// Останавливает отсчёт и возвращает бюджет в полный: прошлая попытка кончилась — исходом или
    /// тем, что началась следующая, — и её остаток к новой отношения не имеет.
    func reset() {
        pause()
        consumed = 0
    }

    @objc
    private func applicationDidEnterBackground() {
        guard isRunning else { return }

        Logger.common(message: "[EmbeddedBlock] Block '\(blockId)' went to the background while loading, pausing the timeout",
                      category: .embeddedBlocks)
        pause()
    }

    @objc
    private func applicationWillEnterForeground() {
        armIfNeeded()
    }
}
