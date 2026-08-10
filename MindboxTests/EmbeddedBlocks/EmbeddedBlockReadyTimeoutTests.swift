//
//  EmbeddedBlockReadyTimeoutTests.swift
//  MindboxTests
//
//  Created by vailence on 10.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
@testable import Mindbox

/// Сколько бюджета «уже потрачено», тесты задают подменёнными часами, а ждут только тот огрызок,
/// который остался. Иначе проверка «продолжается остаток, а не выдаётся полный бюджет» сводилась бы
/// к измерению задержек секундомером.
///
/// Уход в фон и возврат из него здесь не проверяются: это глобальные нотификации, они долетят до
/// блоков из тестов, идущих рядом. Провод от них к паузе проверяет контейнер, у которого блок один.
private let budget: TimeInterval = 0.4

@Suite("Embedded block ready timeout", .tags(.embeddedBlocks))
@MainActor
struct EmbeddedBlockReadyTimeoutTests {

    @Test("A budget that is never paused expires on its own")
    func unpausedBudgetExpires() async throws {
        let bed = TimeoutBed()

        bed.timeout.armIfNeeded()
        try await Task.sleep(nanoseconds: 600_000_000)

        #expect(bed.expirations == 1)
    }

    /// Пока блока никто не ждёт, бюджет не тратится и не истекает.
    @Test("A paused budget does not expire")
    func pausedBudgetDoesNotExpire() async throws {
        let bed = TimeoutBed()

        bed.timeout.armIfNeeded()
        bed.timeout.pause()
        try await Task.sleep(nanoseconds: 600_000_000)

        #expect(bed.expirations == 0)
        #expect(bed.timeout.isRunning == false)
    }

    /// Главное: пауза останавливает счёт, а не начинает его заново. Потрачено почти всё, поэтому
    /// после возобновления блоку остаётся крохотный остаток — а не полный бюджет.
    @Test("Resuming continues the remaining budget instead of granting a new one")
    func resumeContinuesTheRemainder() async throws {
        let bed = TimeoutBed()

        bed.timeout.armIfNeeded()
        bed.clock.advance(budget - 0.02)
        bed.timeout.pause()

        bed.timeout.armIfNeeded()
        // Ждём меньше полного бюджета: он к этому моменту истечь ещё не успел бы.
        try await Task.sleep(nanoseconds: 200_000_000)

        #expect(bed.expirations == 1)
    }

    /// Ровно тот сценарий, из-за которого пауза со сбросом непригодна: пользователь, дёргающий
    /// приложение туда-обратно, не должен уметь продлевать ожидание блока бесконечно.
    @Test("Repeated pause and resume cannot stretch the budget past its duration")
    func repeatedPausesCannotStretchTheBudget() async throws {
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
        try await Task.sleep(nanoseconds: 200_000_000)

        #expect(bed.expirations == 1)
    }

    /// А новая попытка — другое дело: её ждут с полного бюджета.
    @Test("Reset gives the next attempt a full budget again")
    func resetGrantsAFullBudget() async throws {
        let bed = TimeoutBed()

        bed.timeout.armIfNeeded()
        bed.clock.advance(budget - 0.02)
        bed.timeout.reset()

        bed.timeout.armIfNeeded()
        try await Task.sleep(nanoseconds: 200_000_000)

        // Полного бюджета ещё не прошло — попытка жива.
        #expect(bed.expirations == 0)

        try await Task.sleep(nanoseconds: 400_000_000)

        #expect(bed.expirations == 1)
    }

    @Test("Reset stops a running budget")
    func resetStopsTheCountdown() async throws {
        let bed = TimeoutBed()

        bed.timeout.armIfNeeded()
        bed.timeout.reset()
        try await Task.sleep(nanoseconds: 600_000_000)

        #expect(bed.expirations == 0)
    }

    /// Бюджет нужен только пока исход неизвестен и блок на виду — это знает контейнер, и его ответ
    /// спрашивается на каждом заводе.
    @Test("A budget nobody needs is not armed at all")
    func unneededBudgetIsNotArmed() async throws {
        let bed = TimeoutBed(isNeeded: false)

        bed.timeout.armIfNeeded()

        #expect(bed.timeout.isRunning == false)

        try await Task.sleep(nanoseconds: 600_000_000)

        #expect(bed.expirations == 0)
    }

    /// Завод идемпотентен: вход в окно, возврат из фона и перезагрузка зовут его как попало, и
    /// второй вызов не должен ставить второй отсчёт.
    @Test("Arming twice runs a single countdown")
    func armingTwiceRunsOneCountdown() async throws {
        let bed = TimeoutBed()

        bed.timeout.armIfNeeded()
        bed.timeout.armIfNeeded()
        try await Task.sleep(nanoseconds: 600_000_000)

        #expect(bed.expirations == 1)
    }
}

/// Бюджет с управляемыми часами и счётчиком истечений.
@MainActor
private final class TimeoutBed {

    let clock = TestClock()
    let timeout: EmbeddedBlockReadyTimeout

    private(set) var expirations = 0

    init(isNeeded: Bool = true) {
        let clock = self.clock
        timeout = EmbeddedBlockReadyTimeout(blockId: "block-id",
                                            duration: budget,
                                            now: { clock.now })
        timeout.isNeeded = { isNeeded }
        timeout.onExpire = { [weak self] in
            self?.expirations += 1
        }
    }
}

/// Часы, которые идут только когда их просят.
private final class TestClock {

    private(set) var now = Date(timeIntervalSince1970: 1_000_000)

    func advance(_ seconds: TimeInterval) {
        now = now.addingTimeInterval(seconds)
    }
}
