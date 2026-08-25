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
    private let trackingService = InAppTrackingServiceMock()
    private let accountant: InappShowAccountant

    init() {
        accountant = InappShowAccountant(tracker: tracker, trackingService: trackingService)
    }

    private func show(_ frequency: InappFrequency, id: String = "inapp-1") -> InappShow {
        InappShow(inAppId: id, frequency: frequency, tags: ["campaign": "spring"], timeToDisplay: 1.5)
    }

    @Test("A show sends Inapp.Show with the time in the wire format")
    func showSendsTheEvent() {
        accountant.recordShow(show(.unlimited))

        #expect(tracker.trackViewCallCount == 1)
        #expect(tracker.lastTrackedId == "inapp-1")
        #expect(tracker.lastTimeToDisplay == "0:00:01.5000000")
    }

    @Test("A counted show writes the history")
    func countedShowWritesHistory() {
        accountant.recordShow(show(.once(OnceFrequency(kind: .session))))

        #expect(trackingService.trackInAppShownCallCount == 1)
        #expect(trackingService.lastTrackedInAppId == "inapp-1")
    }

    @Test("An unlimited show sends the event and writes nothing")
    func unlimitedShowWritesNothing() {
        accountant.recordShow(show(.unlimited))

        #expect(tracker.trackViewCallCount == 1)
        #expect(trackingService.trackInAppShownCallCount == 0)
        #expect(trackingService.saveInappStateChangeCallCount == 0)
    }

    @Test("A show does not move the cooldown by itself")
    func showLeavesCooldownAlone() {
        accountant.recordShow(show(.once(OnceFrequency(kind: .session))))

        #expect(trackingService.saveInappStateChangeCallCount == 0)
    }

    @Test("A counted cooldown is written, an unlimited one is not")
    func cooldownFollowsTheFrequency() {
        accountant.recordCooldown(frequency: .once(OnceFrequency(kind: .lifetime)))
        accountant.recordCooldown(frequency: .unlimited)

        #expect(trackingService.saveInappStateChangeCallCount == 1)
    }
}
