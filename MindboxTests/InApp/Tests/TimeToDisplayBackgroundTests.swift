//
//  TimeToDisplayBackgroundTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 27.03.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import UIKit
@testable import Mindbox

// The stopwatch listens on the main queue; posting from it keeps the delivery synchronous, so the
// clock is read after the observer ran and not before.
@Suite("TimeToDisplay excludes background time")
@MainActor
struct TimeToDisplayBackgroundTests {

    private var scheduleManager: InappScheduleManager
    private var presentationManagerMock: InAppPresentationManagerMock
    private var trackerMock: InAppMessagesTrackerSpyMock
    private let notificationCenter = NotificationCenter()
    private let clock = TestClock()

    init() {
        TestConfiguration.configure()

        presentationManagerMock = InAppPresentationManagerMock()
        trackerMock = InAppMessagesTrackerSpyMock()

        scheduleManager = InappScheduleManager(
            presentationManager: presentationManagerMock,
            budget: DI.injectOrFail(InappShowBudgeting.self),
            accountant: InappShowAccountant(tracker: trackerMock, budget: DI.injectOrFail(InappShowBudgeting.self)),
            failureManager: InappShowFailureManagerMock()
        )

        SessionTemporaryStorage.shared.erase()
    }

    // MARK: - Tests

    @Test("No background — timeToDisplay is the elapsed time", .tags(.inAppSchedule))
    func timeToDisplay_noBackground_matchesElapsedTime() throws {
        let stopwatch = ForegroundStopwatch(notificationCenter: notificationCenter, now: { clock.now })
        let inapp = createInAppFormData(id: "no-bg")

        clock.advance(0.5)

        scheduleManager.presentInapp(inapp, stopwatch: stopwatch, processingDuration: 0)
        presentationManagerMock.receivedOnPresent?()

        #expect(try parseTimeToDisplay() == 0.5)
    }

    @Test("Single background session — background time is excluded from timeToDisplay", .tags(.inAppSchedule))
    func timeToDisplay_singleBackground_excludesBackgroundTime() throws {
        let stopwatch = ForegroundStopwatch(notificationCenter: notificationCenter, now: { clock.now })
        let inapp = createInAppFormData(id: "single-bg")

        clock.advance(0.25)
        enterBackground(for: 2)
        clock.advance(0.25)

        scheduleManager.presentInapp(inapp, stopwatch: stopwatch, processingDuration: 0)
        presentationManagerMock.receivedOnPresent?()

        #expect(try parseTimeToDisplay() == 0.5)
    }

    @Test("Multiple background sessions — all background time excluded, all foreground time counted", .tags(.inAppSchedule))
    func timeToDisplay_multipleBackgrounds_onlyForegroundCounted() throws {
        let stopwatch = ForegroundStopwatch(notificationCenter: notificationCenter, now: { clock.now })
        let inapp = createInAppFormData(id: "multi-bg")

        clock.advance(0.25)
        enterBackground(for: 2)
        clock.advance(0.25)
        enterBackground(for: 4)
        clock.advance(0.25)

        scheduleManager.presentInapp(inapp, stopwatch: stopwatch, processingDuration: 0)
        presentationManagerMock.receivedOnPresent?()

        #expect(try parseTimeToDisplay() == 0.75)
    }

    // MARK: - Helpers

    private func enterBackground(for seconds: TimeInterval) {
        notificationCenter.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        clock.advance(seconds)
        notificationCenter.post(name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    private func parseTimeToDisplay() throws -> Double {
        let timeToDisplayString = try #require(trackerMock.lastTimeToDisplay)
        let millis = try timeToDisplayString.parseTimeSpanToMillis()
        return Double(millis) / 1000.0
    }

    private func createInAppFormData(id: String) -> InAppFormData {
        let modalVariant = ModalFormVariant(content: InappFormVariantContent(background: ContentBackground(layers: []), elements: nil))
        return InAppFormData(
            inAppId: id,
            isPriority: false,
            delayTime: nil,
            imagesDict: [:],
            firstImageValue: "",
            content: .modal(modalVariant),
            frequency: .once(OnceFrequency(kind: .session))
        )
    }
}

final class InAppMessagesTrackerSpyMock: InAppMessagesTrackerProtocol {
    private(set) var trackViewCallCount = 0
    private(set) var trackTargetingCallCount = 0
    private(set) var lastTimeToDisplay: String?
    private(set) var lastTrackedId: String?
    private(set) var lastTargetedId: String?

    func trackView(id: String, timeToDisplay: String?, tags: [String: String]?) throws {
        trackViewCallCount += 1
        lastTrackedId = id
        lastTimeToDisplay = timeToDisplay
    }

    func trackClick(id: String, tags: [String: String]?) throws {}

    func trackTargeting(id: String, tags: [String: String]?) throws {
        trackTargetingCallCount += 1
        lastTargetedId = id
    }
}
