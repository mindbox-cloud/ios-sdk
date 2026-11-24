//
//  MindboxNotificationServiceTests.swift
//  MindboxNotificationsTests
//
//  Created by Sergei Semko on 8/13/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Testing
import Foundation
import UserNotifications
@testable import MindboxNotifications

@Suite("MindboxNotificationService (NotificationService extension)", .tags(.notifications, .notificationService), .serialized)
struct MindboxNotificationServiceTests {

    let service = MindboxNotificationService()

    // MARK: - didReceive(_:withContentHandler:)

    @Test("didReceive serves the image via a stubbed URL protocol, sets the category and invokes the handler")
    func didReceiveDownloadsImageAndCallsHandler() async {
        StubURLProtocol.reset()
        StubURLProtocol.stubResponseData = NotificationTestFixtures.tinyPNGData()
        URLProtocol.registerClass(StubURLProtocol.self)
        defer {
            URLProtocol.unregisterClass(StubURLProtocol.self)
            StubURLProtocol.reset()
        }

        let request = NotificationTestFixtures.makeRequest(
            userInfo: NotificationTestFixtures.currentFormatUserInfo(),
            title: "Test title",
            body: "Test description"
        )

        let received: UNNotificationContent = await withCheckedContinuation { continuation in
            service.didReceive(request) { content in
                continuation.resume(returning: content)
            }
        }

        #expect(StubURLProtocol.handledRequestCount > 0)
        #expect(service.contentHandler != nil)
        #expect(service.bestAttemptContent != nil)
        #expect(service.bestAttemptContent?.userInfo["uniqueKey"] as? String == NotificationTestFixtures.uniqueKey)
        #expect(received.title == "Test title")
        #expect(received.body == "Test description")
        #expect(received.categoryIdentifier == Constants.categoryIdentifier)
        #expect(service.bestAttemptContent?.attachments.count == 1)
    }

    @Test("didReceive still delivers (no attachment) when the image download fails")
    func didReceiveDeliversWhenDownloadFails() async {
        StubURLProtocol.reset()
        StubURLProtocol.stubError = URLError(.timedOut)
        URLProtocol.registerClass(StubURLProtocol.self)
        defer {
            URLProtocol.unregisterClass(StubURLProtocol.self)
            StubURLProtocol.reset()
        }

        let request = NotificationTestFixtures.makeRequest(
            userInfo: NotificationTestFixtures.currentFormatUserInfo(),
            title: "Test title",
            body: "Test description"
        )

        let received: UNNotificationContent = await withCheckedContinuation { continuation in
            service.didReceive(request) { continuation.resume(returning: $0) }
        }

        #expect(StubURLProtocol.handledRequestCount > 0)
        #expect(received.categoryIdentifier == Constants.categoryIdentifier)
        #expect(received.attachments.isEmpty)
    }

    @Test("didReceive delivers without an attachment when the data is not a recognized image")
    func didReceiveDeliversForUnrecognizedImageData() async {
        StubURLProtocol.reset()
        StubURLProtocol.stubResponseData = Data([0x00, 0x01, 0x02, 0x03])
        URLProtocol.registerClass(StubURLProtocol.self)
        defer {
            URLProtocol.unregisterClass(StubURLProtocol.self)
            StubURLProtocol.reset()
        }

        let request = NotificationTestFixtures.makeRequest(
            userInfo: NotificationTestFixtures.currentFormatUserInfo(),
            title: "Test title",
            body: "Test description"
        )

        let received: UNNotificationContent = await withCheckedContinuation { continuation in
            service.didReceive(request) { continuation.resume(returning: $0) }
        }

        #expect(received.categoryIdentifier == Constants.categoryIdentifier)
        #expect(received.attachments.isEmpty)
    }

    @Test("didReceive without an image URL and a delivered URL invokes the handler before it returns")
    func didReceiveWithoutImageProceedsImmediately() {
        let request = NotificationTestFixtures.makeRequest(
            userInfo: NotificationTestFixtures.currentFormatUserInfo(includeImageUrl: false),
            title: "No image",
            body: "Body"
        )
        var received: UNNotificationContent?

        service.didReceive(request) { received = $0 }

        #expect(received?.categoryIdentifier == Constants.categoryIdentifier)
        #expect(received?.attachments.isEmpty == true)
        #expect(service.bestAttemptContent?.title == "No image")
    }

