//
//  InappShowBudgetTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 03.09.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import Testing
import MindboxLogger
@testable import Mindbox

// Budgets live on the shared session singleton — the suite leans on the target's serial execution.
@Suite("In-app show budget", .tags(.inAppSchedule))
struct InappShowBudgetTests {

    private final class Clock {
        var now = Date()
    }

    private let restricted: InappFrequency = .once(OnceFrequency(kind: .session))
    private let storage = MockPersistenceStorage()
    private let trackingService = InAppTrackingServiceMock()
    private let clock: Clock
    private let budget: InappShowBudget

    init() {
        SessionTemporaryStorage.shared.erase()
        let clock = Clock()
        self.clock = clock
        storage.shownDatesByInApp = [:]
        budget = InappShowBudget(persistenceStorage: storage, trackingService: trackingService, now: { clock.now })
    }

    private var reservations: [InappShowBudgetOwner: InappShowReservation] {
        SessionTemporaryStorage.shared.showBudget.reservations
    }

    private var shownInSession: [String] {
        SessionTemporaryStorage.shared.showBudget.shownInSession
    }

    private func setLimits(session: Int? = nil, day: Int? = nil, interval: String? = nil) {
        SessionTemporaryStorage.shared.inAppSettings = Settings.InAppSettings(maxInappsPerSession: session,
                                                                             maxInappsPerDay: day,
                                                                             minIntervalBetweenShows: interval)
    }

    private func reserve(_ owner: InappShowBudgetOwner,
                         _ inAppId: String,
                         frequency: InappFrequency? = .once(OnceFrequency(kind: .session)),
                         priority: Bool = false) -> Bool {
        budget.reserve(owner, inAppId: inAppId, isPriority: priority, frequency: frequency) != .refused
    }

    // MARK: - Reservations against the budgets

    @Test("A reservation takes a slot in the session budget")
    func reservationTakesASessionSlot() {
        setLimits(session: 1)

        #expect(reserve(.place("stories"), "a"))
        #expect(!reserve(.overlay("b"), "b"))
        #expect(Array(reservations.keys) == [.place("stories")])
    }

    @Test("A reservation counts against the daily budget")
    func reservationCountsAgainstTheDay() {
        setLimits(day: 1)

        #expect(reserve(.place("stories"), "a"))
        #expect(!reserve(.overlay("b"), "b"))
    }

    @Test("A reservation starts the minimum interval")
    func reservationStartsTheInterval() {
        setLimits(interval: "00:05:00")

        #expect(reserve(.place("stories"), "a"))
        #expect(!reserve(.overlay("b"), "b"))

        clock.now = clock.now.addingTimeInterval(301)

        #expect(reserve(.overlay("b"), "b"))
    }

    @Test("A released slot is free again")
    func releasedSlotIsFree() {
        setLimits(session: 1)
        #expect(reserve(.place("stories"), "a"))

        budget.release(.place("stories"))

        #expect(reserve(.overlay("b"), "b"))
        #expect(reservations[.place("stories")] == nil)
    }

    /// A show on request commits without a reservation; it must not touch the slot a scheduled overlay still holds.
    @Test("A commit for one overlay leaves another overlay's slot standing")
    func commitForAnotherOverlayKeepsTheSlot() {
        setLimits(session: 5)
        #expect(reserve(.overlay("a"), "a"))

        budget.commit(.overlay("b"), inAppId: "b", frequency: restricted)

        #expect(reservations[.overlay("a")]?.inAppId == "a")
        #expect(shownInSession == ["b"])
    }

    @Test("A release for one overlay leaves another overlay's slot standing")
    func releaseForAnotherOverlayKeepsTheSlot() {
        #expect(reserve(.overlay("a"), "a"))

        budget.release(.overlay("b"))

        #expect(reservations[.overlay("a")]?.inAppId == "a")
    }

    @Test("The same in-app reserved again by the same owner keeps its one slot")
    func sameInappKeepsItsSlot() {
        setLimits(session: 1)

        #expect(reserve(.place("stories"), "a"))
        #expect(reserve(.place("stories"), "a"))
        #expect(reservations.count == 1)
    }

    @Test("Another in-app reserved by the same owner replaces its slot")
    func anotherInappReplacesTheSlot() {
        setLimits(session: 1)

        #expect(reserve(.place("stories"), "a"))
        #expect(reserve(.place("stories"), "b"))
        #expect(reservations[.place("stories")]?.inAppId == "b")
        #expect(reservations.count == 1)
    }

    @Test("An owner whose replacement is refused loses its old slot too")
    func refusedReplacementDropsTheOldSlot() {
        setLimits(session: 5)
        SessionTemporaryStorage.shared.sessionShownInApps = ["b"]

        #expect(reserve(.place("stories"), "a"))
        #expect(!reserve(.place("stories"), "b"))
        #expect(reservations.isEmpty)
    }

    @Test("A priority or unlimited in-app passes spent budgets without taking a slot",
          arguments: [(InappFrequency.once(OnceFrequency(kind: .session)), true), (.unlimited, false)])
    func priorityAndUnlimitedTakeNoSlot(frequency: InappFrequency, priority: Bool) {
        setLimits(session: 1, day: 1, interval: "00:05:00")
        SessionTemporaryStorage.shared.sessionShownInApps = ["x"]
        storage.shownDatesByInApp = ["x": [clock.now]]
        storage.lastInappStateChangeDate = clock.now

        #expect(budget.reserve(.overlay("a"), inAppId: "a", isPriority: priority, frequency: frequency) == .notNeeded)
        #expect(reservations.isEmpty)
    }

