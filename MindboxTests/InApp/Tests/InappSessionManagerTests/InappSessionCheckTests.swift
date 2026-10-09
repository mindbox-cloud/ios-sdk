//
//  InappSessionCheckTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 08.10.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import QuartzCore
import Testing
import class MindboxLogger.Locked
@_spi(Internal) @testable import Mindbox

@Suite("In-app session check", .tags(.trackVisit))
struct InappSessionCheckTests {

    /// Counts session resets from any thread; each one lingers so a second visit can arrive mid-reset.
    private final class CoreManagerSpy: InAppCoreManagerProtocol {
        weak var delegate: InAppMessagesDelegate?

        @Locked private(set) var startEvents = 0

        /// Runs on the checking thread between the verdict that the session expired and its reset.
        var onDiscard: (() -> Void)?

        func start() {}

        func sendEvent(_ event: InAppMessageTriggerEvent) {
            if case .start = event {
                $startEvents.mutate { $0 += 1 }
            }
        }

        func discardEvents() {
            onDiscard?()
            Thread.sleep(forTimeInterval: 0.2)
        }
    }

    /// Announcements from any thread, with the session each one saw.
    private final class AnnouncementSpy {
        struct Announcement {
            let sessionEpoch: Int
            let startedAt: TimeInterval?
            let startsNewSession: Bool?
        }

        @Locked private(set) var announcements: [Announcement] = []

        private var observer: NSObjectProtocol?

        init() {
            observer = NotificationCenter.default.addObserver(forName: .inappSessionChecked, object: nil, queue: nil) { [weak self] notification in
                let announcement = Announcement(sessionEpoch: SessionTemporaryStorage.shared.ledger.sessionEpoch,
                                                startedAt: notification.userInfo?[Constants.Notification.sessionCheckStartedAt] as? TimeInterval,
                                                startsNewSession: notification.userInfo?[Constants.Notification.startsNewSession] as? Bool)
                self?.$announcements.mutate { $0.append(announcement) }
            }
        }

