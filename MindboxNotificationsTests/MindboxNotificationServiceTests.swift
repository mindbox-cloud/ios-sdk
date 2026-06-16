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

// Serialized: the download tests register a process-global stub `URLProtocol` and share its
// static state, so they must not run concurrently with each other.
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

        #expect(StubURLProtocol.handledRequestCount > 0) // served from the stub, never the real network
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
        StubURLProtocol.stubResponseData = Data([0x00, 0x01, 0x02, 0x03]) // unknown magic byte -> ImageFormat is nil
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

    @Test("didReceive without an image URL delivers immediately and without an attachment")
    func didReceiveWithoutImageProceedsImmediately() async {
        let request = NotificationTestFixtures.makeRequest(
            userInfo: NotificationTestFixtures.currentFormatUserInfo(includeImageUrl: false),
            title: "No image",
            body: "Body"
        )

        let received: UNNotificationContent = await withCheckedContinuation { continuation in
            service.didReceive(request) { content in
                continuation.resume(returning: content)
            }
        }

        #expect(received.categoryIdentifier == Constants.categoryIdentifier)
        #expect(received.attachments.isEmpty)
        #expect(service.bestAttemptContent?.title == "No image")
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
