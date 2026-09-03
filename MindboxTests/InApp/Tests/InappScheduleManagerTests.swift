//
//  InappScheduleManagerTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 04.07.2025.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import Testing
import MindboxLogger
import QuartzCore
import UIKit
@testable import Mindbox

@Suite("In-app schedule manager tests")
struct InappScheduleManagerTests {

    private var scheduleManager: InappScheduleManager
    private var presentationManagerMock: InAppPresentationManagerMock
    private var trackingServiceMock: InAppTrackingServiceMock
    private var failureManagerMock: InappShowFailureManagerMock
    private var budget: InappShowBudget

    init() {
        TestConfiguration.configure()

        presentationManagerMock = InAppPresentationManagerMock()
        trackingServiceMock = InAppTrackingServiceMock()
        failureManagerMock = InappShowFailureManagerMock()
        budget = InappShowBudget(persistenceStorage: DI.injectOrFail(PersistenceStorage.self), trackingService: trackingServiceMock)

        scheduleManager = InappScheduleManager(
            presentationManager: presentationManagerMock,
            budget: budget,
            accountant: InappShowAccountant(tracker: DI.injectOrFail(InAppMessagesTracker.self), budget: budget),
            failureManager: failureManagerMock
        )

        SessionTemporaryStorage.shared.erase()
    }

    // MARK: - No delay

    @Test("In-app without delay is presented exactly once and the queue is cleaned up", .tags(.inAppSchedule))
    func scheduleInapp_noDelay_schedulesCorrectly() {
        #expect(scheduleManager.inappsByPresentationTime.isEmpty)

        let inapp = createInAppFormData(id: "1", isPriority: false, delayTime: nil)
        scheduleManager.scheduleInApp(inapp, processingDuration: 0)

        // delayTime == nil ⇒ delay 0, so the production DispatchSourceTimer is armed
        // for `.now()` and can fire and present on its own the instant the host app is
        // foregrounded, racing any "scheduled but not yet shown" inspection. That
        // intermediate state is not observable here and contradicts the no-delay
        // contract, so we assert only the deterministic end state. If the timer has not
        // already presented (e.g. host app backgrounded), drive it manually — this is
        // idempotent because showEligibleInapp removes the entry under `queue`, so the
        // in-app is presented at most once whichever path wins.
        var presentationTime: TimeInterval?
        scheduleManager.queue.sync {
            presentationTime = self.scheduleManager.inappsByPresentationTime.keys.first
        }

        if let presentationTime {
            scheduleManager.showEligibleInapp(presentationTime)
        }

        scheduleManager.queue.sync {
            #expect(self.presentationManagerMock.presentCallsCount == 1)
            #expect(self.presentationManagerMock.receivedInAppUIModel?.inAppId == inapp.inAppId)
            #expect(self.scheduleManager.inappsByPresentationTime.isEmpty)
        }
    }

    // MARK: - Small delay (logic-level, not real time)

    @Test("In-app with small delay is scheduled and presented when eligible", .tags(.inAppSchedule))
    func scheduleInApp_smallDelay_schedulesCorrectly() {
        #expect(scheduleManager.inappsByPresentationTime.isEmpty)

        let inapp = createInAppFormData(id: "1", isPriority: false, delayTime: "00:00:02")
        scheduleManager.scheduleInApp(inapp, processingDuration: 0)

        var presentationTime: TimeInterval?

        scheduleManager.queue.sync {
            #expect(self.scheduleManager.inappsByPresentationTime.count == 1)
            presentationTime = self.scheduleManager.inappsByPresentationTime.keys.first

            let storedInapp = self.scheduleManager.inappsByPresentationTime.values.first?.first?.inapp
            #expect(storedInapp?.inAppId == inapp.inAppId)
            #expect(self.presentationManagerMock.presentCallsCount == 0)
        }

        guard let time = presentationTime else {
            Issue.record("Expected presentationTime to be set")
            return
        }

        scheduleManager.showEligibleInapp(time)

        scheduleManager.queue.sync {
            #expect(self.presentationManagerMock.presentCallsCount == 1)
            #expect(self.presentationManagerMock.receivedInAppUIModel?.inAppId == inapp.inAppId)
            #expect(self.scheduleManager.inappsByPresentationTime.isEmpty)
        }
    }

    // MARK: - Multiple in-apps with different times

