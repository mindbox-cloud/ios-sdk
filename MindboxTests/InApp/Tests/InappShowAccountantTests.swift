//
//  InappShowAccountantTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 25.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
@testable import Mindbox

@Suite("In-app show accountant", .tags(.inAppSchedule))
struct InappShowAccountantTests {

    private let tracker = InAppMessagesTrackerSpyMock()
    private let budget = InappShowBudgetMock()
    private let accountant: InappShowAccountant

    init() {
        SessionTemporaryStorage.shared.erase()
        accountant = InappShowAccountant(tracker: tracker, budget: budget)
    }

    private func show(_ frequency: InappFrequency, id: String = "inapp-1") -> InappShow {
        InappShow(inAppId: id, frequency: frequency, tags: ["campaign": "spring"], timeToDisplay: 1.5)
    }

    @Test("A show sends Inapp.Show with the time in the wire format")
    func showSendsTheEvent() {
        accountant.recordShow(show(.unlimited))

        #expect(tracker.trackViewCallCount == 1)
        #expect(tracker.lastTrackedId == "inapp-1")
        #expect(tracker.lastTimeToDisplay == "00:00:01.5000000")
    }

    @Test("A show turns the overlay's slot into a recorded show")
    func showCommitsTheOverlaySlot() {
        let frequency: InappFrequency = .once(OnceFrequency(kind: .session))

        accountant.recordShow(show(frequency))

        #expect(budget.commits == [.init(owner: .overlay, inAppId: "inapp-1", frequency: frequency)])
    }

    @Test("The budget, not the accountant, decides what an unlimited show writes")
    func unlimitedShowIsCommittedWithItsFrequency() {
        accountant.recordShow(show(.unlimited))

        #expect(budget.commits == [.init(owner: .overlay, inAppId: "inapp-1", frequency: .unlimited)])
    }

    @Test("A cooldown is handed to the budget with its frequency")
    func cooldownGoesToTheBudget() {
        accountant.recordCooldown(frequency: .once(OnceFrequency(kind: .lifetime)))

        #expect(budget.cooldowns == [.once(OnceFrequency(kind: .lifetime))])
    }

    @Test("A block show turns the place's slot into a recorded show")
    func blockShowCommitsThePlaceSlot() {
        accountant.recordBlockShow(show(.unlimited), at: "place")

        #expect(tracker.trackViewCallCount == 1)
        #expect(budget.commits == [.init(owner: .place("place"), inAppId: "inapp-1", frequency: .unlimited)])
    }

    @Test("The same in-app at a place is accounted once and gives the slot back")
    func sameInappAtPlaceIsAccountedOnce() {
        accountant.recordBlockShow(show(.unlimited), at: "place")
        accountant.recordBlockShow(show(.unlimited), at: "place")

        #expect(tracker.trackViewCallCount == 1)
        #expect(budget.commits.count == 1)
        #expect(budget.releases == [.place("place")])
    }

    @Test("Another in-app at the place is accounted")
    func anotherInappAtPlaceIsAccounted() {
        accountant.recordBlockShow(show(.unlimited, id: "inapp-1"), at: "place")
        accountant.recordBlockShow(show(.unlimited, id: "inapp-2"), at: "place")

        #expect(tracker.trackViewCallCount == 2)
        #expect(budget.commits.map(\.inAppId) == ["inapp-1", "inapp-2"])
    }

    @Test("Returning to the first in-app at the place is accounted again")
    func returningInappAtPlaceIsAccountedAgain() {
        accountant.recordBlockShow(show(.unlimited, id: "inapp-1"), at: "place")
        accountant.recordBlockShow(show(.unlimited, id: "inapp-2"), at: "place")
        accountant.recordBlockShow(show(.unlimited, id: "inapp-1"), at: "place")

        #expect(tracker.trackViewCallCount == 3)
    }

    @Test("Two places showing the same in-app are accounted independently")
    func twoPlacesAreAccountedIndependently() {
        accountant.recordBlockShow(show(.unlimited), at: "first-place")
        accountant.recordBlockShow(show(.unlimited), at: "second-place")

        #expect(tracker.trackViewCallCount == 2)
        #expect(budget.commits.map(\.owner) == [.place("first-place"), .place("second-place")])
    }

    @Test("A new session accounts the same in-app at the place again")
    func newSessionAccountsThePlaceAgain() {
        accountant.recordBlockShow(show(.unlimited), at: "place")
        SessionTemporaryStorage.shared.erase()
        accountant.recordBlockShow(show(.unlimited), at: "place")

        #expect(tracker.trackViewCallCount == 2)
    }
}
