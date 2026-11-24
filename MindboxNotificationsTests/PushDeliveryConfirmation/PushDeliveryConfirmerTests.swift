//
//  PushDeliveryConfirmerTests.swift
//  MindboxNotificationsTests
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
import UserNotifications
@testable import MindboxNotifications

@Suite("Push delivery confirmation: sending, file and the push itself", .tags(.notifications, .pushDeliveryConfirmation))
struct PushDeliveryConfirmerTests {

    private func confirmation(host: String, receivedAt: Date = Date()) throws -> PushDeliveryConfirmation {
        PushDeliveryConfirmation(url: try #require(URL(string: "https://\(host)/delivered?id=42")), receivedAt: receivedAt)
    }

    // MARK: - Sender

    @Test("The sender makes one POST with the body {} and the SDK headers and returns the status code")
    func senderSendsRequest() async throws {
        let host = PushDeliveryConfirmationStub.makeHost(answering: .status(200))

        let statusCode = await PushDeliveryConfirmationSender.stubbed().send(try confirmation(host: host))

        let requests = PushDeliveryConfirmationStub.requests(to: host)
        #expect(statusCode == 200)
        #expect(requests.count == 1)
        let request = try #require(requests.first)
        #expect(request.httpMethod == "POST")
        #expect(PushDeliveryConfirmationStub.body(of: request) == Data("{}".utf8))
        #expect(request.value(forHTTPHeaderField: "Mindbox-Integration") == "iOS-SDK")
        #expect(request.value(forHTTPHeaderField: "Mindbox-Integration-Version") == SDKVersionProvider.sdkVersion)
        #expect(request.value(forHTTPHeaderField: "User-Agent")?.hasPrefix("mindbox.sdk/") == true)
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json; charset=utf-8")
        #expect(request.url?.query?.hasPrefix("id=42&dateTimeOffset=") == true)
    }

    @Test("The sender returns the status code of any answer", arguments: [204, 400, 404, 429, 500, 503])
    func senderReturnsStatusCode(code: Int) async throws {
        let host = PushDeliveryConfirmationStub.makeHost(answering: .status(code))

        #expect(await PushDeliveryConfirmationSender.stubbed().send(try confirmation(host: host)) == code)
    }

    @Test("The sender does not follow a redirect and returns its status code")
    func senderDoesNotFollowRedirect() async throws {
        let target = PushDeliveryConfirmationStub.makeHost(answering: .status(200))
        let host = PushDeliveryConfirmationStub.makeHost(answering: .redirect(to: "https://\(target)/elsewhere"))

        let statusCode = await PushDeliveryConfirmationSender.stubbed().send(try confirmation(host: host))

        #expect(statusCode == 302)
        #expect(PushDeliveryConfirmationStub.requests(to: target).isEmpty)
    }

    @Test("Without an answer the sender returns nil")
    func senderReturnsNilWithoutAnswer() async throws {
        let host = PushDeliveryConfirmationStub.makeHost(answering: .failure(.notConnectedToInternet))

        #expect(await PushDeliveryConfirmationSender.stubbed().send(try confirmation(host: host)) == nil)
    }

    @Test("The sender waits for the answer for 3 seconds by default")
    func defaultTimeoutIsThreeSeconds() {
        #expect(PushDeliveryConfirmationSender.responseTimeout == 3)
    }

    @Test("The sender stops waiting when the time is over")
    func senderStopsWaiting() async throws {
        let host = PushDeliveryConfirmationStub.makeHost(answering: .silence)
        let started = Date()

        let statusCode = await PushDeliveryConfirmationSender.stubbed(timeout: 0.3).send(try confirmation(host: host))

        #expect(statusCode == nil)
        #expect(Date().timeIntervalSince(started) < 3)
    }

    // MARK: - Confirmer

    private final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private var count = 0

        var value: Int { lock.withLock { count } }

        func increment() { lock.withLock { count += 1 } }
    }