    @Test("Multiple in-apps with different delays schedule correctly and only earliest is shown", .tags(.inAppSchedule))
    func scheduleMultipleInapp_smallDelay_schedulesCorrectly() {
        #expect(scheduleManager.inappsByPresentationTime.isEmpty)

        let inapp1 = createInAppFormData(id: "1", isPriority: false, delayTime: "00:00:02")
        let inapp2 = createInAppFormData(id: "2", isPriority: false, delayTime: "00:00:03")
        let inapp3 = createInAppFormData(id: "3", isPriority: true, delayTime: "00:00:04")

        scheduleManager.scheduleInApp(inapp1, processingDuration: 0)
        scheduleManager.scheduleInApp(inapp2, processingDuration: 0)
        scheduleManager.scheduleInApp(inapp3, processingDuration: 0)

        var entries: [(time: TimeInterval, inappId: String)] = []

        scheduleManager.queue.sync {
            #expect(self.scheduleManager.inappsByPresentationTime.count == 3)
            #expect(self.presentationManagerMock.presentCallsCount == 0)

            for (time, scheduled) in self.scheduleManager.inappsByPresentationTime {
                guard let first = scheduled.first else {
                    Issue.record("Expected at least one scheduled in-app for time \(time)")
                    continue
                }
                entries.append((time: time, inappId: first.inapp.inAppId))
            }
        }

        #expect(entries.count == 3)

        let earliest = entries.min { $0.time < $1.time }
        #expect(earliest?.inappId == inapp1.inAppId)

        let sortedTimes = entries.map { $0.time }.sorted()
        for time in sortedTimes {
            scheduleManager.showEligibleInapp(time)
        }

        scheduleManager.queue.sync {
            #expect(self.scheduleManager.inappsByPresentationTime.isEmpty)
            #expect(self.presentationManagerMock.presentCallsCount == 1)
            #expect(self.presentationManagerMock.receivedInAppUIModel?.inAppId == inapp1.inAppId)
        }
    }

    @Test("A delayed in-app whose time comes while another is on screen is dropped, closing that one does not show it", .tags(.inAppSchedule))
    func scheduleInapp_missedMomentBehindAnotherInapp_isDropped() throws {
        let onScreen = createInAppFormData(id: "1", isPriority: false, delayTime: "00:00:02")
        let late = createInAppFormData(id: "2", isPriority: false, delayTime: "00:00:02")
        scheduleManager.scheduleInApp(onScreen, processingDuration: 0)
        let onScreenTime = try #require(scheduleManager.queue.sync { scheduleManager.inappsByPresentationTime.keys.first })
        scheduleManager.showEligibleInapp(onScreenTime)
        scheduleManager.queue.sync {
            #expect(self.presentationManagerMock.receivedInAppUIModel?.inAppId == onScreen.inAppId)
        }

        scheduleManager.scheduleInApp(late, processingDuration: 0)
        let lateTime = try #require(scheduleManager.queue.sync { scheduleManager.inappsByPresentationTime.keys.first })
        scheduleManager.showEligibleInapp(lateTime)
        scheduleManager.queue.sync {
            #expect(self.presentationManagerMock.presentCallsCount == 1)
            #expect(self.scheduleManager.inappsByPresentationTime.isEmpty)
        }

        presentationManagerMock.dismissActiveInApp()

        scheduleManager.queue.sync {
            #expect(self.presentationManagerMock.presentCallsCount == 1)
        }
        #expect(!SessionTemporaryStorage.shared.isPresentingInAppMessage)
    }

    // MARK: - Records deletion

    @Test("Scheduled entries are removed after in-app is shown", .tags(.inAppSchedule))
    func scheduleInapp_successShow_recordsDeleted() {
        #expect(scheduleManager.inappsByPresentationTime.isEmpty)

        let inapp = createInAppFormData(id: "1", isPriority: false, delayTime: "00:00:02")
        scheduleManager.scheduleInApp(inapp, processingDuration: 0)

        var presentationTime: TimeInterval?

        scheduleManager.queue.sync {
            #expect(!self.scheduleManager.inappsByPresentationTime.isEmpty)
            presentationTime = self.scheduleManager.inappsByPresentationTime.keys.first
        }

        guard let time = presentationTime else {
            Issue.record("Expected presentationTime to be set")
            return
        }

        scheduleManager.showEligibleInapp(time)

        scheduleManager.queue.sync {
            #expect(self.scheduleManager.inappsByPresentationTime.isEmpty)
        }
    }

