//
//  EmbeddedBlockReadyTimeoutTests.swift
//  MindboxTests
//
//  Created by vailence on 10.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
import UIKit
@testable import Mindbox

/// Ни часы, ни планировщик здесь не настоящие. Сколько бюджета «уже потрачено», тесты задают
/// подменёнными часами, а момент «время вышло» наступает по их команде. Реальным временем не
/// ждётся ничего: бюджет — это арифметика над потраченным, и проверять её секундомером значило бы
/// платить полсекунды за тест и флакать на загруженном раннере.
///
/// Отсюда же главная проверка большинства тестов — не «истёк или нет», а с какой задержкой завели
/// отсчёт: именно она и есть остаток бюджета.
///
/// Уход в фон и возврат из него идут через свой центр нотификаций у каждого стенда: на глобальном
/// такое уведомление долетело бы до блоков из тестов, идущих рядом.
private let budget: TimeInterval = 0.4

@Suite("Embedded block ready timeout", .tags(.embeddedBlocks))
@MainActor
struct EmbeddedBlockReadyTimeoutTests {

    @Test("A budget that is never paused expires on its own")
    func unpausedBudgetExpires() {
        let bed = TimeoutBed()

        bed.timeout.armIfNeeded()

        #expect(bed.scheduler.lastDelay == budget)

        bed.scheduler.fireAll()

        #expect(bed.expirations == 1)
    }

    /// Пока блока никто не ждёт, бюджет не тратится и не истекает.
    @Test("A paused budget does not expire")
    func pausedBudgetDoesNotExpire() {
        let bed = TimeoutBed()

        bed.timeout.armIfNeeded()
        bed.timeout.pause()
        bed.scheduler.fireAll()

        #expect(bed.expirations == 0)
        #expect(bed.timeout.isRunning == false)
    }

    /// Главное: пауза останавливает счёт, а не начинает его заново. Потрачено почти всё, поэтому
    /// после возобновления отсчёт заводится на крохотный остаток — а не на полный бюджет.
    @Test("Resuming continues the remaining budget instead of granting a new one")
    func resumeContinuesTheRemainder() {
        let bed = TimeoutBed()

        bed.timeout.armIfNeeded()
        bed.clock.advance(budget - 0.02)
        bed.timeout.pause()

        bed.timeout.armIfNeeded()

        #expect(isClose(bed.scheduler.lastDelay, to: 0.02))

        bed.scheduler.fireAll()

        #expect(bed.expirations == 1)
    }

    /// Ровно тот сценарий, из-за которого пауза со сбросом непригодна: пользователь, дёргающий
    /// приложение туда-обратно, не должен уметь продлевать ожидание блока бесконечно.
    @Test("Repeated pause and resume cannot stretch the budget past its duration")
    func repeatedPausesCannotStretchTheBudget() {
        let bed = TimeoutBed()

        for _ in 0..<5 {
            bed.timeout.armIfNeeded()
            bed.clock.advance(budget / 4)
            bed.timeout.pause()
        }

        #expect(bed.expirations == 0)

        // Пять отрезков по четверти — бюджет выбран целиком, и следующий завод не даёт блоку больше
        // ни секунды.
        bed.timeout.armIfNeeded()

        #expect(bed.scheduler.lastDelay == 0)

        bed.scheduler.fireAll()

        #expect(bed.expirations == 1)
    }

    /// А новая попытка — другое дело: её ждут с полного бюджета.
    @Test("Reset gives the next attempt a full budget again")
    func resetGrantsAFullBudget() {
        let bed = TimeoutBed()

        bed.timeout.armIfNeeded()
        bed.clock.advance(budget - 0.02)
        bed.timeout.reset()

        bed.timeout.armIfNeeded()

        #expect(bed.scheduler.lastDelay == budget)
    }

    @Test("Reset stops a running budget")
    func resetStopsTheCountdown() {
        let bed = TimeoutBed()

        bed.timeout.armIfNeeded()
        bed.timeout.reset()
        bed.scheduler.fireAll()

        #expect(bed.expirations == 0)
    }

