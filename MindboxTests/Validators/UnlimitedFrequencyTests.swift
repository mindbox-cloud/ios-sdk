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

    /// Private storage: the validator only reads it, so no need to join the serial-execution-bound suites.
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

    @Test("Unlimited passes for an in-app that was already shown")
    func passesWhenAlreadyShown() {
        let validator = makeValidator(shownDates: ["1": [Date(), Date()]])
        #expect(validator.isValid(frequency: .unlimited, id: "1"))
    }

    @Test("Once lifetime still blocks an in-app that was already shown")
    func onceLifetimeStillBlocks() {
        let validator = makeValidator(shownDates: ["1": [Date()]])
        #expect(!validator.isValid(frequency: .once(OnceFrequency(kind: .lifetime)), id: "1"))
    }
}

@Suite("Unlimited in-app and the show limits", .tags(.inAppSchedule))
struct UnlimitedFrequencyLimitsTests {

    private let restricted: InappFrequency = .once(OnceFrequency(kind: .session))

    /// Budgets live in the shared session storage — this suite leans on the target's serial execution.
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

    @Test("Unlimited waits while another in-app is on screen")
    func respectsTheOneAtATimeLock() {
        SessionTemporaryStorage.shared.isPresentingInAppMessage = true

        #expect(!makeValidator().canPresentInApp(isPriority: false, frequency: .unlimited, id: "1"))
    }

    @Test("A block's budgets are checked without the one-at-a-time lock")
    func showBudgetsIgnoreTheScreenLock() {
        SessionTemporaryStorage.shared.isPresentingInAppMessage = true
        let validator = makeValidator()

        #expect(validator.isWithinShowBudgets(isPriority: false, frequency: restricted, id: "1"))
        #expect(!validator.canPresentInApp(isPriority: false, frequency: restricted, id: "1"))
    }

    @Test("A block is held back by a spent budget like anything else")
    func showBudgetsStillHoldBackABlock() {
        setLimits(session: 2)
        SessionTemporaryStorage.shared.sessionShownInApps = ["a", "b"]
        let validator = makeValidator()

        #expect(!validator.isWithinShowBudgets(isPriority: false, frequency: restricted, id: "1"))
        #expect(validator.isWithinShowBudgets(isPriority: false, frequency: .unlimited, id: "1"))
    }
}