    /// The delay keeps the manager's own timer out of the test.
    @Test("Eligible in-app cleanup leaves the failure buffer alone", .tags(.inAppSchedule))
    func showEligibleInapp_leavesFailuresAlone() {
        let inapp = createInAppFormData(id: "keep-failures", isPriority: false, delayTime: "00:01:00")
        scheduleManager.scheduleInApp(inapp, processingDuration: 0)

        var presentationTime: TimeInterval?
        scheduleManager.queue.sync {
            presentationTime = self.scheduleManager.inappsByPresentationTime.keys.first
        }

        guard let presentationTime else {
            Issue.record("Expected presentationTime to be set")
            return
        }

        scheduleManager.showEligibleInapp(presentationTime)

        scheduleManager.queue.sync {
            #expect(self.failureManagerMock.sendFailuresCallCount == 0)
            #expect(self.scheduleManager.inappsByPresentationTime.isEmpty)
        }
    }

    // MARK: - Invalid / zero delay

    @Test("Invalid delay string falls back to zero and in-app is presented", .tags(.inAppSchedule))
    func scheduleInapp_withInvalidDelayTime_usesDefaultDelay() {
        let inapp = createInAppFormData(id: "1", isPriority: false, delayTime: "invalid_time")
        scheduleManager.scheduleInApp(inapp, processingDuration: 0)

        // An invalid delay string falls back to 0, so the timer can auto-fire and
        // present immediately, racing inspection — see scheduleInapp_noDelay_schedulesCorrectly.
        // Drive presentation only if the timer has not already done so.
        var presentationTime: TimeInterval?
        scheduleManager.queue.sync {
            presentationTime = self.scheduleManager.inappsByPresentationTime.keys.first
        }

        if let presentationTime {
            scheduleManager.showEligibleInapp(presentationTime)
        }

        scheduleManager.queue.sync {
            #expect(self.presentationManagerMock.presentCallsCount == 1)
            #expect(self.presentationManagerMock.receivedInAppUIModel?.inAppId == inapp.inAppId)
            #expect(self.scheduleManager.inappsByPresentationTime.isEmpty)
        }
    }

    @Test("Zero delay is treated as immediate and in-app is presented", .tags(.inAppSchedule))
    func scheduleInapp_withZeroDelay_schedulesCorrectly() {
        let inapp = createInAppFormData(id: "1", isPriority: false, delayTime: "00:00:00")
        scheduleManager.scheduleInApp(inapp, processingDuration: 0)

        // Zero delay ⇒ the timer can auto-fire and present immediately, racing
        // inspection — see scheduleInapp_noDelay_schedulesCorrectly. Drive presentation
        // only if the timer has not already done so.
        var presentationTime: TimeInterval?
        scheduleManager.queue.sync {
            presentationTime = self.scheduleManager.inappsByPresentationTime.keys.first
        }

        if let presentationTime {
            scheduleManager.showEligibleInapp(presentationTime)
        }

        scheduleManager.queue.sync {
            #expect(self.presentationManagerMock.presentCallsCount == 1)
            #expect(self.presentationManagerMock.receivedInAppUIModel?.inAppId == inapp.inAppId)
            #expect(self.scheduleManager.inappsByPresentationTime.isEmpty)
        }
    }

    // MARK: - Large delay

    @Test("In-app with large delay is scheduled at expected time", .tags(.inAppSchedule))
    func scheduleInApp_withLargeDelay_schedulesCorrectly() {
        #expect(scheduleManager.inappsByPresentationTime.isEmpty)

        let inapp = createInAppFormData(id: "1", isPriority: false, delayTime: "01:00:00")
        let start = Date().timeIntervalSince1970

        scheduleManager.scheduleInApp(inapp, processingDuration: 0)

        var scheduledTime: TimeInterval?

        scheduleManager.queue.sync {
            #expect(self.scheduleManager.inappsByPresentationTime.count == 1)
            scheduledTime = self.scheduleManager.inappsByPresentationTime.keys.first

            let scheduledInapp = self.scheduleManager.inappsByPresentationTime.values.first?.first?.inapp
            #expect(scheduledInapp?.inAppId == inapp.inAppId)
        }

        guard let time = scheduledTime else {
            Issue.record("Expected scheduledTime to be set")
            return
        }

        let oneHour: TimeInterval = 3600
        let tolerance: TimeInterval = 1

        #expect(time >= start + oneHour - tolerance)
        #expect(time <= start + oneHour + tolerance)
    }

