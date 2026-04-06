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

@Suite("TimeToDisplay excludes background time")
struct TimeToDisplayBackgroundTests {

    private var scheduleManager: InappScheduleManager
    private var presentationManagerMock: InAppPresentationManagerMock
    private var trackerMock: InAppMessagesTrackerSpyMock
    private let notificationCenter = NotificationCenter()

    init() {
        TestConfiguration.configure()

        presentationManagerMock = InAppPresentationManagerMock()
        trackerMock = InAppMessagesTrackerSpyMock()

        scheduleManager = InappScheduleManager(
            presentationManager: presentationManagerMock,
            presentationValidator: DI.injectOrFail(InAppPresentationValidatorProtocol.self),
            trackingService: InAppTrackingServiceMock(),
            tracker: trackerMock,
            failureManager: InappShowFailureManagerMock()
        )

        SessionTemporaryStorage.shared.erase()
    }

    // MARK: - Tests

    @Test("No background — timeToDisplay matches real elapsed time", .tags(.inAppSchedule))
    func timeToDisplay_noBackground_matchesElapsedTime() throws {
        let stopwatch = ForegroundStopwatch(notificationCenter: notificationCenter)
        let inapp = createInAppFormData(id: "no-bg")

        Thread.sleep(forTimeInterval: 0.1)

        scheduleManager.presentInapp(inapp, stopwatch: stopwatch, processingDuration: 0)
        presentationManagerMock.receivedOnPresent?()

        let seconds = try parseTimeToDisplay()

        #expect(seconds >= 0.1, "Expected timeToDisplay >= 0.1s, got \(seconds)s")
        #expect(seconds < 0.2, "Expected timeToDisplay < 0.2s (no background time to subtract), got \(seconds)s")
    }

    @Test("Single background session — background time is excluded from timeToDisplay", .tags(.inAppSchedule))
    func timeToDisplay_singleBackground_excludesBackgroundTime() throws {
        let stopwatch = ForegroundStopwatch(notificationCenter: notificationCenter)
        let inapp = createInAppFormData(id: "single-bg")

        // ~0.05s foreground
        Thread.sleep(forTimeInterval: 0.05)

        // ~0.3s background (should be excluded)
        notificationCenter.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        Thread.sleep(forTimeInterval: 0.3)
        notificationCenter.post(name: UIApplication.willEnterForegroundNotification, object: nil)

        // ~0.05s foreground
        Thread.sleep(forTimeInterval: 0.05)

        scheduleManager.presentInapp(inapp, stopwatch: stopwatch, processingDuration: 0)
        presentationManagerMock.receivedOnPresent?()

        let seconds = try parseTimeToDisplay()

        // Foreground time: ~0.05 + ~0.05 = ~0.1s
        // Background time: ~0.3s (excluded)
        // Total wall time: ~0.4s, but timeToDisplay should be ~0.1s
        #expect(seconds >= 0.05, "Expected timeToDisplay >= 0.05s (foreground time), got \(seconds)s")
        #expect(seconds < 0.2, "Expected timeToDisplay < 0.2s (excluding ~0.3s background), got \(seconds)s")
    }

    @Test("Multiple background sessions — all background time excluded, all foreground time counted", .tags(.inAppSchedule))
    func timeToDisplay_multipleBackgrounds_onlyForegroundCounted() throws {
        let stopwatch = ForegroundStopwatch(notificationCenter: notificationCenter)
        let inapp = createInAppFormData(id: "multi-bg")

        // ~0.05s foreground
        Thread.sleep(forTimeInterval: 0.05)

        // ~0.2s background #1 (excluded)
        notificationCenter.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        Thread.sleep(forTimeInterval: 0.2)
        notificationCenter.post(name: UIApplication.willEnterForegroundNotification, object: nil)

        // ~0.05s foreground
        Thread.sleep(forTimeInterval: 0.05)

        // ~0.2s background #2 (excluded)
        notificationCenter.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        Thread.sleep(forTimeInterval: 0.2)
        notificationCenter.post(name: UIApplication.willEnterForegroundNotification, object: nil)

        // ~0.05s foreground
        Thread.sleep(forTimeInterval: 0.05)

        scheduleManager.presentInapp(inapp, stopwatch: stopwatch, processingDuration: 0)
        presentationManagerMock.receivedOnPresent?()

        let seconds = try parseTimeToDisplay()

        // Foreground time: ~0.05 + ~0.05 + ~0.05 = ~0.15s
        // Background time: ~0.2 + ~0.2 = ~0.4s (excluded)
        // Total wall time: ~0.55s, but timeToDisplay should be ~0.15s
        #expect(seconds >= 0.1, "Expected timeToDisplay >= 0.1s (foreground time), got \(seconds)s")
        #expect(seconds < 0.25, "Expected timeToDisplay < 0.25s (excluding ~0.4s background), got \(seconds)s")
    }

    // MARK: - Helpers

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
    private(set) var lastTimeToDisplay: String?
    private(set) var lastTrackedId: String?

    func trackView(id: String, timeToDisplay: String?, tags: [String: String]?) throws {
        trackViewCallCount += 1
        lastTrackedId = id
        lastTimeToDisplay = timeToDisplay
    }

    func trackClick(id: String) throws {}
}