    @Test("A spent frequency refuses the reservation")
    func spentFrequencyRefuses() {
        storage.shownDatesByInApp = ["a": [clock.now]]

        #expect(!reserve(.place("stories"), "a", frequency: .once(OnceFrequency(kind: .lifetime))))
        #expect(reservations.isEmpty)
    }

    @Test("A missing or unknown frequency refuses the reservation", arguments: [nil, InappFrequency.unknown])
    func missingFrequencyRefuses(frequency: InappFrequency?) {
        #expect(!reserve(.place("stories"), "a", frequency: frequency))
    }

    @Test("Concurrent reservations at a limit of one admit exactly one")
    func concurrentReservationsAdmitOne() {
        setLimits(session: 1)
        @Locked var admitted = 0

        DispatchQueue.concurrentPerform(iterations: 32) { index in
            if reserve(.place("place-\(index)"), "inapp-\(index)") {
                $admitted.mutate { $0 += 1 }
            }
        }

        #expect(admitted == 1)
        #expect(reservations.count == 1)
    }

    // MARK: - Turning a slot into a show

    @Test("A commit turns the slot into a recorded show")
    func commitRecordsTheShow() {
        #expect(reserve(.place("stories"), "a"))

        budget.commit(.place("stories"), inAppId: "a", frequency: restricted)

        #expect(reservations.isEmpty)
        #expect(shownInSession == ["a"])
        #expect(trackingService.trackInAppShownCallCount == 1)
        #expect(trackingService.lastTrackedInAppId == "a")
        #expect(trackingService.saveInappStateChangeCallCount == 1)
    }

    @Test("A committed unlimited show records nothing")
    func unlimitedCommitRecordsNothing() {
        budget.commit(.overlay("a"), inAppId: "a", frequency: .unlimited)

        #expect(shownInSession.isEmpty)
        #expect(trackingService.trackInAppShownCallCount == 0)
        #expect(trackingService.saveInappStateChangeCallCount == 0)
    }

    @Test("A commit without a reservation still records the show")
    func commitWithoutReservationRecords() {
        budget.commit(.overlay("a"), inAppId: "a", frequency: restricted)

        #expect(shownInSession == ["a"])
        #expect(trackingService.trackInAppShownCallCount == 1)
    }

    @Test("A committed show keeps holding the budget")
    func committedShowHoldsTheBudget() {
        setLimits(session: 1)
        #expect(reserve(.place("stories"), "a"))

        budget.commit(.place("stories"), inAppId: "a", frequency: restricted)

        #expect(!reserve(.overlay("b"), "b"))
    }

    @Test("A cooldown is written for a counted frequency only")
    func cooldownFollowsTheFrequency() {
        budget.recordCooldown(frequency: .once(OnceFrequency(kind: .lifetime)))
        budget.recordCooldown(frequency: .unlimited)

        #expect(trackingService.saveInappStateChangeCallCount == 1)
    }

    @Test("A new session drops every reservation")
    func newSessionDropsReservations() {
        #expect(reserve(.place("stories"), "a"))

        SessionTemporaryStorage.shared.erase()

        #expect(reservations.isEmpty)
    }

    // MARK: - The budget rules

    @Test("A session limit of zero or below means no limit", arguments: [0, -1])
    func nonPositiveSessionLimitIsNoLimit(limit: Int) {
        setLimits(session: limit)
        SessionTemporaryStorage.shared.sessionShownInApps = ["a", "b"]

        #expect(reserve(.overlay("c"), "c"))
    }

    @Test("A daily limit of zero or below means no limit", arguments: [0, -1])
    func nonPositiveDailyLimitIsNoLimit(limit: Int) {
        setLimits(day: limit)
        storage.shownDatesByInApp = ["a": [clock.now], "b": [clock.now]]

        #expect(reserve(.overlay("c"), "c"))
    }

    @Test("Only today's shows count against the daily budget")
    func onlyTodayCountsAgainstTheDay() {
        setLimits(day: 2)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: clock.now) ?? clock.now
        storage.shownDatesByInApp = ["a": [yesterday], "b": [yesterday], "c": [Date(timeIntervalSince1970: 0)]]

        #expect(reserve(.overlay("d"), "d"))
    }

    @Test("Every show of one in-app today counts against the daily budget")
    func everyShowTodayCounts() {
        setLimits(day: 2)
        storage.shownDatesByInApp = ["a": [clock.now, clock.now, clock.now]]

        #expect(!reserve(.overlay("b"), "b"))
    }

    @Test("An unset, zero, invalid or negative interval means no interval",
          arguments: [nil, "00:00:00", "invalid_format", "-00:05:00"])
    func degenerateIntervalIsNoInterval(interval: String?) {
        setLimits(interval: interval)
        storage.lastInappStateChangeDate = clock.now

        #expect(reserve(.overlay("a"), "a"))
    }

    @Test("The interval counts from the last recorded show")
    func intervalCountsFromTheLastShow() {
        setLimits(interval: "00:00:10")
        storage.lastInappStateChangeDate = clock.now.addingTimeInterval(-5)

        #expect(!reserve(.overlay("a"), "a"))

        storage.lastInappStateChangeDate = clock.now.addingTimeInterval(-11)

        #expect(reserve(.overlay("a"), "a"))
    }
}