    // MARK: - Priority selection

    @Test("When multiple in-apps share the same time, priority one is shown", .tags(.inAppSchedule))
    func multipleInAppsOnSameTime_schedulesCorrectly_shownSecond() {
        #expect(scheduleManager.inappsByPresentationTime.isEmpty)

        let inapp1 = createInAppFormData(id: "1", isPriority: false, delayTime: "01:00:00")
        let inapp2 = createInAppFormData(id: "2", isPriority: true, delayTime: "01:00:00")
        let inapp3 = createInAppFormData(id: "3", isPriority: false, delayTime: "01:00:00")

        scheduleManager.scheduleInApp(inapp1, processingDuration: 0)

        var presentationTime: TimeInterval?

        scheduleManager.queue.sync {
            guard
                let entry = self.scheduleManager.inappsByPresentationTime.first,
                let existingScheduled = entry.value.first
            else {
                Issue.record("Expected one scheduled in-app")
                return
            }

            presentationTime = entry.key

            let scheduledInapp1 = ScheduledInapp(inapp: inapp1, timer: existingScheduled.timer, processingDuration: 0)
            let scheduledInapp2 = ScheduledInapp(inapp: inapp2, timer: existingScheduled.timer, processingDuration: 0)
            let scheduledInapp3 = ScheduledInapp(inapp: inapp3, timer: existingScheduled.timer, processingDuration: 0)

            self.scheduleManager.inappsByPresentationTime[entry.key] = [
                scheduledInapp1,
                scheduledInapp2,
                scheduledInapp3
            ]
        }

        guard let time = presentationTime else {
            Issue.record("Expected presentationTime to be set")
            return
        }

        scheduleManager.showEligibleInapp(time)

        scheduleManager.queue.sync {
            #expect(self.scheduleManager.inappsByPresentationTime.isEmpty)
            #expect(self.presentationManagerMock.presentCallsCount == 1)
            #expect(self.presentationManagerMock.receivedInAppUIModel?.inAppId == inapp2.inAppId)
        }
    }
    
    @Test("In-app success callback leaves the failure buffer alone", .tags(.inAppSchedule))
    func presentInapp_onPresented_leavesFailuresAlone() {
        let inapp = createInAppFormData(id: "success-id", isPriority: false, delayTime: nil)

        scheduleManager.presentInapp(inapp, stopwatch: ForegroundStopwatch())
        #expect(presentationManagerMock.presentCallsCount == 1)

        presentationManagerMock.receivedOnPresent?()
        #expect(failureManagerMock.sendFailuresCallCount == 0)
        #expect(failureManagerMock.addFailureCallCount == 0)
    }
    
    @Test("In-app error callback sends buffered failures", .tags(.inAppSchedule))
    func presentInapp_onError_sendsFailures() {
        let inapp = createInAppFormData(id: "error-id", isPriority: false, delayTime: nil)

        scheduleManager.presentInapp(inapp, stopwatch: ForegroundStopwatch())
        #expect(presentationManagerMock.presentCallsCount == 1)
        #expect(failureManagerMock.sendFailuresCallCount == 0)

        presentationManagerMock.receivedOnError?(.failedToLoadWindow)
        #expect(failureManagerMock.sendFailuresCallCount == 1)
    }

    @Test("In-app error callback propagates the in-app tags into the show failure", .tags(.inAppSchedule, .inAppTags))
    func presentInapp_onError_propagatesTags() {
        let tags = ["templateType": "Modal"]
        let inapp = createInAppFormData(id: "error-tags-id", isPriority: false, delayTime: nil, tags: tags)

        scheduleManager.presentInapp(inapp, stopwatch: ForegroundStopwatch())
        presentationManagerMock.receivedOnError?(.failedToLoadWindow)

        #expect(failureManagerMock.addFailureCalls.first?.tags == tags)
    }