    /// Бюджет нужен только пока исход неизвестен и блок на виду — это знает контейнер, и его ответ
    /// спрашивается на каждом заводе.
    @Test("A budget nobody needs is not armed at all")
    func unneededBudgetIsNotArmed() {
        let bed = TimeoutBed(isNeeded: false)

        bed.timeout.armIfNeeded()

        #expect(bed.timeout.isRunning == false)
        #expect(bed.scheduler.lastDelay == nil)

        bed.scheduler.fireAll()

        #expect(bed.expirations == 0)
    }

    // MARK: - Background

    /// Пока приложение в фоне, блока никто не ждёт — значит и бюджет тратиться не должен.
    @Test("Going to the background pauses a running budget")
    func backgroundPausesTheCountdown() {
        let bed = TimeoutBed()

        bed.timeout.armIfNeeded()
        bed.enterBackground()

        #expect(bed.timeout.isRunning == false)

        bed.scheduler.fireAll()

        #expect(bed.expirations == 0)
    }

    /// И ровно то, ради чего заведён учёт потраченного: возврат из фона продолжает бюджет с остатка,
    /// а не выдаёт его заново.
    @Test("Returning from the background continues the remaining budget")
    func foregroundContinuesTheRemainder() {
        let bed = TimeoutBed()

        bed.timeout.armIfNeeded()
        bed.clock.advance(budget - 0.02)
        bed.enterBackground()
        bed.enterForeground()

        #expect(isClose(bed.scheduler.lastDelay, to: 0.02))

        bed.scheduler.fireAll()

        #expect(bed.expirations == 1)
    }

    /// Фон, заставший блок вне отсчёта, тратить не может ничего: следующая попытка получает бюджет
    /// целиком.
    @Test("Going to the background outside a countdown consumes nothing")
    func backgroundOutsideCountdownConsumesNothing() {
        let bed = TimeoutBed()

        bed.enterBackground()
        bed.clock.advance(budget)

        bed.timeout.armIfNeeded()

        #expect(bed.scheduler.lastDelay == budget)
    }

    /// Возврат из фона к блоку, которого уже никто не ждёт, отсчёт не воскрешает: нужен ли он,
    /// решает контейнер, и его ответ спрашивается на каждом заводе.
    @Test("Returning from the background does not arm a budget nobody needs")
    func foregroundDoesNotArmAnUnneededBudget() {
        let bed = TimeoutBed(isNeeded: false)

        bed.enterForeground()

        #expect(bed.timeout.isRunning == false)
        #expect(bed.scheduler.lastDelay == nil)
    }

    // MARK: - Arming

    /// Завод идемпотентен: вход в окно, возврат из фона и перезагрузка зовут его как попало, и
    /// второй вызов не должен ставить второй отсчёт.
    @Test("Arming twice runs a single countdown")
    func armingTwiceRunsOneCountdown() {
        let bed = TimeoutBed()

        bed.timeout.armIfNeeded()
        bed.timeout.armIfNeeded()
        bed.scheduler.fireAll()

        // Завелись бы два отсчёта — истечений было бы столько же.
        #expect(bed.expirations == 1)
    }
}

/// Остаток бюджета — арифметика над `Double`, поэтому сравнивается с допуском.
private func isClose(_ value: TimeInterval?, to expected: TimeInterval) -> Bool {
    guard let value else { return false }

    return abs(value - expected) < 0.0001
}

/// Общий стенд бюджета плюс счётчик истечений: здесь бюджет проверяется сам по себе, поэтому
/// `isNeeded` задаётся тестом напрямую, а не спрашивается у контейнера.
@MainActor
private final class TimeoutBed {

    private let bed = EmbeddedBlockTimeoutBed(duration: budget)

    private(set) var expirations = 0

    var timeout: EmbeddedBlockReadyTimeout { bed.timeout }
    var clock: TestClock { bed.clock }
    var scheduler: TestScheduler { bed.scheduler }

    init(isNeeded: Bool = true) {
        bed.timeout.isNeeded = { isNeeded }
        bed.timeout.onExpire = { [weak self] in
            self?.expirations += 1
        }
    }

    func enterBackground() {
        bed.enterBackground()
    }

    func enterForeground() {
        bed.enterForeground()
    }
}
