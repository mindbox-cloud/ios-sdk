//
//  NotificationTestFixtures.swift
//  MindboxNotificationsTests
//
//  Created by Sergei Semko on 6/16/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import UIKit
import UserNotifications
@testable import MindboxNotifications

enum NotificationTestFixtures {

    static let clickUrl = "https://mindbox.ru/"
    static let uniqueKey = "4cccb64d-ba46-41eb-9699-3a706f2b910b"
    static let imageUrl = "https://mobpush-images.mindbox.ru/Mpush-test/63/5933f4cd-47e3-4317-9237-bc5aad291aa9.png"
    static let payloadString = "{\n  \"payload\": \"data\"\n}"

    static let firstButtonKey = "1b112bcd-5eae-4914-8842-d77198466466"
    static let secondButtonKey = "cff05f38-6df4-4a10-9859-ea3bf0a65068"

    static let buttons: [[String: Any]] = [
        [
            "url": "https://developers.mindbox.ru/docs/mindbox-sdk",
            "text": "Documentation",
            "uniqueKey": firstButtonKey
        ],
        [
            "url": "https://google.com",
            "text": "Button #1",
            "uniqueKey": secondButtonKey
        ]
    ]

    static func currentFormatUserInfo(
        includeBody: Bool = true,
        includeClickUrl: Bool = true,
        includeButtons: Bool = true,
        includeImageUrl: Bool = true
    ) -> [AnyHashable: Any] {
        var alert: [String: Any] = ["title": "Test title"]
        if includeBody { alert["body"] = "Test description" }

        let aps: [String: Any] = [
            "mutable-content": 1,
            "alert": alert,
            "content-available": 1,
            "sound": "default"
        ]

        var userInfo: [AnyHashable: Any] = [
            "payload": payloadString,
            "uniqueKey": uniqueKey,
            "aps": aps
        ]
        if includeClickUrl { userInfo["clickUrl"] = clickUrl }
        if includeButtons { userInfo["buttons"] = buttons }
        if includeImageUrl { userInfo["imageUrl"] = imageUrl }
        return userInfo
    }

    static func legacyFormatUserInfo(
        includeBody: Bool = true,
        includeClickUrl: Bool = true,
        includeButtons: Bool = true
    ) -> [AnyHashable: Any] {
        var alert: [String: Any] = ["title": "Test title"]
        if includeBody { alert["body"] = "Test description" }

        var aps: [String: Any] = [
            "mutable-content": 1,
            "alert": alert,
            "content-available": 1,
            "sound": "default",
            "uniqueKey": uniqueKey,
            "imageUrl": imageUrl,
            "payload": payloadString
        ]
        if includeClickUrl { aps["clickUrl"] = clickUrl }
        if includeButtons { aps["buttons"] = buttons }
        return ["aps": aps]
    }

    static func makeContent(
        userInfo: [AnyHashable: Any],
        title: String? = nil,
        body: String? = nil
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.userInfo = userInfo
        if let title { content.title = title }
        if let body { content.body = body }
        return content
    }

    static func makeRequest(
        userInfo: [AnyHashable: Any],
        title: String? = nil,
        body: String? = nil
    ) -> UNNotificationRequest {
        let content = makeContent(userInfo: userInfo, title: title, body: body)
        return UNNotificationRequest(identifier: "test", content: content, trigger: nil)
    }

    static func tinyPNGData() -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).pngData { _ in }
    }

    static func makeImageAttachment() throws -> UNNotificationAttachment {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("testImage_\(UUID().uuidString).png")
        try tinyPNGData().write(to: fileURL)
        return try UNNotificationAttachment(identifier: "identifier", url: fileURL, options: nil)
    }
}

// MARK: - Test doubles

final class MockExtensionContext: NSExtensionContext {
    private var actions: [UNNotificationAction] = []

    override var notificationActions: [UNNotificationAction] {
        get { actions }
        set { actions = newValue }
    }
}

// `UNNotification` has no public initializer, so build one by round-tripping through secure coding.
// swiftlint:disable force_unwrapping force_try
final class MockUNNotification: UNNotification {
    private let mockRequest: UNNotificationRequest

    init(request: UNNotificationRequest) {
        self.mockRequest = request
        let data = try! NSKeyedArchiver.archivedData(withRootObject: request, requiringSecureCoding: true)
        let coder = try! NSKeyedUnarchiver(forReadingFrom: data)
        super.init(coder: coder)!
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var request: UNNotificationRequest {
        mockRequest
    }
}
// swiftlint:enable force_unwrapping force_try

// MARK: - URLProtocol stub

/// Intercepts `URLSession.shared` requests so the notification-service download path runs
/// against a local image instead of a real network fetch. Serves `stubResponseData` for
/// every request while registered, and counts how many it handled.
class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var stubResponseData: Data?
    nonisolated(unsafe) static var stubError: Error?
    nonisolated(unsafe) static var handledRequestCount = 0

    static func reset() {
        stubResponseData = nil
        stubError = nil
        handledRequestCount = 0
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        StubURLProtocol.handledRequestCount += 1
        if let error = StubURLProtocol.stubError {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        if let url = request.url,
           let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil) {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        if let data = StubURLProtocol.stubResponseData {
            client?.urlProtocol(self, didLoad: data)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