    @Test("In-app error callback maps error to show failure payload", .tags(.inAppSchedule))
    func presentInapp_onError_mapsToFailureReasonAndDetails() {
        let cases: [(InAppPresentationError, InAppShowFailureReason, String)] = [
            (.failedToLoadImages, .presentationFailed, "[InAppPresentationError] Failed to load images."),
            (.failedToLoadWindow, .presentationFailed, "[InAppPresentationError] Failed to load window."),
            (.failed("presentation-failed-details"), .presentationFailed, "presentation-failed-details"),
            (.webviewLoadFailed("webview-load-details"), .webviewLoadFailed, "webview-load-details"),
            (.webviewPresentationFailed("webview-presentation-details"), .webviewPresentationFailed, "webview-presentation-details")
        ]

        for (index, testCase) in cases.enumerated() {
            let (error, expectedReason, expectedDetails) = testCase
            let inapp = createInAppFormData(id: "error-map-\(index)", isPriority: false, delayTime: nil)

            scheduleManager.presentInapp(inapp, stopwatch: ForegroundStopwatch())
            presentationManagerMock.receivedOnError?(error)

            #expect(failureManagerMock.addFailureCallCount == index + 1)
            #expect(failureManagerMock.sendFailuresCallCount == index + 1)

            let call = failureManagerMock.addFailureCalls[index]
            #expect(call.inappId == inapp.inAppId)
            #expect(call.reason == expectedReason)
            #expect(call.details == expectedDetails)
        }
    }

    @Test("In-app error callback resets presenting flag", .tags(.inAppSchedule))
    func presentInapp_onError_resetsPresentingFlag() {
        let inapp = createInAppFormData(id: "error-reset-flag", isPriority: false, delayTime: nil)

        scheduleManager.presentInapp(inapp, stopwatch: ForegroundStopwatch())
        #expect(SessionTemporaryStorage.shared.isPresentingInAppMessage)

        presentationManagerMock.receivedOnError?(.failed("any-error"))
        #expect(!SessionTemporaryStorage.shared.isPresentingInAppMessage)
    }

    @Test("In-app error callback is handled once per presentation", .tags(.inAppSchedule))
    func presentInapp_onError_isSingleShot() {
        let inapp = createInAppFormData(id: "single-shot-id", isPriority: false, delayTime: nil)

        scheduleManager.presentInapp(inapp, stopwatch: ForegroundStopwatch())

        presentationManagerMock.receivedOnError?(.failed("first-error"))
        presentationManagerMock.receivedOnError?(.failed("second-error"))

        #expect(failureManagerMock.addFailureCallCount == 1)
        #expect(failureManagerMock.sendFailuresCallCount == 1)
        #expect(failureManagerMock.addFailureCalls.first?.details == "first-error")
    }

    // MARK: - A show on request

    private func makeSpiedManager(tracker: InAppMessagesTrackerSpyMock) -> InappScheduleManager {
        InappScheduleManager(
            presentationManager: presentationManagerMock,
            budget: budget,
            accountant: InappShowAccountant(tracker: tracker, budget: budget),
            failureManager: failureManagerMock
        )
    }

    private func showNowAndAwaitMainQueue(_ manager: InappScheduleManager,
                                          _ inapp: InAppFormData,
                                          processingDuration: TimeInterval = 0) async {
        manager.showInAppNow(inapp, processingDuration: processingDuration) { _ in }
        // showInAppNow takes two main-queue turns: close the active overlay, then present.
        for _ in 0..<2 {
            await withCheckedContinuation { continuation in
                DispatchQueue.main.async { continuation.resume() }
            }
        }
    }

    @Test("An unlimited show on request sends the event but records nothing", .tags(.inAppSchedule))
    func showInAppNow_unlimitedRecordsNothing() async {
        let trackerSpy = InAppMessagesTrackerSpyMock()
        let manager = makeSpiedManager(tracker: trackerSpy)
        let inapp = createInAppFormData(id: "direct-1", isPriority: false, delayTime: nil, frequency: .unlimited)

        await showNowAndAwaitMainQueue(manager, inapp)

        #expect(presentationManagerMock.presentCallsCount == 1)
        #expect(SessionTemporaryStorage.shared.isPresentingInAppMessage)

        presentationManagerMock.receivedOnPresent?()
        presentationManagerMock.receivedOnPresentationCompleted?()

        #expect(trackerSpy.trackViewCallCount == 1)
        #expect(trackerSpy.lastTrackedId == "direct-1")
        #expect(trackingServiceMock.trackInAppShownCallCount == 0)
        #expect(trackingServiceMock.saveInappStateChangeCallCount == 0)
        #expect(!SessionTemporaryStorage.shared.isPresentingInAppMessage)
    }

