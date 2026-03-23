//
//  TrackVisitManagerTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 3/20/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
@testable import Mindbox

// Note: Push deduplication is not tested directly because UNNotificationResponse
// has no public initializers. The skip-flag mechanism is identical for push and
// universal link (both set skipNextDirectTrackVisit = true), so universal link
// tests fully cover the shared deduplication logic.

@Suite("TrackVisitManager", .tags(.trackVisit))
struct TrackVisitManagerTests {

    private func makeSUT() -> (sut: TrackVisitManager, spy: SpyDatabaseRepository) {
        let spy = SpyDatabaseRepository()
        let stubSession = StubInappSessionManager()
        let sut = TrackVisitManager(databaseRepository: spy, inappSessionManager: stubSession)
        SessionTemporaryStorage.shared.erase()
        return (sut, spy)
    }

    private func makeUserActivity(url: String = "https://test-site.s.mindbox.ru") -> NSUserActivity {
        let activity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
        activity.webpageURL = URL(string: url)
        return activity
    }

    private func decodeTrackVisit(from event: Event) throws -> TrackVisit {
        let data = try #require(event.body.data(using: .utf8))
        return try JSONDecoder().decode(TrackVisit.self, from: data)
    }

    // MARK: - trackDirect

    @Test("trackDirect sends direct event with source=direct and sets lastTrackVisit")
    func trackDirectSendsEvent() throws {
        let (sut, spy) = makeSUT()

        try sut.trackDirect()

        #expect(spy.createdEvents.count == 1)
        #expect(spy.createdEvents[0].type == .trackVisit)
        let body = try decodeTrackVisit(from: spy.createdEvents[0])
        #expect(body.source == .direct)
        #expect(body.requestUrl == nil)
        #expect(SessionTemporaryStorage.shared.lastTrackVisit?.source == .direct)
        #expect(SessionTemporaryStorage.shared.lastTrackVisit?.requestUrl == nil)
    }

    // MARK: - trackForeground

    @Test("trackForeground sends event with source=nil and does not modify lastTrackVisit")
    func trackForegroundDoesNotOverwriteLastTrackVisit() throws {
        let (sut, spy) = makeSUT()

        // Simulate a prior universal link track visit
        try sut.track(.universalLink(makeUserActivity()))
        let savedTrackVisit = SessionTemporaryStorage.shared.lastTrackVisit

        try sut.trackForeground()

        #expect(spy.createdEvents.count == 2) // link + foreground
        let foregroundBody = try decodeTrackVisit(from: spy.createdEvents[1])
        #expect(foregroundBody.source == nil)
        #expect(SessionTemporaryStorage.shared.lastTrackVisit?.source == savedTrackVisit?.source)
        #expect(SessionTemporaryStorage.shared.lastTrackVisit?.requestUrl == savedTrackVisit?.requestUrl)
    }

    @Test("trackForeground does not affect skipNextDirectTrackVisit flag")
    func trackForegroundDoesNotAffectSkipFlag() throws {
        let (sut, spy) = makeSUT()

        try sut.trackForeground()
        try sut.trackDirect()

        // Both should send — foreground should not set skip flag
        #expect(spy.createdEvents.count == 2)
    }

    // MARK: - Universal link deduplication

    @Test("trackDirect is skipped after universal link")
    func trackDirectSkippedAfterUniversalLink() throws {
        let (sut, spy) = makeSUT()

        try sut.track(.universalLink(makeUserActivity()))
        try sut.trackDirect()

        // Only universal link event, direct is skipped
        #expect(spy.createdEvents.count == 1)
        let body = try decodeTrackVisit(from: spy.createdEvents[0])
        #expect(body.source == .link)
    }

