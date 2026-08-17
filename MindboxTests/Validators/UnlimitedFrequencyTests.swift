//
//  UnlimitedFrequencyTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import Testing
@testable import Mindbox

@Suite("Unlimited in-app frequency", .tags(.inAppSchedule))
struct UnlimitedFrequencyTests {

    private struct Holder: Decodable {
        let frequency: InappFrequency?
    }

    private func decode(_ value: String) throws -> InappFrequency? {
        let json = "{\"frequency\": \(value)}"
        return try JSONDecoder().decode(Holder.self, from: Data(json.utf8)).frequency
    }

    /// A private storage instead of the shared one: the validator only reads it, so there is no need
    /// to join the suites that depend on serial execution.
    private func makeValidator(shownDates: [String: [Date]] = [:]) -> InappFrequencyValidator {
        let storage = MockPersistenceStorage()
        storage.shownDatesByInApp = shownDates
        return InappFrequencyValidator(persistenceStorage: storage)
    }

    @Test("Unlimited is parsed as its own case")
    func parsesUnlimited() throws {
        #expect(try decode(#"{"$type": "unlimited"}"#) == .unlimited)
    }

    @Test("Unlimited passes for an in-app that was never shown")
    func passesWhenNeverShown() {
        #expect(makeValidator().isValid(frequency: .unlimited, id: "1"))
    }

    /// The property that matters: unlimited never consults the show history, which is what lets the
    /// same in-app be resolved again and again.
    @Test("Unlimited passes for an in-app that was already shown")
    func passesWhenAlreadyShown() {
        let validator = makeValidator(shownDates: ["1": [Date(), Date()]])
        #expect(validator.isValid(frequency: .unlimited, id: "1"))
    }

    /// The pair to the case above: adding a permissive frequency must not make the restrictive ones
    /// permissive too.
    @Test("Once lifetime still blocks an in-app that was already shown")
    func onceLifetimeStillBlocks() {
        let validator = makeValidator(shownDates: ["1": [Date()]])
        #expect(!validator.isValid(frequency: .once(OnceFrequency(kind: .lifetime)), id: "1"))
    }
}

/// `unlimited` is outside the show budgets in both directions: it records no show, and no recorded
/// show holds it back. Each test pairs the unlimited answer with a restricted in-app in the very same
/// state, so what changed the answer is the frequency and not the arrangement.
@Suite("Unlimited in-app and the show limits", .tags(.inAppSchedule))
struct UnlimitedFrequencyLimitsTests {

    private let restricted: InappFrequency = .once(OnceFrequency(kind: .session))

    /// The budgets are read from the shared session storage, so this suite leans on the target running
    /// its tests serially, like the others that touch it.
    init() {
        SessionTemporaryStorage.shared.erase()
    }

    private func makeValidator(shownDates: [String: [Date]] = [:],
                               lastStateChange: Date? = nil) -> InAppPresentationValidator {
        let storage = MockPersistenceStorage()
        storage.shownDatesByInApp = shownDates
        storage.lastInappStateChangeDate = lastStateChange
        return InAppPresentationValidator(persistenceStorage: storage)
    }

    private func setLimits(session: Int? = nil, day: Int? = nil, interval: String? = nil) {
        SessionTemporaryStorage.shared.inAppSettings = Settings.InAppSettings(maxInappsPerSession: session,
                                                                             maxInappsPerDay: day,
                                                                             minIntervalBetweenShows: interval)
    }

    @Test("Unlimited shows with the session limit already spent")
    func ignoresSessionLimit() {
        setLimits(session: 2)
        SessionTemporaryStorage.shared.sessionShownInApps = ["a", "b"]
        let validator = makeValidator()

        #expect(validator.canPresentInApp(isPriority: false, frequency: .unlimited, id: "1"))
        #expect(!validator.canPresentInApp(isPriority: false, frequency: restricted, id: "1"))
    }

    @Test("Unlimited shows with the daily limit already spent")
    func ignoresDailyLimit() {
        setLimits(day: 2)
        let validator = makeValidator(shownDates: ["a": [Date()], "b": [Date()]])

        #expect(validator.canPresentInApp(isPriority: false, frequency: .unlimited, id: "1"))
        #expect(!validator.canPresentInApp(isPriority: false, frequency: restricted, id: "1"))
    }

    @Test("Unlimited shows before the minimum interval has elapsed")
    func ignoresMinimumInterval() {
        setLimits(interval: "00:05:00")
        let validator = makeValidator(lastStateChange: Date())

        #expect(validator.canPresentInApp(isPriority: false, frequency: .unlimited, id: "1"))
        #expect(!validator.canPresentInApp(isPriority: false, frequency: restricted, id: "1"))
    }

    @Test("Unlimited shows with every budget spent at once")
    func ignoresAllLimitsTogether() {
        setLimits(session: 2, day: 2, interval: "00:05:00")
        SessionTemporaryStorage.shared.sessionShownInApps = ["a", "b"]
        let validator = makeValidator(shownDates: ["a": [Date()], "b": [Date()]], lastStateChange: Date())

        #expect(validator.canPresentInApp(isPriority: false, frequency: .unlimited, id: "1"))
        #expect(!validator.canPresentInApp(isPriority: false, frequency: restricted, id: "1"))
    }

    /// The one thing being unlimited does not buy. Two in-apps cannot share the screen, so the lock is
    /// not a budget to be exempt from — a priority in-app waits for it too.
    @Test("Unlimited waits while another in-app is on screen")
    func respectsTheOneAtATimeLock() {
        SessionTemporaryStorage.shared.isPresentingInAppMessage = true

        #expect(!makeValidator().canPresentInApp(isPriority: false, frequency: .unlimited, id: "1"))
    }

    /// And the reason the validator was split in two: the lock is the one check a block does not run.
    /// A block is drawn inside the host's layout and shares it with everything, so a snackbar on screen
    /// is no reason to leave a hole in someone else's list.
    @Test("A block's budgets are checked without the one-at-a-time lock")
    func showBudgetsIgnoreTheScreenLock() {
        SessionTemporaryStorage.shared.isPresentingInAppMessage = true
        let validator = makeValidator()

        #expect(validator.isWithinShowBudgets(isPriority: false, frequency: restricted, id: "1"))
        #expect(!validator.canPresentInApp(isPriority: false, frequency: restricted, id: "1"))
    }

    /// The other half of the split: everything that is not the lock still applies to a block.
    @Test("A block is held back by a spent budget like anything else")
    func showBudgetsStillHoldBackABlock() {
        setLimits(session: 2)
        SessionTemporaryStorage.shared.sessionShownInApps = ["a", "b"]
        let validator = makeValidator()

        #expect(!validator.isWithinShowBudgets(isPriority: false, frequency: restricted, id: "1"))
        #expect(validator.isWithinShowBudgets(isPriority: false, frequency: .unlimited, id: "1"))
    }
}