    @Test("A non-unlimited show on request records like a trigger show", .tags(.inAppSchedule))
    func showInAppNow_nonUnlimitedRecords() async {
        let trackerSpy = InAppMessagesTrackerSpyMock()
        let manager = makeSpiedManager(tracker: trackerSpy)
        let inapp = createInAppFormData(id: "direct-once", isPriority: false, delayTime: nil)

        await showNowAndAwaitMainQueue(manager, inapp)
        presentationManagerMock.receivedOnPresent?()

        #expect(trackingServiceMock.trackInAppShownCallCount == 1)
        #expect(trackingServiceMock.saveInappStateChangeCallCount == 1)

        presentationManagerMock.receivedOnPresentationCompleted?()
        #expect(trackingServiceMock.saveInappStateChangeCallCount == 2)
    }

    @Test("An unlimited trigger show records nothing", .tags(.inAppSchedule))
    func presentInapp_unlimitedRecordsNothing() {
        let trackerSpy = InAppMessagesTrackerSpyMock()
        let manager = makeSpiedManager(tracker: trackerSpy)
        let inapp = createInAppFormData(id: "trigger-unlimited", isPriority: false, delayTime: nil, frequency: .unlimited)

        manager.presentInapp(inapp, stopwatch: ForegroundStopwatch())
        presentationManagerMock.receivedOnPresent?()
        presentationManagerMock.receivedOnPresentationCompleted?()

        #expect(trackerSpy.trackViewCallCount == 1)
        #expect(trackingServiceMock.trackInAppShownCallCount == 0)
        #expect(trackingServiceMock.saveInappStateChangeCallCount == 0)
    }

    @Test("A show on request sends the show and no targeting", .tags(.inAppSchedule))
    func showInAppNow_sendsOnlyTheShow() async {
        let trackerSpy = InAppMessagesTrackerSpyMock()
        let manager = makeSpiedManager(tracker: trackerSpy)
        let inapp = createInAppFormData(id: "direct-2", isPriority: false, delayTime: nil)

        await showNowAndAwaitMainQueue(manager, inapp)

        presentationManagerMock.receivedOnPresent?()

        #expect(trackerSpy.trackViewCallCount == 1)
        #expect(trackerSpy.trackTargetingCallCount == 0)
    }

    @Test("A show on request counts the time since the tap into timeToDisplay", .tags(.inAppSchedule))
    func showInAppNow_countsTheTapsProcessingTime() async throws {
        let trackerSpy = InAppMessagesTrackerSpyMock()
        let manager = makeSpiedManager(tracker: trackerSpy)
        let inapp = createInAppFormData(id: "direct-timed", isPriority: false, delayTime: nil)

        await showNowAndAwaitMainQueue(manager, inapp, processingDuration: 3)
        presentationManagerMock.receivedOnPresent?()

        let timeToDisplay = try #require(trackerSpy.lastTimeToDisplay)
        #expect(timeToDisplay.hasPrefix("00:00:03."), "expected at least the 3 s of processing, got \(timeToDisplay)")
    }

    @Test("A show on request closes the overlay already on screen", .tags(.inAppSchedule))
    func showInAppNow_closesTheActiveOverlay() async {
        let trackerSpy = InAppMessagesTrackerSpyMock()
        let manager = makeSpiedManager(tracker: trackerSpy)
        let active = createInAppFormData(id: "snackbar-on-screen", isPriority: false, delayTime: nil)
        let story = createInAppFormData(id: "tapped-story", isPriority: false, delayTime: nil)

        manager.presentInapp(active, stopwatch: ForegroundStopwatch())
        #expect(SessionTemporaryStorage.shared.isPresentingInAppMessage)

        await showNowAndAwaitMainQueue(manager, story)

        #expect(presentationManagerMock.dismissActiveCallsCount == 1)
        #expect(presentationManagerMock.presentCallsCount == 2)
        #expect(presentationManagerMock.receivedInAppUIModel?.inAppId == "tapped-story")
        #expect(SessionTemporaryStorage.shared.isPresentingInAppMessage)
    }

    @Test("A trigger show still records the show, the event and the cooldown", .tags(.inAppSchedule))
    func presentInapp_stillRecordsEverything() {
        let trackerSpy = InAppMessagesTrackerSpyMock()
        let manager = makeSpiedManager(tracker: trackerSpy)
        let inapp = createInAppFormData(id: "trigger-1", isPriority: false, delayTime: nil)

        manager.presentInapp(inapp, stopwatch: ForegroundStopwatch())
        presentationManagerMock.receivedOnPresent?()

        #expect(trackerSpy.trackViewCallCount == 1)
        #expect(trackerSpy.trackTargetingCallCount == 0)
        #expect(trackingServiceMock.trackInAppShownCallCount == 1)
        #expect(trackingServiceMock.saveInappStateChangeCallCount == 1)

        presentationManagerMock.receivedOnPresentationCompleted?()
        #expect(trackingServiceMock.saveInappStateChangeCallCount == 2)
    }