    @Test("didReceive with an image and a delivered URL confirms, attaches the image and invokes the handler once", arguments: [200, 500])
    func didReceiveDownloadsImageAndConfirms(code: Int) async {
        StubURLProtocol.reset()
        StubURLProtocol.stubResponseData = NotificationTestFixtures.tinyPNGData()
        URLProtocol.registerClass(StubURLProtocol.self)
        defer {
            URLProtocol.unregisterClass(StubURLProtocol.self)
            StubURLProtocol.reset()
        }

        let host = PushDeliveryConfirmationStub.makeHost(answering: .status(code))
        let store = PushDeliveryConfirmationStore.temporary()
        service.deliveryConfirmer = PushDeliveryConfirmer(sender: .stubbed(), store: store, signal: {})
        var userInfo = NotificationTestFixtures.currentFormatUserInfo()
        userInfo["callbacks"] = ["deliveredUrl": "https://\(host)/delivered"]
        let request = NotificationTestFixtures.makeRequest(userInfo: userInfo, title: "Test title", body: "Test description")

        let received: UNNotificationContent = await withCheckedContinuation { continuation in
            service.didReceive(request) { continuation.resume(returning: $0) }
        }

        #expect(StubURLProtocol.handledRequestCount == 1)
        #expect(PushDeliveryConfirmationStub.requests(to: host).count == (code == 200 ? 1 : 3))
        #expect(store.fileNames.count == 1)
        #expect(received.attachments.count == 1)
        #expect(received.categoryIdentifier == Constants.categoryIdentifier)
    }

    @Test("didReceive waits for a slow confirmation after the image is loaded and marks the success before the handler")
    func didReceiveFinishesConfirmationAfterImage() async {
        StubURLProtocol.reset()
        StubURLProtocol.stubResponseData = NotificationTestFixtures.tinyPNGData()
        URLProtocol.registerClass(StubURLProtocol.self)
        defer {
            URLProtocol.unregisterClass(StubURLProtocol.self)
            StubURLProtocol.reset()
        }

        let host = PushDeliveryConfirmationStub.makeHost(answering: .delayedStatus(200, after: 0.5))
        let store = PushDeliveryConfirmationStore.temporary()
        service.deliveryConfirmer = PushDeliveryConfirmer(sender: .stubbed(), store: store, signal: {})
        var userInfo = NotificationTestFixtures.currentFormatUserInfo()
        userInfo["callbacks"] = ["deliveredUrl": "https://\(host)/delivered"]
        let request = NotificationTestFixtures.makeRequest(userInfo: userInfo, title: "Test title", body: "Test description")
        let started = Date()

        let filesAtHandler: [String] = await withCheckedContinuation { continuation in
            service.didReceive(request) { _ in continuation.resume(returning: store.fileNames) }
        }

        #expect(Date().timeIntervalSince(started) >= 0.5)
        #expect(filesAtHandler == ["last-success"])
        #expect(service.bestAttemptContent?.attachments.count == 1)
        #expect(PushDeliveryConfirmationStub.requests(to: host).count == 1)
    }

    @Test("The push is shown only after the third attempt")
    func pushWaitsForAllAttempts() async {
        let host = PushDeliveryConfirmationStub.makeHost(answering: .status(500))
        service.deliveryConfirmer = PushDeliveryConfirmer(
            sender: .stubbed(),
            store: PushDeliveryConfirmationStore.temporary(),
            signal: {}
        )
        var userInfo = NotificationTestFixtures.currentFormatUserInfo(includeImageUrl: false)
        userInfo["callbacks"] = ["deliveredUrl": "https://\(host)/delivered"]
        let request = NotificationTestFixtures.makeRequest(userInfo: userInfo, title: "Test title", body: "Test description")

        let requestsAtHandler: Int = await withCheckedContinuation { continuation in
            service.didReceive(request) { _ in
                continuation.resume(returning: PushDeliveryConfirmationStub.requests(to: host).count)
            }
        }

        #expect(requestsAtHandler == 3)
    }

    // MARK: - serviceExtensionTimeWillExpire()

    @Test("serviceExtensionTimeWillExpire delivers the stored best-attempt content")
    func serviceExtensionTimeWillExpireDelivers() {
        let content = NotificationTestFixtures.makeContent(userInfo: [:], title: "t", body: "b")
        service.bestAttemptContent = content

        var received: UNNotificationContent?
        service.contentHandler = { received = $0 }

        service.serviceExtensionTimeWillExpire()

        #expect(received != nil)
        #expect(received?.categoryIdentifier == Constants.categoryIdentifier)
    }

    @Test("serviceExtensionTimeWillExpire is a no-op without best-attempt content")
    func serviceExtensionTimeWillExpireNoContent() {
        var called = false
        service.contentHandler = { _ in called = true }

        service.serviceExtensionTimeWillExpire()

        #expect(!called)
    }

    // MARK: - pushDelivered(_:)

    @Test("pushDelivered runs without producing best-attempt content")
    func pushDeliveredRuns() {
        let request = NotificationTestFixtures.makeRequest(userInfo: NotificationTestFixtures.currentFormatUserInfo())
        service.pushDelivered(request)
        #expect(service.bestAttemptContent == nil)
    }
}
