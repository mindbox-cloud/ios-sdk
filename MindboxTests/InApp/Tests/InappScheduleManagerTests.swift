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
    
    // MARK: - Планирование in-app сообщений
    
    func test_scheduleInapp_noDelay_schedulesCorrectly() {
        XCTAssertTrue(scheduleManager.inappsByPresentationTime.isEmpty)
        let inapp = createInAppFormData(id: "1", isPriority: false, delayTime: nil)
        scheduleManager.scheduleInApp(inapp)
        
        let expectation = XCTestExpectation(description: "Schedule non-priority in-app")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(presentationManagerMock.presentCallsCount == 1)
        XCTAssertEqual(presentationManagerMock.receivedInAppUIModel?.inAppId, inapp.inAppId)
    }
    
    func test_scheduleInApp_smallDelay_schedulesCorrectly() {
        XCTAssertTrue(scheduleManager.inappsByPresentationTime.isEmpty)
        let inapp = createInAppFormData(id: "1", isPriority: false, delayTime: "00:00:02")
        scheduleManager.scheduleInApp(inapp)
        
        let schedulingExpectation = XCTestExpectation(description: "In-app should be scheduled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertTrue(self.scheduleManager.inappsByPresentationTime.count == 1)
            let scheduledInApp = self.scheduleManager.inappsByPresentationTime.first?.value.first
            XCTAssertEqual(scheduledInApp?.inapp.inAppId, inapp.inAppId)
            XCTAssertTrue(self.presentationManagerMock.presentCallsCount == 0)
            schedulingExpectation.fulfill()
        }
        wait(for: [schedulingExpectation], timeout: 1.0)
        
        let presentationExpectation = XCTestExpectation(description: "In-app should be presented after delay")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            XCTAssertTrue(self.presentationManagerMock.presentCallsCount == 1)
            XCTAssertEqual(self.presentationManagerMock.receivedInAppUIModel?.inAppId, inapp.inAppId)
            presentationExpectation.fulfill()
        }
        wait(for: [presentationExpectation], timeout: 3.0)
    }
    
    func test_scheduleMultipleInapp_smallDelay_schedulesCorrectly() {
        XCTAssertTrue(scheduleManager.inappsByPresentationTime.isEmpty)
        let inapp1 = createInAppFormData(id: "1", isPriority: false, delayTime: "00:00:02")
        let inapp2 = createInAppFormData(id: "2", isPriority: false, delayTime: "00:00:03")
        let inapp3 = createInAppFormData(id: "3", isPriority: true, delayTime: "00:00:04")
        scheduleManager.scheduleInApp(inapp1)
        scheduleManager.scheduleInApp(inapp2)
        scheduleManager.scheduleInApp(inapp3)
        
        let schedulingExpectation = XCTestExpectation(description: "In-app should be scheduled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            XCTAssertTrue(self.scheduleManager.inappsByPresentationTime.count == 3)
            XCTAssertTrue(self.presentationManagerMock.presentCallsCount == 0)
            schedulingExpectation.fulfill()
        }
        wait(for: [schedulingExpectation], timeout: 2)
        
        let presentationExpectation = XCTestExpectation(description: "In-app should be presented after delay")
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            XCTAssertTrue(self.presentationManagerMock.presentCallsCount == 1)
            XCTAssertEqual(self.presentationManagerMock.receivedInAppUIModel?.inAppId, inapp1.inAppId)
            presentationExpectation.fulfill()
        }
        wait(for: [presentationExpectation], timeout: 6)
        
        XCTAssertTrue(self.scheduleManager.inappsByPresentationTime.isEmpty)
    }
    
    func test_scheduleInapp_successShow_recordsDeleted() {
        XCTAssertTrue(scheduleManager.inappsByPresentationTime.isEmpty)
        let inapp = createInAppFormData(id: "1", isPriority: false, delayTime: "00:00:02")
        scheduleManager.scheduleInApp(inapp)
        
        let expectation = XCTestExpectation(description: "Schedule non-priority in-app")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertFalse(self.scheduleManager.inappsByPresentationTime.isEmpty)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        let presentationExpectation = XCTestExpectation(description: "In-app should be presented after delay")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            XCTAssertTrue(self.scheduleManager.inappsByPresentationTime.isEmpty)
            presentationExpectation.fulfill()
        }
        wait(for: [presentationExpectation], timeout: 3)
    }
    
    func test_scheduleInapp_withInvalidDelayTime_usesDefaultDelay() {
        XCTAssertTrue(scheduleManager.inappsByPresentationTime.isEmpty)
        let inapp = createInAppFormData(id: "1", isPriority: false, delayTime: "invalid_time")
        scheduleManager.scheduleInApp(inapp)
        
        let expectation = XCTestExpectation(description: "Schedule in-app with invalid delay")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            XCTAssertTrue(self.presentationManagerMock.presentCallsCount == 1)
            XCTAssertEqual(self.presentationManagerMock.receivedInAppUIModel?.inAppId, inapp.inAppId)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.2)
    }
    
    func test_scheduleInapp_withZeroDelay_schedulesCorrectly() {
        XCTAssertTrue(scheduleManager.inappsByPresentationTime.isEmpty)
        let inapp = createInAppFormData(id: "1", isPriority: false, delayTime: "00:00:00")
        scheduleManager.scheduleInApp(inapp)
        
        let expectation = XCTestExpectation(description: "Schedule in-app with zero delay")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            XCTAssertTrue(self.presentationManagerMock.presentCallsCount == 1)
            XCTAssertEqual(self.presentationManagerMock.receivedInAppUIModel?.inAppId, inapp.inAppId)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.2)
    }
    
    func test_scheduleInApp_withLargeDelay_schedulesCorrectly() {
        XCTAssertTrue(scheduleManager.inappsByPresentationTime.isEmpty)
        let inapp = createInAppFormData(id: "1", isPriority: false, delayTime: "01:00:00")
        scheduleManager.scheduleInApp(inapp)
        
        let expectation = XCTestExpectation(description: "Schedule in-app with large delay")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(self.scheduleManager.inappsByPresentationTime.count == 1)
            let scheduledInApp = self.scheduleManager.inappsByPresentationTime.first?.value.first
            XCTAssertEqual(scheduledInApp?.inapp.inAppId, inapp.inAppId)
            
            let scheduledTime = self.scheduleManager.inappsByPresentationTime.first?.key
            let currentTime = Date().timeIntervalSince1970
            let oneHourInSeconds: TimeInterval = 3600
            let tolerance: TimeInterval = 1
            
            XCTAssertNotNil(scheduledTime)
            XCTAssertGreaterThanOrEqual(scheduledTime!, currentTime + oneHourInSeconds - tolerance)
            XCTAssertLessThanOrEqual(scheduledTime!, currentTime + oneHourInSeconds + tolerance)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }
    
    func test_multipleInAppsOnSameTime_schedulesCorrectly_shownSecond() {
        XCTAssertTrue(scheduleManager.inappsByPresentationTime.isEmpty)
        let inapp1 = createInAppFormData(id: "1", isPriority: false, delayTime: "00:00:02")
        let inapp2 = createInAppFormData(id: "2", isPriority: true, delayTime: "00:00:02")
        let inapp3 = createInAppFormData(id: "3", isPriority: false, delayTime: "00:00:02")
        
        scheduleManager.scheduleInApp(inapp1)
        
        let q = scheduleManager.queue // или: let q = DispatchQueue(label: "test.timer")
        
        // timer1
        let timer1 = DispatchSource.makeTimerSource(flags: .strict, queue: q)
        timer1.setEventHandler { /* no-op для теста */ }
        timer1.schedule(deadline: .now() + .milliseconds(5), repeating: .never, leeway: .milliseconds(1))
        timer1.resume()

        defer {
            timer1.cancel()
        }
        
        let scheduledInapp1 = ScheduledInapp(inapp: inapp1, timer: timer1)
        let scheduledInapp2 = ScheduledInapp(inapp: inapp2, timer: timer1)
        let scheduledInapp3 = ScheduledInapp(inapp: inapp3, timer: timer1)
        
        let expectation = XCTestExpectation(description: "Schedule in-app")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if let scheduledTime = self.scheduleManager.inappsByPresentationTime.first?.key {
                self.scheduleManager.inappsByPresentationTime[scheduledTime] = [scheduledInapp1, scheduledInapp2, scheduledInapp3]
            }

            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 3)

        let presentationExpectation = XCTestExpectation(description: "Present in-app")
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            XCTAssertEqual(self.scheduleManager.inappsByPresentationTime.count, 0)
            XCTAssertEqual(self.presentationManagerMock.presentCallsCount, 1)
            XCTAssertEqual(self.presentationManagerMock.receivedInAppUIModel?.inAppId, inapp2.inAppId)
            presentationExpectation.fulfill()
        }
        
        wait(for: [presentationExpectation], timeout: 7)
    }
    
    // MARK: - Helper Methods
    
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