    @Test("A show on request answers success once the window is on screen", .tags(.inAppSchedule))
    func showInAppNow_answersSuccessWhenPresented() async {
        let manager = makeSpiedManager(tracker: InAppMessagesTrackerSpyMock())
        let inapp = createInAppFormData(id: "direct-answered", isPriority: false, delayTime: nil)
        var outcomes: [Result<Void, InAppPresentationError>] = []

        manager.showInAppNow(inapp, processingDuration: 0) { outcomes.append($0) }
        for _ in 0..<2 {
            await withCheckedContinuation { continuation in DispatchQueue.main.async { continuation.resume() } }
        }
        #expect(outcomes.isEmpty)

        presentationManagerMock.receivedOnPresent?()

        #expect(outcomes.count == 1)
        if case .success = outcomes.first {} else {
            Issue.record("Expected success, got \(String(describing: outcomes.first))")
        }
    }

    @Test("A show on request answers the presentation error when the show failed", .tags(.inAppSchedule))
    func showInAppNow_answersTheErrorWhenFailed() async {
        let manager = makeSpiedManager(tracker: InAppMessagesTrackerSpyMock())
        let inapp = createInAppFormData(id: "direct-failed", isPriority: false, delayTime: nil)
        var outcomes: [Result<Void, InAppPresentationError>] = []

        manager.showInAppNow(inapp, processingDuration: 0) { outcomes.append($0) }
        for _ in 0..<2 {
            await withCheckedContinuation { continuation in DispatchQueue.main.async { continuation.resume() } }
        }

        presentationManagerMock.receivedOnError?(.failed("no window"))
        presentationManagerMock.receivedOnError?(.failed("again"))

        #expect(outcomes.count == 1)
        if case .failure(.failed("no window")) = outcomes.first {} else {
            Issue.record("Expected the first presentation error, got \(String(describing: outcomes.first))")
        }
    }

    @Test("A show on request reports a presentation error", .tags(.inAppSchedule))
    func showInAppNow_reportsAnError() async {
        let trackerSpy = InAppMessagesTrackerSpyMock()
        let manager = makeSpiedManager(tracker: trackerSpy)
        let inapp = createInAppFormData(id: "direct-err", isPriority: false, delayTime: nil)

        await showNowAndAwaitMainQueue(manager, inapp)
        presentationManagerMock.receivedOnError?(.failed("no window"))

        #expect(failureManagerMock.addFailureCallCount == 1)
        #expect(failureManagerMock.sendFailuresCallCount == 1)
        #expect(!SessionTemporaryStorage.shared.isPresentingInAppMessage)
    }

    // MARK: - The show budget

    /// A two-second delay keeps the production timer out of the way; the eligible show is driven by hand.
    private func showScheduled(_ inapp: InAppFormData) {
        scheduleManager.scheduleInApp(inapp, processingDuration: 0)

        var presentationTime: TimeInterval?
        scheduleManager.queue.sync {
            presentationTime = self.scheduleManager.inappsByPresentationTime.keys.first
        }
        if let presentationTime {
            scheduleManager.showEligibleInapp(presentationTime)
        }
        scheduleManager.queue.sync {}
    }

    @Test("A scheduled in-app past the session limit is not presented", .tags(.inAppSchedule))
    func showEligibleInapp_pastSessionLimit_isNotPresented() {
        SessionTemporaryStorage.shared.inAppSettings = Settings.InAppSettings(maxInappsPerSession: 1, maxInappsPerDay: nil, minIntervalBetweenShows: nil)
        SessionTemporaryStorage.shared.sessionShownInApps = ["already-shown"]

        showScheduled(createInAppFormData(id: "1", isPriority: false, delayTime: "00:00:02"))

        #expect(presentationManagerMock.presentCallsCount == 0)
        #expect(SessionTemporaryStorage.shared.showBudget.reservations.isEmpty)
    }

