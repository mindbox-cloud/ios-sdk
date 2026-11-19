//
//  PushDeliveryConfirmerTests.swift
//  MindboxNotificationsTests
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
import UserNotifications
@_spi(Internal) @testable import MindboxNotifications

@Suite("Push delivery confirmation: notification service extension", .tags(.notifications, .deliveryConfirmation))
struct PushDeliveryConfirmerTests {

    private let store = PushDeliveryConfirmationStore(
        directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    )

    private func service(timeout: TimeInterval = 5) -> MindboxNotificationService {
        let service = MindboxNotificationService()
        service.deliveryConfirmer = PushDeliveryConfirmer(sender: PushDeliveryConfirmationStub.sender(timeout: timeout), store: store)
        return service
    }

    private func request(host: String?) -> UNNotificationRequest {
        var userInfo = NotificationTestFixtures.currentFormatUserInfo(includeImageUrl: false)
        if let host {
            userInfo["callbacks"] = ["deliveredUrl": "https://\(host)/delivered"]
        }
        return NotificationTestFixtures.makeRequest(userInfo: userInfo, title: "Title", body: "Body")
    }

    // MARK: - confirmDelivery(_:)

    @Test("A delivered or refused confirmation leaves no file for the app", arguments: [200, 204, 400, 404])
    func finalAnswerLeavesNoFile(code: Int) async {
        let host = PushDeliveryConfirmationStub.makeHost(answer: .status(code))

        await service().confirmDelivery(request(host: host))

        #expect(PushDeliveryConfirmationStub.requests(to: host).count == 1)
        #expect(store.pending().isEmpty)
    }

    @Test("A confirmation without an answer stays on disk for the app", arguments: [
        PushDeliveryConfirmationStub.Answer.status(429),
        .status(500),
        .status(503),
        .failure(URLError(.notConnectedToInternet))
    ])
    func failedConfirmationStaysForTheApp(answer: PushDeliveryConfirmationStub.Answer) async throws {
        let host = PushDeliveryConfirmationStub.makeHost(answer: answer)

        await service().confirmDelivery(request(host: host))

        #expect(PushDeliveryConfirmationStub.requests(to: host).count == 1)
        let pending = try #require(store.pending().first)
        #expect(pending.url.absoluteString == "https://\(host)/delivered")
    }

    @Test("confirmDelivery gives up at the timeout and keeps the file")
    func confirmDeliveryStopsAtTimeout() async {
        let host = PushDeliveryConfirmationStub.makeHost(answer: .silence)
        let started = Date()

        await service(timeout: 0.5).confirmDelivery(request(host: host))

        #expect(Date().timeIntervalSince(started) < 4)
        #expect(store.pending().count == 1)
    }

    @Test("A push without a confirmation URL sends nothing and writes nothing")
    func noURLNoRequest() async {
        await service().confirmDelivery(request(host: nil))
        #expect(store.pending().isEmpty)
    }

    // MARK: - start(_:)

    @Test("The confirmation is on disk before start returns: the system may stop the extension right after")
    func startWritesFileBeforeReturning() throws {
        let host = PushDeliveryConfirmationStub.makeHost(answer: .silence)
        let url = try #require(URL(string: "https://\(host)/delivered"))
        let confirmer = PushDeliveryConfirmer(sender: PushDeliveryConfirmationStub.sender(timeout: 1), store: store)

        _ = confirmer.start(PushDeliveryConfirmation(url: url, receivedAt: Date()))

        #expect(store.pending().map(\.url) == [url])
    }

    // MARK: - pushDelivered(_:)

    @Test("pushDelivered only writes the log: it sends nothing and leaves no file")
    func pushDeliveredSendsNothing() async throws {
        let host = PushDeliveryConfirmationStub.makeHost(answer: .status(200))

        service().pushDelivered(request(host: host))
        try await Task.sleep(nanoseconds: 300_000_000)

        #expect(PushDeliveryConfirmationStub.requests(to: host).isEmpty)
        #expect(store.pending().isEmpty)
    }

    @Test("An app that calls pushDelivered and then didReceive sends one confirmation")
    func pushDeliveredAndDidReceiveSendOnce() async {
        let host = PushDeliveryConfirmationStub.makeHost(answer: .status(200))
        let service = service()
        let request = request(host: host)

        service.pushDelivered(request)
        await withCheckedContinuation { continuation in
            service.didReceive(request) { _ in continuation.resume() }
        }

        #expect(PushDeliveryConfirmationStub.requests(to: host).count == 1)
    }

    // MARK: - didReceive(_:withContentHandler:)

    @Test("didReceive shows the push only after the answer comes")
    func didReceiveWaitsForAnswer() async {
        let host = PushDeliveryConfirmationStub.makeHost(answer: .status(200))
        let service = service()

        let content: UNNotificationContent = await withCheckedContinuation { continuation in
            service.didReceive(request(host: host)) { continuation.resume(returning: $0) }
        }

        #expect(PushDeliveryConfirmationStub.requests(to: host).count == 1)
        #expect(store.pending().isEmpty)
        #expect(content.title == "Title")
    }

    @Test("didReceive shows the push at the timeout when there is no answer")
    func didReceiveShowsPushAtTimeout() async {
        let host = PushDeliveryConfirmationStub.makeHost(answer: .silence)
        let service = service(timeout: 0.5)
        let started = Date()

        let content: UNNotificationContent = await withCheckedContinuation { continuation in
            service.didReceive(request(host: host)) { continuation.resume(returning: $0) }
        }

        #expect(Date().timeIntervalSince(started) >= 0.4)
        #expect(Date().timeIntervalSince(started) < 4)
        #expect(content.categoryIdentifier == Constants.categoryIdentifier)
        #expect(store.pending().count == 1)
    }

    @Test("didReceive shows the push without an image even when the app keeps no reference to the service, then lets it go")
    func didReceiveShowsPushWithoutReferenceToService() async {
        let request = request(host: PushDeliveryConfirmationStub.makeHost(answer: .status(200)))
        weak var released: MindboxNotificationService?

        await confirmation("The push is shown") { shown in
            do {
                let service = service()
                released = service
                service.didReceive(request) { _ in shown() }
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }

        #expect(released == nil)
    }

    // MARK: - App Group

    @Test("The extension writes to the App Group of the host app")
    func hostAppGroupIsGroupOfHostApp() throws {
        let app = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString)/Host.app", isDirectory: true)
        let appex = app.appendingPathComponent("PlugIns/Service.appex", isDirectory: true)
        try writeBundle(at: app, identifier: "com.example.host")
        try writeBundle(at: appex, identifier: "com.example.host.service")
        let bundle = try #require(Bundle(url: appex))

        #expect(PushDeliveryConfirmationStore.hostAppGroupIdentifier(bundle: bundle) == "group.cloud.Mindbox.com.example.host")
        #expect(PushDeliveryConfirmationStore.hostAppGroupIdentifier(bundle: try #require(Bundle(url: app))) == "group.cloud.Mindbox.com.example.host")
    }

    // MARK: - Helpers

    private func writeBundle(at url: URL, identifier: String) throws {
        let contents = url.appendingPathComponent("Info.plist")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let plist: [String: Any] = ["CFBundleIdentifier": identifier, "CFBundlePackageType": "APPL"]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: contents)
    }
}
