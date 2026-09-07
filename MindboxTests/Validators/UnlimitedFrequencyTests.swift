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

    /// Private storage: the validator only reads it, so no need to join the serial-execution-bound suites.
    private func makeValidator(shownDates: [String: [Date]] = [:]) -> InappFrequencyValidator {
        let storage = MockPersistenceStorage()
        storage.shownDatesByInApp = shownDates
        return InappFrequencyValidator(persistenceStorage: storage)
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
}
