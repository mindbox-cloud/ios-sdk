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

    @Test("2xx and 4xx except 429 close the confirmation; 429, 5xx, 3xx and no answer do not")
    func rule() {
        for code in [200, 201, 204, 299, 400, 401, 404, 410, 428, 430, 499] {
            #expect(PushDeliveryConfirmer.closesConfirmation(code), "\(code)")
        }
        for code in [100, 301, 302, 429, 500, 502, 503, 599] {
            #expect(!PushDeliveryConfirmer.closesConfirmation(code), "\(code)")
        }
        #expect(!PushDeliveryConfirmer.closesConfirmation(nil))
    }

    @Test("The file is on disk before the request is answered")
    func fileIsWrittenBeforeRequest() async throws {
        let host = PushDeliveryConfirmationStub.makeHost(answering: .silence)
        let store = PushDeliveryConfirmationStore.temporary()
        let confirmer = PushDeliveryConfirmer(sender: .stubbed(timeout: 0.5), store: store)

        let sending = confirmer.start(try confirmation(host: host))

        #expect(store.fileNames.count == 1)
        await sending.value
    }

    @Test("An answer that closes the confirmation removes the file", arguments: [200, 204, 400, 404, 410])
    func closingAnswerRemovesFile(code: Int) async throws {
        let host = PushDeliveryConfirmationStub.makeHost(answering: .status(code))
        let store = PushDeliveryConfirmationStore.temporary()
        let confirmer = PushDeliveryConfirmer(sender: .stubbed(), store: store)

        await confirmer.start(try confirmation(host: host)).value

        #expect(store.fileNames.isEmpty)
        #expect(PushDeliveryConfirmationStub.requests(to: host).count == 1)
    }

    @Test("An answer that does not close the confirmation leaves the file", arguments: [429, 500, 503])
    func otherAnswerLeavesFile(code: Int) async throws {
        let host = PushDeliveryConfirmationStub.makeHost(answering: .status(code))
        let store = PushDeliveryConfirmationStore.temporary()
        let confirmer = PushDeliveryConfirmer(sender: .stubbed(), store: store)

        await confirmer.start(try confirmation(host: host)).value

        #expect(store.fileNames.count == 1)
        #expect(PushDeliveryConfirmationStub.requests(to: host).count == 1)
    }

    @Test("No answer leaves the file")
    func noAnswerLeavesFile() async throws {
        let host = PushDeliveryConfirmationStub.makeHost(answering: .failure(.timedOut))
        let store = PushDeliveryConfirmationStore.temporary()
        let confirmer = PushDeliveryConfirmer(sender: .stubbed(), store: store)

        await confirmer.start(try confirmation(host: host)).value

        #expect(store.fileNames.count == 1)
    }

    @Test("Without a store the request is still sent")
    func noStoreStillSends() async throws {
        let host = PushDeliveryConfirmationStub.makeHost(answering: .status(200))
        let confirmer = PushDeliveryConfirmer(sender: .stubbed(), store: nil)

        await confirmer.start(try confirmation(host: host)).value

        #expect(PushDeliveryConfirmationStub.requests(to: host).count == 1)
    }

    @Test("The request is finished and the file is removed after the confirmer is released")
    func requestOutlivesConfirmer() async throws {
        let host = PushDeliveryConfirmationStub.makeHost(answering: .status(200))
        let store = PushDeliveryConfirmationStore.temporary()
        var confirmer: PushDeliveryConfirmer? = PushDeliveryConfirmer(sender: .stubbed(), store: store)

        let sending = confirmer?.start(try confirmation(host: host))
        confirmer = nil
        await sending?.value

        #expect(PushDeliveryConfirmationStub.requests(to: host).count == 1)
        #expect(store.fileNames.isEmpty)
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

        #expect(PushDeliveryConfirmationStub.requests(to: host).count == 1)
        #expect(store.fileNames.count == (PushDeliveryConfirmer.closesConfirmation(code) ? 0 : 1))
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