        deinit {
            if let observer {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }

    private enum PayloadError: Error {
        case notAString
    }

    private let coreManager = CoreManagerSpy()
    private let manager: InappSessionManager

    // The announcement reaches the process-wide presence on the default center.
    init() {
        TestConfiguration.configure()
        SessionTemporaryStorage.shared.erase()
        EmbeddedBlockAppPresence.shared.reset()
        SessionTemporaryStorage.shared.isInitializationCalled = true
        SessionTemporaryStorage.shared.expiredConfigSession = "0.00:30:00.0000000"

        manager = InappSessionManager(inappCoreManager: coreManager,
                                      inappConfigManager: DI.injectOrFail(InAppConfigurationManagerProtocol.self),
                                      targetingChecker: DI.injectOrFail(InAppTargetingCheckerProtocol.self),
                                      userVisitManager: DI.injectOrFail(UserVisitManagerProtocol.self))
    }

    @Test("Two visits at once after the session expired start one new session")
    func concurrentVisitsResetTheSessionOnce() {
        manager.lastTrackVisitTimestamp = Date().addingTimeInterval(-2400)
        let sessionEpoch = SessionTemporaryStorage.shared.ledger.sessionEpoch

        DispatchQueue.concurrentPerform(iterations: 2) { _ in
            manager.checkInappSession()
        }
        waitForMain()

        #expect(coreManager.startEvents == 1)
        #expect(SessionTemporaryStorage.shared.ledger.sessionEpoch == sessionEpoch + 1)
    }

    /// The announcement is posted on main: what main has run is what the observers have heard.
    private func waitForMain() {
        let ran = DispatchSemaphore(value: 0)
        DispatchQueue.main.async { ran.signal() }
        _ = ran.wait(timeout: .now() + 2)
    }

    @Test("A session check is announced when it ends, after the reset of an expired session, stamped on the monotonic clock",
          arguments: [true, false])
    func sessionCheckIsAnnouncedAfterTheReset(isExpired: Bool) throws {
        manager.lastTrackVisitTimestamp = Date().addingTimeInterval(isExpired ? -2400 : -10)
        let sessionEpoch = SessionTemporaryStorage.shared.ledger.sessionEpoch
        let spy = AnnouncementSpy()
        let checkStarted = CACurrentMediaTime()

        manager.checkInappSession()

        let checkEnded = CACurrentMediaTime()
        waitForMain()
        let announcement = try #require(spy.announcements.first)
        let startedAt = try #require(announcement.startedAt)
        #expect(spy.announcements.count == 1)
        #expect(announcement.sessionEpoch == sessionEpoch + (isExpired ? 1 : 0))
        #expect(announcement.startsNewSession == isExpired)
        #expect(startedAt >= checkStarted && startedAt <= checkEnded)
    }

    @Test("Two visits at once after the session expired announce their checks only once the reset is done")
    func concurrentChecksAreAnnouncedAfterTheReset() {
        manager.lastTrackVisitTimestamp = Date().addingTimeInterval(-2400)
        let sessionEpoch = SessionTemporaryStorage.shared.ledger.sessionEpoch
        let spy = AnnouncementSpy()

        DispatchQueue.concurrentPerform(iterations: 2) { _ in
            manager.checkInappSession()
        }
        waitForMain()

        #expect(spy.announcements.map(\.sessionEpoch) == [sessionEpoch + 1, sessionEpoch + 1])
        #expect(spy.announcements.filter { $0.startsNewSession == true }.count == 1)
    }

    @Test("A check before initialization is announced too, and starts no session")
    func checkBeforeInitializationIsAnnounced() {
        // Swapped past the flag's observer, which would start the SDK on the way back.
        _ = SessionTemporaryStorage.shared.$isInitializationCalled.exchange(false)
        defer { _ = SessionTemporaryStorage.shared.$isInitializationCalled.exchange(true) }
        manager.lastTrackVisitTimestamp = Date().addingTimeInterval(-2400)
        let spy = AnnouncementSpy()

        manager.checkInappSession()
        waitForMain()

        #expect(spy.announcements.map(\.startsNewSession) == [false])
        #expect(coreManager.startEvents == 0)
    }

    @Test("A check made off the main thread returns while main waits for it: the announcement never makes it wait for main")
    func checkOffMainDoesNotWaitForMain() {
        manager.lastTrackVisitTimestamp = Date().addingTimeInterval(-10)
        let observer = NotificationCenter.default.addObserver(forName: .inappSessionChecked, object: nil, queue: .main) { _ in }
        defer { NotificationCenter.default.removeObserver(observer) }
        let manager = manager
        let mainWaited = DispatchSemaphore(value: 0)
        var returnedWhileMainWaited = false

        DispatchQueue.main.async {
            let checked = DispatchSemaphore(value: 0)
            DispatchQueue.global().async {
                manager.checkInappSession()
                checked.signal()
            }
            returnedWhileMainWaited = checked.wait(timeout: .now() + 2) == .success
            mainWaited.signal()
        }
        _ = mainWaited.wait(timeout: .now() + 5)
        waitForMain()

        #expect(returnedWhileMainWaited)
    }

    @Test("A block show recorded after a check has found the session expired, before its reset, is not accounted")
    func showWhileTheCheckEndsTheSessionIsNotAccounted() {
        manager.lastTrackVisitTimestamp = Date().addingTimeInterval(-2400)
        let endingSession = SessionTemporaryStorage.shared.ledger.sessionEpoch
        let tracker = InAppMessagesTrackerSpyMock()
        let accountant = InappShowAccountant(tracker: tracker, budget: InappShowBudgetMock())
        var wasEndingMeanwhile: Bool?
        coreManager.onDiscard = {
            wasEndingMeanwhile = SessionTemporaryStorage.shared.ledger.isSessionEnding
            accountant.recordBlockShow(InappShow(inAppId: "inapp", frequency: .unlimited, tags: nil, timeToDisplay: 1),
                                       at: "stories",
                                       sessionEpoch: endingSession)
        }

        manager.checkInappSession()
        waitForMain()

        #expect(wasEndingMeanwhile == true)
        #expect(tracker.trackViewCallCount == 0)
        #expect(SessionTemporaryStorage.shared.ledger.placeShownInappId.isEmpty)
        #expect(SessionTemporaryStorage.shared.ledger.isSessionEnding == false)
    }

    @Test("A visit that starts a new session is still the page's track-visit source after the reset")
    func visitThatStartsASessionOutlivesItsReset() async throws {
        manager.lastTrackVisitTimestamp = Date().addingTimeInterval(-2400)
        SessionTemporaryStorage.shared.lastTrackVisit = nil
        let sessionEpoch = SessionTemporaryStorage.shared.ledger.sessionEpoch
        let link = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
        link.webpageURL = URL(string: "https://test-site.s.mindbox.ru/new-session")
        let trackVisitManager = TrackVisitManager(databaseRepository: DI.injectOrFail(DatabaseRepositoryProtocol.self),
                                                  inappSessionManager: manager)

        try trackVisitManager.track(.universalLink(link))
        let payload = try await startPayload()

        #expect(SessionTemporaryStorage.shared.ledger.sessionEpoch == sessionEpoch + 1)
        #expect(payload["trackVisitSource"] == .string(TrackVisitSource.link.rawValue))
        #expect(payload["trackVisitRequestUrl"] == .string("https://test-site.s.mindbox.ru/new-session"))
    }

    private func startPayload() async throws -> [String: JSONValue] {
        let builder = WebViewStartPayloadBuilder(contentId: "block", operation: nil, customParams: nil, insetsSource: nil, logError: { _ in })
        let payload = await withCheckedContinuation { continuation in
            builder.build { continuation.resume(returning: $0) }
        }

        guard case .string(let json) = payload else {
            throw PayloadError.notAString
        }

        return try JSONDecoder().decode([String: JSONValue].self, from: Data(json.utf8))
    }
}
