//
//  InappScheduleManagerTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 04.07.2025.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

final class InappScheduleManagerTests: XCTestCase {
    
    private var scheduleManager: InappScheduleManager!
    private var presentationManagerMock: InAppPresentationManagerMock!
    private var trackingServiceMock: InAppTrackingServiceMock!
    
    override func setUp() {
        super.setUp()
        presentationManagerMock = InAppPresentationManagerMock()
        trackingServiceMock = InAppTrackingServiceMock()
        
        scheduleManager = InappScheduleManager(
            presentationManager: presentationManagerMock,
            presentationValidator: DI.injectOrFail(InAppPresentationValidatorProtocol.self),
            trackingService: trackingServiceMock
        )
        
        SessionTemporaryStorage.shared.erase()
    }
    
    override func tearDown() {
        scheduleManager = nil
        presentationManagerMock = nil
        trackingServiceMock = nil
        SessionTemporaryStorage.shared.erase()
        super.tearDown()
    }
    
    func test_scheduleInapp_noDelay_schedulesCorrectly() {
        XCTAssertTrue(scheduleManager.inappsByPresentationTime.isEmpty)
        
        let inapp = createInAppFormData(id: "1", isPriority: false, delayTime: nil)
        scheduleManager.scheduleInApp(inapp)
        
        var presentationTime: TimeInterval?
        scheduleManager.queue.sync {
            XCTAssertEqual(self.scheduleManager.inappsByPresentationTime.count, 1)
            presentationTime = self.scheduleManager.inappsByPresentationTime.keys.first
            let storedInapp = self.scheduleManager.inappsByPresentationTime.values.first?.first?.inapp
            XCTAssertEqual(storedInapp?.inAppId, inapp.inAppId)
            XCTAssertEqual(self.presentationManagerMock.presentCallsCount, 0)
        }
        
        XCTAssertNotNil(presentationTime)
        
        let expectation = expectation(description: "In-app without delay is presented")
        scheduleManager.showEligibleInapp(presentationTime!)
        
        scheduleManager.queue.async {
            XCTAssertEqual(self.presentationManagerMock.presentCallsCount, 1)
            XCTAssertEqual(self.presentationManagerMock.receivedInAppUIModel?.inAppId, inapp.inAppId)
            XCTAssertTrue(self.scheduleManager.inappsByPresentationTime.isEmpty)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func test_scheduleInApp_smallDelay_schedulesCorrectly() {
        XCTAssertTrue(scheduleManager.inappsByPresentationTime.isEmpty)
        
        let inapp = createInAppFormData(id: "1", isPriority: false, delayTime: "00:00:02")
        scheduleManager.scheduleInApp(inapp)
        
        var presentationTime: TimeInterval?
        scheduleManager.queue.sync {
            XCTAssertEqual(self.scheduleManager.inappsByPresentationTime.count, 1)
            presentationTime = self.scheduleManager.inappsByPresentationTime.keys.first
            let storedInapp = self.scheduleManager.inappsByPresentationTime.values.first?.first?.inapp
            XCTAssertEqual(storedInapp?.inAppId, inapp.inAppId)
            XCTAssertEqual(self.presentationManagerMock.presentCallsCount, 0)
        }
        
        XCTAssertNotNil(presentationTime)
        
        let expectation = expectation(description: "In-app with small delay is presented when eligible")
        scheduleManager.showEligibleInapp(presentationTime!)
        
        scheduleManager.queue.async {
            XCTAssertEqual(self.presentationManagerMock.presentCallsCount, 1)
            XCTAssertEqual(self.presentationManagerMock.receivedInAppUIModel?.inAppId, inapp.inAppId)
            XCTAssertTrue(self.scheduleManager.inappsByPresentationTime.isEmpty)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func test_scheduleMultipleInapp_smallDelay_schedulesCorrectly() {
        XCTAssertTrue(scheduleManager.inappsByPresentationTime.isEmpty)
        
        let inapp1 = createInAppFormData(id: "1", isPriority: false, delayTime: "00:00:02")
        let inapp2 = createInAppFormData(id: "2", isPriority: false, delayTime: "00:00:03")
        let inapp3 = createInAppFormData(id: "3", isPriority: true, delayTime: "00:00:04")
        
        scheduleManager.scheduleInApp(inapp1)
        scheduleManager.scheduleInApp(inapp2)
        scheduleManager.scheduleInApp(inapp3)
        
        var entries: [(time: TimeInterval, inappId: String)] = []
        scheduleManager.queue.sync {
            XCTAssertEqual(self.scheduleManager.inappsByPresentationTime.count, 3)
            XCTAssertEqual(self.presentationManagerMock.presentCallsCount, 0)
            
            for (time, scheduled) in self.scheduleManager.inappsByPresentationTime {
                guard let first = scheduled.first else {
                    XCTFail("Expected at least one scheduled in-app for time \(time)")
                    continue
                }
                entries.append((time: time, inappId: first.inapp.inAppId))
            }
        }
        
        XCTAssertEqual(entries.count, 3)
        
        let earliest = entries.min(by: { $0.time < $1.time })
        XCTAssertEqual(earliest?.inappId, inapp1.inAppId)
        
        let sortedTimes = entries.map { $0.time }.sorted()
        for time in sortedTimes {
            scheduleManager.showEligibleInapp(time)
        }
        
        let expectation = expectation(description: "Only first scheduled in-app is presented")
        scheduleManager.queue.async {
            XCTAssertTrue(self.scheduleManager.inappsByPresentationTime.isEmpty)
            XCTAssertEqual(self.presentationManagerMock.presentCallsCount, 1)
            XCTAssertEqual(self.presentationManagerMock.receivedInAppUIModel?.inAppId, inapp1.inAppId)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func test_scheduleInapp_successShow_recordsDeleted() {
        XCTAssertTrue(scheduleManager.inappsByPresentationTime.isEmpty)
        
        let inapp = createInAppFormData(id: "1", isPriority: false, delayTime: "00:00:02")
        scheduleManager.scheduleInApp(inapp)
        
        var presentationTime: TimeInterval?
        scheduleManager.queue.sync {
            XCTAssertFalse(self.scheduleManager.inappsByPresentationTime.isEmpty)
            presentationTime = self.scheduleManager.inappsByPresentationTime.keys.first
        }
        
        XCTAssertNotNil(presentationTime)
        
        let expectation = expectation(description: "Scheduled in-app entries are removed after presentation")
        scheduleManager.showEligibleInapp(presentationTime!)
        
        scheduleManager.queue.async {
            XCTAssertTrue(self.scheduleManager.inappsByPresentationTime.isEmpty)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func test_scheduleInapp_withInvalidDelayTime_usesDefaultDelay() {
        XCTAssertEqual(scheduleManager.getDelay("invalid_time"), 0)
        
        let inapp = createInAppFormData(id: "1", isPriority: false, delayTime: "invalid_time")
        scheduleManager.scheduleInApp(inapp)
        
        var presentationTime: TimeInterval?
        scheduleManager.queue.sync {
            XCTAssertEqual(self.scheduleManager.inappsByPresentationTime.count, 1)
            presentationTime = self.scheduleManager.inappsByPresentationTime.keys.first
        }
        
        XCTAssertNotNil(presentationTime)
        
        let expectation = expectation(description: "In-app with invalid delay uses default delay and is presented")
        scheduleManager.showEligibleInapp(presentationTime!)
        
        scheduleManager.queue.async {
            XCTAssertEqual(self.presentationManagerMock.presentCallsCount, 1)
            XCTAssertEqual(self.presentationManagerMock.receivedInAppUIModel?.inAppId, inapp.inAppId)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func test_scheduleInapp_withZeroDelay_schedulesCorrectly() {
        XCTAssertEqual(scheduleManager.getDelay("00:00:00"), 0)
        
        let inapp = createInAppFormData(id: "1", isPriority: false, delayTime: "00:00:00")
        scheduleManager.scheduleInApp(inapp)
        
        var presentationTime: TimeInterval?
        scheduleManager.queue.sync {
            XCTAssertEqual(self.scheduleManager.inappsByPresentationTime.count, 1)
            presentationTime = self.scheduleManager.inappsByPresentationTime.keys.first
        }
        
        XCTAssertNotNil(presentationTime)
        
        let expectation = expectation(description: "In-app with zero delay is presented")
        scheduleManager.showEligibleInapp(presentationTime!)
        
        scheduleManager.queue.async {
            XCTAssertEqual(self.presentationManagerMock.presentCallsCount, 1)
            XCTAssertEqual(self.presentationManagerMock.receivedInAppUIModel?.inAppId, inapp.inAppId)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func test_scheduleInApp_withLargeDelay_schedulesCorrectly() {
        XCTAssertTrue(scheduleManager.inappsByPresentationTime.isEmpty)
        
        let inapp = createInAppFormData(id: "1", isPriority: false, delayTime: "01:00:00")
        let start = Date().timeIntervalSince1970
        
        scheduleManager.scheduleInApp(inapp)
        
        var scheduledTime: TimeInterval?
        scheduleManager.queue.sync {
            XCTAssertEqual(self.scheduleManager.inappsByPresentationTime.count, 1)
            scheduledTime = self.scheduleManager.inappsByPresentationTime.keys.first
            let scheduledInapp = self.scheduleManager.inappsByPresentationTime.values.first?.first?.inapp
            XCTAssertEqual(scheduledInapp?.inAppId, inapp.inAppId)
        }
        
        XCTAssertNotNil(scheduledTime)
        
        let oneHour: TimeInterval = 3600
        let tolerance: TimeInterval = 1
        
        XCTAssertGreaterThanOrEqual(scheduledTime!, start + oneHour - tolerance)
        XCTAssertLessThanOrEqual(scheduledTime!, start + oneHour + tolerance)
    }
    
    func test_multipleInAppsOnSameTime_schedulesCorrectly_shownSecond() {
        XCTAssertTrue(scheduleManager.inappsByPresentationTime.isEmpty)
        
        let inapp1 = createInAppFormData(id: "1", isPriority: false, delayTime: "01:00:00")
        let inapp2 = createInAppFormData(id: "2", isPriority: true, delayTime: "01:00:00")
        let inapp3 = createInAppFormData(id: "3", isPriority: false, delayTime: "01:00:00")
        
        scheduleManager.scheduleInApp(inapp1)
        
        var presentationTime: TimeInterval?
        var baseTimer: DispatchSourceTimer?
        
        scheduleManager.queue.sync {
            guard let entry = self.scheduleManager.inappsByPresentationTime.first,
                  let existingScheduled = entry.value.first else {
                XCTFail("Expected one scheduled in-app")
                return
            }
            
            presentationTime = entry.key
            baseTimer = existingScheduled.timer
            
            let scheduledInapp1 = ScheduledInapp(inapp: inapp1, timer: existingScheduled.timer)
            let scheduledInapp2 = ScheduledInapp(inapp: inapp2, timer: existingScheduled.timer)
            let scheduledInapp3 = ScheduledInapp(inapp: inapp3, timer: existingScheduled.timer)
            
            self.scheduleManager.inappsByPresentationTime[presentationTime!] = [
                scheduledInapp1,
                scheduledInapp2,
                scheduledInapp3
            ]
        }
        
        XCTAssertNotNil(presentationTime)
        XCTAssertNotNil(baseTimer)
        
        let expectation = expectation(description: "Priority in-app is presented when several scheduled at the same time")
        scheduleManager.showEligibleInapp(presentationTime!)
        
        scheduleManager.queue.async {
            XCTAssertEqual(self.scheduleManager.inappsByPresentationTime.count, 0)
            XCTAssertEqual(self.presentationManagerMock.presentCallsCount, 1)
            XCTAssertEqual(self.presentationManagerMock.receivedInAppUIModel?.inAppId, inapp2.inAppId)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 7.0)
    }
    
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
