//
//  InappScheduleManagerTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 04.07.2025.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import Testing
@testable import Mindbox

@Suite("In-app schedule manager tests")
struct InappScheduleManagerTests {

    private var scheduleManager: InappScheduleManager
    private var presentationManagerMock: InAppPresentationManagerMock
    private var trackingServiceMock: InAppTrackingServiceMock

    init() {
        TestConfiguration.configure()

        presentationManagerMock = InAppPresentationManagerMock()
        trackingServiceMock = InAppTrackingServiceMock()

        scheduleManager = InappScheduleManager(
            presentationManager: presentationManagerMock,
            presentationValidator: DI.injectOrFail(InAppPresentationValidatorProtocol.self),
            trackingService: trackingServiceMock,
            failureManager: DI.injectOrFail(InappShowFailureManagerProtocol.self)
        )

        SessionTemporaryStorage.shared.erase()
    }

    // MARK: - No delay

    @Test("In-app without delay is scheduled and presented immediately", .tags(.inAppSchedule))
    func scheduleInapp_noDelay_schedulesCorrectly() {
        #expect(scheduleManager.inappsByPresentationTime.isEmpty)

        let inapp = createInAppFormData(id: "1", isPriority: false, delayTime: nil)
        scheduleManager.scheduleInApp(inapp)

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

    // MARK: - Small delay (logic-level, not real time)

    @Test("In-app with small delay is scheduled and presented when eligible", .tags(.inAppSchedule))
    func scheduleInApp_smallDelay_schedulesCorrectly() {
        #expect(scheduleManager.inappsByPresentationTime.isEmpty)

        let inapp = createInAppFormData(id: "1", isPriority: false, delayTime: "00:00:02")
        scheduleManager.scheduleInApp(inapp)

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

        scheduleManager.scheduleInApp(inapp1)
        scheduleManager.scheduleInApp(inapp2)
        scheduleManager.scheduleInApp(inapp3)

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

    // MARK: - Records deletion

    @Test("Scheduled entries are removed after in-app is shown", .tags(.inAppSchedule))
    func scheduleInapp_successShow_recordsDeleted() {
        #expect(scheduleManager.inappsByPresentationTime.isEmpty)

        let inapp = createInAppFormData(id: "1", isPriority: false, delayTime: "00:00:02")
        scheduleManager.scheduleInApp(inapp)

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

    // MARK: - Invalid / zero delay

    @Test("Invalid delay string falls back to zero and in-app is presented", .tags(.inAppSchedule))
    func scheduleInapp_withInvalidDelayTime_usesDefaultDelay() {
        #expect(scheduleManager.getDelay("invalid_time") == 0)

        let inapp = createInAppFormData(id: "1", isPriority: false, delayTime: "invalid_time")
        scheduleManager.scheduleInApp(inapp)

        var presentationTime: TimeInterval?

        scheduleManager.queue.sync {
            #expect(self.scheduleManager.inappsByPresentationTime.count == 1)
            presentationTime = self.scheduleManager.inappsByPresentationTime.keys.first
        }

        guard let time = presentationTime else {
            Issue.record("Expected presentationTime to be set")
            return
        }

        scheduleManager.showEligibleInapp(time)

        scheduleManager.queue.sync {
            #expect(self.presentationManagerMock.presentCallsCount == 1)
            #expect(self.presentationManagerMock.receivedInAppUIModel?.inAppId == inapp.inAppId)
        }
    }

    @Test("Zero delay is treated as immediate and in-app is presented", .tags(.inAppSchedule))
    func scheduleInapp_withZeroDelay_schedulesCorrectly() {
        #expect(scheduleManager.getDelay("00:00:00") == 0)

        let inapp = createInAppFormData(id: "1", isPriority: false, delayTime: "00:00:00")
        scheduleManager.scheduleInApp(inapp)

        var presentationTime: TimeInterval?

        scheduleManager.queue.sync {
            #expect(self.scheduleManager.inappsByPresentationTime.count == 1)
            presentationTime = self.scheduleManager.inappsByPresentationTime.keys.first
        }

        guard let time = presentationTime else {
            Issue.record("Expected presentationTime to be set")
            return
        }

        scheduleManager.showEligibleInapp(time)

        scheduleManager.queue.sync {
            #expect(self.presentationManagerMock.presentCallsCount == 1)
            #expect(self.presentationManagerMock.receivedInAppUIModel?.inAppId == inapp.inAppId)
        }
    }

    // MARK: - Large delay

    @Test("In-app with large delay is scheduled at expected time", .tags(.inAppSchedule))
    func scheduleInApp_withLargeDelay_schedulesCorrectly() {
        #expect(scheduleManager.inappsByPresentationTime.isEmpty)

        let inapp = createInAppFormData(id: "1", isPriority: false, delayTime: "01:00:00")
        let start = Date().timeIntervalSince1970

        scheduleManager.scheduleInApp(inapp)

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

        scheduleManager.scheduleInApp(inapp1)

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

            let scheduledInapp1 = ScheduledInapp(inapp: inapp1, timer: existingScheduled.timer)
            let scheduledInapp2 = ScheduledInapp(inapp: inapp2, timer: existingScheduled.timer)
            let scheduledInapp3 = ScheduledInapp(inapp: inapp3, timer: existingScheduled.timer)

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

    // MARK: - Helpers

    private func createInAppFormData(id: String, isPriority: Bool, delayTime: String?) -> InAppFormData {
        let modalVariant = ModalFormVariant(content: createMockContent())
        let content: MindboxFormVariant = .modal(modalVariant)
        let onceFrequency = OnceFrequency(kind: .session)
        let frequency: InappFrequency = .once(onceFrequency)

        return InAppFormData(
            inAppId: id,
            isPriority: isPriority,
            delayTime: delayTime,
            imagesDict: [:],
            firstImageValue: "",
            content: content,
            frequency: frequency
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