    @Test("A presented in-app holds its slot until the window reports itself", .tags(.inAppSchedule))
    func showEligibleInapp_holdsTheSlotUntilPresented() {
        showScheduled(createInAppFormData(id: "1", isPriority: false, delayTime: "00:00:02"))

        #expect(presentationManagerMock.presentCallsCount == 1)
        #expect(SessionTemporaryStorage.shared.showBudget.reservations[.overlay]?.inAppId == "1")

        presentationManagerMock.receivedOnPresent?()

        #expect(SessionTemporaryStorage.shared.showBudget.reservations.isEmpty)
        #expect(SessionTemporaryStorage.shared.sessionShownInApps == ["1"])
    }

    @Test("A presentation error gives the slot back", .tags(.inAppSchedule))
    func showEligibleInapp_errorGivesTheSlotBack() {
        showScheduled(createInAppFormData(id: "1", isPriority: false, delayTime: "00:00:02"))

        presentationManagerMock.receivedOnError?(.failed("no window"))

        #expect(SessionTemporaryStorage.shared.showBudget.reservations.isEmpty)
        #expect(SessionTemporaryStorage.shared.sessionShownInApps.isEmpty)
    }

    @Test("Another in-app on screen blocks the show without taking a slot", .tags(.inAppSchedule))
    func showEligibleInapp_whileAnotherIsOnScreen_isNotPresented() {
        SessionTemporaryStorage.shared.isPresentingInAppMessage = true

        showScheduled(createInAppFormData(id: "1", isPriority: false, delayTime: "00:00:02"))

        #expect(presentationManagerMock.presentCallsCount == 0)
        #expect(SessionTemporaryStorage.shared.showBudget.reservations.isEmpty)
    }

    // MARK: - Helpers

    private func createInAppFormData(id: String,
                                     isPriority: Bool,
                                     delayTime: String?,
                                     frequency: InappFrequency = .once(OnceFrequency(kind: .session)),
                                     tags: [String: String]? = nil) -> InAppFormData {
        let modalVariant = ModalFormVariant(content: createMockContent())
        let content: MindboxFormVariant = .modal(modalVariant)

        return InAppFormData(
            inAppId: id,
            isPriority: isPriority,
            delayTime: delayTime,
            imagesDict: [:],
            firstImageValue: "",
            content: content,
            frequency: frequency,
            tags: tags
        )
    }

    private func createMockContent() -> InappFormVariantContent {
        let background = ContentBackground(layers: [])
        return InappFormVariantContent(background: background, elements: nil)
    }
}

class InAppTrackingServiceMock: InAppTrackingServiceProtocol {
    var trackInAppShownCallCount = 0
    var saveInappStateChangeCallCount = 0
    var lastTrackedInAppId: String?
    
    func trackInAppShown(id: String) {
        trackInAppShownCallCount += 1
        lastTrackedInAppId = id
    }
    
    func saveInappStateChange() {
        saveInappStateChangeCallCount += 1
    }
}

final class InappShowFailureManagerMock: InappShowFailureManagerProtocol {
    struct AddFailureCall {
        let inappId: String
        let reason: InAppShowFailureReason
        let details: String?
        let tags: [String: String]?
    }

    // @Locked: production calls these from its queues while the test reads from its own context.
    @Locked private(set) var addFailureCallCount = 0
    @Locked private(set) var sendFailuresCallCount = 0
    @Locked private(set) var clearFailuresCallCount = 0
    @Locked private(set) var waitBudgetExceeded: [(place: String, waited: TimeInterval, phase: EmbeddedBlockShowFailure.Phase)] = []
    @Locked private(set) var addFailureCalls: [AddFailureCall] = []
    @Locked private(set) var sentAtOnce: [AddFailureCall] = []

    func addFailure(inappId: String, reason: InAppShowFailureReason, details: String?, tags: [String: String]?) {
        addFailureCallCount += 1
        addFailureCalls.append(AddFailureCall(inappId: inappId, reason: reason, details: details, tags: tags))
    }

    func sendFailure(inappId: String, reason: InAppShowFailureReason, details: String?, tags: [String: String]?) {
        sentAtOnce.append(AddFailureCall(inappId: inappId, reason: reason, details: details, tags: tags))
    }

    func sendFailures() {
        sendFailuresCallCount += 1
    }

    func clearFailures() {
        clearFailuresCallCount += 1
    }

    func sendWaitBudgetExceeded(place: String, waited: TimeInterval, phase: EmbeddedBlockShowFailure.Phase) {
        waitBudgetExceeded.append((place, waited, phase))
    }
}