    @Test("universal link event contains source=link and requestUrl")
    func universalLinkEventBody() throws {
        let (sut, spy) = makeSUT()
        let url = "https://test-site.s.mindbox.ru/some/path"

        try sut.track(.universalLink(makeUserActivity(url: url)))

        let body = try decodeTrackVisit(from: spy.createdEvents[0])
        #expect(body.source == .link)
        #expect(body.requestUrl?.absoluteString == url)
        #expect(SessionTemporaryStorage.shared.lastTrackVisit?.source == .link)
        #expect(SessionTemporaryStorage.shared.lastTrackVisit?.requestUrl == url)
    }

    // MARK: - Flag resets after skip

    @Test("skip flag resets after one skip — second trackDirect sends direct")
    func skipFlagResetsAfterSkip() throws {
        let (sut, spy) = makeSUT()

        try sut.track(.universalLink(makeUserActivity()))
        try sut.trackDirect()  // skipped
        try sut.trackDirect()  // should send

        #expect(spy.createdEvents.count == 2) // link + second direct
        let firstBody = try decodeTrackVisit(from: spy.createdEvents[0])
        let secondBody = try decodeTrackVisit(from: spy.createdEvents[1])
        #expect(firstBody.source == .link)
        #expect(secondBody.source == .direct)
    }

    // MARK: - Multiple universal links

    @Test("second universal link resets flag — only one direct is skipped")
    func multipleUniversalLinks() throws {
        let (sut, spy) = makeSUT()

        try sut.track(.universalLink(makeUserActivity()))
        try sut.track(.universalLink(makeUserActivity(url: "https://test-site.g.mindbox.ru")))
        try sut.trackDirect()  // skipped
        try sut.trackDirect()  // should send

        // 2 links + 1 direct
        #expect(spy.createdEvents.count == 3)
        let sources = try spy.createdEvents.map { try decodeTrackVisit(from: $0).source }
        #expect(sources == [.link, .link, .direct])
    }

    // MARK: - Keepalive does not break deduplication

    @Test("trackForeground between universal link and trackDirect does not consume skip flag")
    func keepaliveBetweenLinkAndDirect() throws {
        let (sut, spy) = makeSUT()

        try sut.track(.universalLink(makeUserActivity()))
        try sut.trackForeground()  // keepalive — should not consume flag
        try sut.trackDirect()      // should still be skipped

        // link + foreground, direct is skipped
        #expect(spy.createdEvents.count == 2)
        let sources = try spy.createdEvents.map { try decodeTrackVisit(from: $0).source }
        #expect(sources == [.link, nil])
    }

    // MARK: - Normal foreground without push/link

    @Test("trackDirect sends event when no push or link preceded it")
    func trackDirectWithoutPrecedingPushOrLink() throws {
        let (sut, spy) = makeSUT()

        try sut.trackDirect()
        try sut.trackDirect()

        #expect(spy.createdEvents.count == 2)
        let sources = try spy.createdEvents.map { try decodeTrackVisit(from: $0).source }
        #expect(sources == [.direct, .direct])
    }

    // MARK: - handleLaunch with nil options

    @Test("track launch with nil options does not create event")
    func trackLaunchNilOptions() throws {
        let (sut, spy) = makeSUT()

        try sut.track(.launch(nil))

        #expect(spy.createdEvents.isEmpty)
    }
}

// MARK: - Test doubles

private final class SpyDatabaseRepository: DatabaseRepositoryProtocol {
    var createdEvents: [Event] = []

    var limit: Int { 100 }
    var lifeLimitDate: Date? { nil }
    var deprecatedLimit: Int { 0 }
    var onObjectsDidChange: (() -> Void)?

    func create(event: Event) throws {
        createdEvents.append(event)
    }

    func readEvent(by transactionId: String) throws -> Event? { nil }
    func update(event: Event) throws {}
    func delete(event: Event) throws {}
    func query(fetchLimit: Int, retryDeadline: TimeInterval) throws -> [Event] { [] }
    func removeDeprecatedEventsIfNeeded() throws {}
    func countDeprecatedEvents() throws -> Int { 0 }
    func erase() throws {}
    func countEvents() throws -> Int { 0 }
}

private final class StubInappSessionManager: InappSessionManagerProtocol {
    func checkInappSession() {}
}
