//
//  InappSessionCheckTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 08.10.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import Testing
import class MindboxLogger.Locked
@_spi(Internal) @testable import Mindbox

@Suite("In-app session check", .tags(.trackVisit))
struct InappSessionCheckTests {

    private final class CoreManagerSpy: InAppCoreManagerProtocol {
        weak var delegate: InAppMessagesDelegate?

        @Locked private(set) var startEvents = 0

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

    private enum PayloadError: Error {
        case notAString
    }

    private let coreManager = CoreManagerSpy()
    private let manager: InappSessionManager

    init() {
        TestConfiguration.configure()
        SessionTemporaryStorage.shared.erase()
        SessionTemporaryStorage.shared.isInitializationCalled = true
        SessionTemporaryStorage.shared.expiredConfigSession = "0.00:30:00.0000000"

        manager = InappSessionManager(inappCoreManager: coreManager,
                                      inappConfigManager: DI.injectOrFail(InAppConfigurationManagerProtocol.self),
                                      targetingChecker: DI.injectOrFail(InAppTargetingCheckerProtocol.self),
                                      userVisitManager: DI.injectOrFail(UserVisitManagerProtocol.self))
    }

    @Test("Two visits at once after the session expired start one new session: the check that ends it has already taken its visit's time when it resets")
    func concurrentVisitsResetTheSessionOnce() throws {
        manager.lastTrackVisitTimestamp = Date().addingTimeInterval(-2400)
        let manager = manager
        var visitAtTheReset: Date?
        coreManager.onDiscard = { visitAtTheReset = manager.lastTrackVisitTimestamp }

        DispatchQueue.concurrentPerform(iterations: 2) { _ in
            manager.checkInappSession()
        }
        waitForMain()

        #expect(coreManager.startEvents == 1)
        let visit = try #require(visitAtTheReset)
        #expect(visit.timeIntervalSinceNow > -60)
    }

    private func waitForMain() {
        let ran = DispatchSemaphore(value: 0)
        DispatchQueue.main.async { ran.signal() }
        _ = ran.wait(timeout: .now() + 2)
    }

    @Test("A check before initialization starts no session")
    func checkBeforeInitializationStartsNoSession() {
        _ = SessionTemporaryStorage.shared.$isInitializationCalled.exchange(false)
        defer { _ = SessionTemporaryStorage.shared.$isInitializationCalled.exchange(true) }
        manager.lastTrackVisitTimestamp = Date().addingTimeInterval(-2400)

        manager.checkInappSession()
        waitForMain()

        #expect(coreManager.startEvents == 0)
    }

    @Test("A visit that starts a new session is still the page's track-visit source after the reset")
    func visitThatStartsASessionOutlivesItsReset() async throws {
        manager.lastTrackVisitTimestamp = Date().addingTimeInterval(-2400)
        SessionTemporaryStorage.shared.lastTrackVisit = nil
        let link = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
        link.webpageURL = URL(string: "https://test-site.s.mindbox.ru/new-session")
        let trackVisitManager = TrackVisitManager(databaseRepository: DI.injectOrFail(DatabaseRepositoryProtocol.self),
                                                  inappSessionManager: manager)

        try trackVisitManager.track(.universalLink(link))
        let payload = try await startPayload()

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