    private func jsonObject(at url: URL) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    }

    private func offsets(to host: String) -> [Int64] {
        PushDeliveryConfirmationStub.requests(to: host).compactMap { request in
            request.url?.query?.components(separatedBy: "&").last?.components(separatedBy: "=").last.flatMap { Int64($0) }
        }
    }

    @Test("The status code decides the outcome", arguments: [
        (200, PushDeliveryConfirmer.Outcome.delivered), (204, .delivered),
        (301, .rejected), (302, .rejected), (400, .rejected), (404, .rejected), (410, .rejected),
        (429, .retry), (500, .retry), (503, .retry), (199, .retry), (600, .retry)
    ])
    func outcome(code: Int, expected: PushDeliveryConfirmer.Outcome) {
        #expect(PushDeliveryConfirmer.outcome(of: code) == expected)
    }

    @Test("No answer means another attempt")
    func outcomeWithoutAnswer() {
        #expect(PushDeliveryConfirmer.outcome(of: nil) == .retry)
    }

    @Test("The file is on disk before the request is answered")
    func fileIsWrittenBeforeRequest() async throws {
        let host = PushDeliveryConfirmationStub.makeHost(answering: .silence)
        let store = PushDeliveryConfirmationStore.temporary()
        let confirmer = PushDeliveryConfirmer(sender: .stubbed(timeout: 0.2), store: store)
        let confirmation = try confirmation(host: host)

        let sending = confirmer.start(confirmation)

        #expect(store.fileNames == [store.fileURL(for: confirmation, state: .pending).lastPathComponent])
        await sending.value
    }

    @Test("The first success removes the record and marks the success")
    func succeedsAtOnce() async throws {
        let host = PushDeliveryConfirmationStub.makeHost(answering: .status(200))
        let store = PushDeliveryConfirmationStore.temporary()
        let confirmer = PushDeliveryConfirmer(sender: .stubbed(), store: store)

        await confirmer.start(try confirmation(host: host)).value

        #expect(PushDeliveryConfirmationStub.requests(to: host).count == 1)
        #expect(store.fileNames == ["last-success"])
    }

    @Test("A success on the third attempt is still a success")
    func succeedsOnThirdAttempt() async throws {
        let host = PushDeliveryConfirmationStub.makeHost(answering: .sequence([.status(500), .status(500), .status(200)]))
        let store = PushDeliveryConfirmationStore.temporary()
        let confirmer = PushDeliveryConfirmer(sender: .stubbed(), store: store)

        await confirmer.start(try confirmation(host: host)).value

        #expect(PushDeliveryConfirmationStub.requests(to: host).count == 3)
        #expect(store.fileNames == ["last-success"])
    }

    @Test("Three failures hand the record over with the last answer", arguments: [429, 500, 503])
    func handsOver(code: Int) async throws {
        let host = PushDeliveryConfirmationStub.makeHost(answering: .status(code))
        let store = PushDeliveryConfirmationStore.temporary()
        let now = Date(timeIntervalSince1970: 1_800_000_010)
        let confirmer = PushDeliveryConfirmer(sender: .stubbed(), store: store, now: { now })
        let confirmation = try confirmation(host: host)

        await confirmer.start(confirmation).value

        #expect(PushDeliveryConfirmationStub.requests(to: host).count == 3)
        #expect(store.fileNames == [store.fileURL(for: confirmation, state: .released).lastPathComponent])
        let json = try jsonObject(at: store.fileURL(for: confirmation, state: .released))
        #expect(json["lastStatusCode"] as? Int == code)
        #expect(json["lastAttemptAt"] as? Int64 == 1_800_000_010_000)
    }

    @Test("A final refusal stops the attempts and removes the record", arguments: [302, 400, 404])
    func refusalStops(code: Int) async throws {
        let host = PushDeliveryConfirmationStub.makeHost(answering: .status(code))
        let store = PushDeliveryConfirmationStore.temporary()
        let confirmer = PushDeliveryConfirmer(sender: .stubbed(), store: store)

        await confirmer.start(try confirmation(host: host)).value

        #expect(PushDeliveryConfirmationStub.requests(to: host).count == 1)
        #expect(store.fileNames.isEmpty)
    }

    @Test("Three silent attempts hand the record over without a status code")
    func silenceHandsOver() async throws {
        let host = PushDeliveryConfirmationStub.makeHost(answering: .silence)
        let store = PushDeliveryConfirmationStore.temporary()
        let confirmer = PushDeliveryConfirmer(sender: .stubbed(timeout: 0.2), store: store)
        let confirmation = try confirmation(host: host)

        await confirmer.start(confirmation).value

        #expect(PushDeliveryConfirmationStub.requests(to: host).count == 3)
        let json = try jsonObject(at: store.fileURL(for: confirmation, state: .released))
        #expect(json["lastStatusCode"] == nil)
        #expect(json["lastAttemptAt"] != nil)
    }

    @Test("The next attempt goes at once, without a pause")
    func noPauseBetweenAttempts() async throws {
        let host = PushDeliveryConfirmationStub.makeHost(answering: .status(500))
        let confirmer = PushDeliveryConfirmer(sender: .stubbed(), store: PushDeliveryConfirmationStore.temporary())
        let started = Date()

        await confirmer.start(try confirmation(host: host)).value

        #expect(PushDeliveryConfirmationStub.requests(to: host).count == 3)
        #expect(Date().timeIntervalSince(started) < 1)
    }

    @Test("Every attempt recomputes dateTimeOffset from the receive time")
    func offsetGrows() async throws {
        let host = PushDeliveryConfirmationStub.makeHost(answering: .delayedStatus(500, after: 0.2))
        let confirmer = PushDeliveryConfirmer(sender: .stubbed(), store: PushDeliveryConfirmationStore.temporary())

        await confirmer.start(try confirmation(host: host, receivedAt: Date().addingTimeInterval(-5))).value

        let offsets = offsets(to: host)
        #expect(offsets.count == 3)
        #expect(offsets[0] >= 5000)
        #expect(offsets[2] >= offsets[0] + 300)
    }

    @Test("Without a store the confirmer still tries three times")
    func withoutStoreStillTriesThreeTimes() async throws {
        let host = PushDeliveryConfirmationStub.makeHost(answering: .status(500))
        let completions = Counter()
        let confirmer = PushDeliveryConfirmer(sender: .stubbed(), store: nil)

        await confirmer.start(try confirmation(host: host)) { completions.increment() }.value

        #expect(PushDeliveryConfirmationStub.requests(to: host).count == 3)
        #expect(completions.value == 1)
    }

    @Test("The same URL twice leaves one consistent record")
    func sameUrlTwiceLeavesOneConsistentRecord() async throws {
        let host = PushDeliveryConfirmationStub.makeHost(answering: .status(500))
        let store = PushDeliveryConfirmationStore.temporary()
        let confirmer = PushDeliveryConfirmer(sender: .stubbed(), store: store)
        let confirmation = try confirmation(host: host)

        let first = confirmer.start(confirmation)
        let second = confirmer.start(confirmation)
        await first.value
        await second.value

        #expect(store.fileNames == [store.fileURL(for: confirmation, state: .released).lastPathComponent])
        let data = try Data(contentsOf: store.fileURL(for: confirmation, state: .released))
        let record = try JSONDecoder().decode(PushDeliveryConfirmationStore.Record.self, from: data)
        #expect(record.url == confirmation.url.absoluteString)
        #expect(record.lastStatusCode == 500)
    }

    @Test("The request is finished and the record is removed after the confirmer is released")
    func requestOutlivesConfirmer() async throws {
        let host = PushDeliveryConfirmationStub.makeHost(answering: .status(200))
        let store = PushDeliveryConfirmationStore.temporary()
        var confirmer: PushDeliveryConfirmer? = PushDeliveryConfirmer(sender: .stubbed(), store: store)

        let sending = confirmer?.start(try confirmation(host: host))
        confirmer = nil
        await sending?.value

        #expect(PushDeliveryConfirmationStub.requests(to: host).count == 1)
        #expect(store.fileNames == ["last-success"])
    }

    // MARK: - didReceive

    private func show(userInfo: [AnyHashable: Any], confirmer: PushDeliveryConfirmer) async -> UNNotificationContent {
        let service = MindboxNotificationService()
        service.deliveryConfirmer = confirmer
        let request = NotificationTestFixtures.makeRequest(userInfo: userInfo, title: "Test title", body: "Test description")
        return await withCheckedContinuation { continuation in
            service.didReceive(request) { continuation.resume(returning: $0) }
        }
    }

    private func userInfo(host: String?) -> [AnyHashable: Any] {
        var userInfo = NotificationTestFixtures.currentFormatUserInfo(includeImageUrl: false)
        if let host {
            userInfo["callbacks"] = ["deliveredUrl": "https://\(host)/delivered"]
        }
        return userInfo
    }

    @Test("didReceive confirms the delivery and then shows the push", arguments: [200, 404, 429, 500])
    func didReceiveConfirmsThenShows(code: Int) async {
        let host = PushDeliveryConfirmationStub.makeHost(answering: .status(code))
        let store = PushDeliveryConfirmationStore.temporary()

        let content = await show(userInfo: userInfo(host: host), confirmer: PushDeliveryConfirmer(sender: .stubbed(), store: store))

        let outcome = PushDeliveryConfirmer.outcome(of: code)
        #expect(PushDeliveryConfirmationStub.requests(to: host).count == (outcome == .retry ? 3 : 1))
        #expect(store.fileNames.count == (outcome == .rejected ? 0 : 1))
        #expect(content.title == "Test title")
        #expect(content.categoryIdentifier == Constants.categoryIdentifier)
    }

    @Test("didReceive shows the push when the confirmation gets no answer in time")
    func didReceiveShowsWithoutAnswer() async {
        let host = PushDeliveryConfirmationStub.makeHost(answering: .silence)
        let store = PushDeliveryConfirmationStore.temporary()

        let content = await show(userInfo: userInfo(host: host), confirmer: PushDeliveryConfirmer(sender: .stubbed(timeout: 0.3), store: store))

        #expect(store.fileNames.count == 1)
        #expect(content.categoryIdentifier == Constants.categoryIdentifier)
    }

    @Test("didReceive sends nothing and writes nothing for a push without the delivered URL")
    func didReceiveWithoutUrl() async {
        let store = PushDeliveryConfirmationStore.temporary()

        let content = await show(userInfo: userInfo(host: nil), confirmer: PushDeliveryConfirmer(sender: .stubbed(), store: store))

        #expect(store.fileNames.isEmpty)
        #expect(content.categoryIdentifier == Constants.categoryIdentifier)
    }

    @Test("didReceive reads the delivered URL of a push in the legacy format")
    func didReceiveLegacyFormat() async {
        let host = PushDeliveryConfirmationStub.makeHost(answering: .status(200))
        var userInfo = NotificationTestFixtures.legacyFormatUserInfo()
        var aps = userInfo["aps"] as? [String: Any] ?? [:]
        aps["callbacks"] = ["deliveredUrl": "https://\(host)/delivered"]
        aps["imageUrl"] = nil
        userInfo["aps"] = aps

        _ = await show(userInfo: userInfo, confirmer: PushDeliveryConfirmer(sender: .stubbed(), store: nil))

        #expect(PushDeliveryConfirmationStub.requests(to: host).count == 1)
    }
}
