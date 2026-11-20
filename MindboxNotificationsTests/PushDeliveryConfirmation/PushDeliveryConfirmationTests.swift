//
//  PushDeliveryConfirmationTests.swift
//  MindboxNotificationsTests
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
import UIKit
@testable import MindboxNotifications

@Suite("Push delivery confirmation: push parsing and request", .tags(.notifications, .pushDeliveryConfirmation))
struct PushDeliveryConfirmationTests {

    private let receivedAt = Date(timeIntervalSince1970: 1_800_000_000)

    private func userInfo(deliveredUrl: Any?) -> [AnyHashable: Any] {
        var userInfo = NotificationTestFixtures.currentFormatUserInfo()
        if let deliveredUrl {
            userInfo["callbacks"] = ["deliveredUrl": deliveredUrl]
        }
        return userInfo
    }

    private func parsed(_ userInfo: [AnyHashable: Any]) -> PushDeliveryConfirmation? {
        let request = NotificationTestFixtures.makeRequest(userInfo: userInfo)
        let payload = MindboxNotificationService().parse(request: request)
        return PushDeliveryConfirmation(deliveredUrl: payload?.withCallbacks?.callbacks?.deliveredUrl, receivedAt: receivedAt)
    }

    // MARK: - Parsing

    @Test("The delivered URL is taken from callbacks.deliveredUrl as the push gave it")
    func takesDeliveredUrl() throws {
        let string = "https://api.mindbox.ru/push/delivered?id=42&hash=a%2Bb%3D"
        let confirmation = try #require(parsed(userInfo(deliveredUrl: string)))

        #expect(confirmation.url.absoluteString == string)
        #expect(confirmation.receivedAt == receivedAt)
    }

    @Test("The delivered URL of a push in the legacy format is taken from aps.callbacks.deliveredUrl")
    func takesDeliveredUrlFromLegacyFormat() throws {
        var userInfo = NotificationTestFixtures.legacyFormatUserInfo()
        var aps = userInfo["aps"] as? [String: Any] ?? [:]
        aps["callbacks"] = ["deliveredUrl": "https://api.mindbox.ru/push/delivered"]
        userInfo["aps"] = aps

        #expect(parsed(userInfo)?.url.absoluteString == "https://api.mindbox.ru/push/delivered")
    }

    @Test("A push without the delivered URL gives no confirmation")
    func noUrlNoConfirmation() {
        #expect(parsed(userInfo(deliveredUrl: nil)) == nil)
        #expect(parsed(["callbacks": [String: Any]()]) == nil)
        #expect(parsed(["callbacks": "https://api.mindbox.ru"]) == nil)
        #expect(PushDeliveryConfirmation(deliveredUrl: nil) == nil)
    }

    @Test("callbacks or deliveredUrl sent as null give no confirmation and keep the image")
    func nullGivesNoConfirmation() {
        for callbacks in [NSNull(), ["deliveredUrl": NSNull()]] as [Any] {
            var userInfo = NotificationTestFixtures.currentFormatUserInfo()
            userInfo["callbacks"] = callbacks
            let payload = MindboxNotificationService().parse(request: NotificationTestFixtures.makeRequest(userInfo: userInfo))

            #expect(parsed(userInfo) == nil)
            #expect(payload?.withImageURL?.imageUrl == NotificationTestFixtures.imageUrl)
        }
    }

    @Test(
        "A URL that is not a valid https address gives no confirmation",
        arguments: ["http://api.mindbox.ru/delivered", "ftp://api.mindbox.ru/delivered", "api.mindbox.ru/delivered", "https://", "", "https://exa mple.com/x"]
    )
    func invalidUrlNoConfirmation(string: String) {
        #expect(parsed(userInfo(deliveredUrl: string)) == nil)
    }

    @Test("A delivered URL that is not a string gives no confirmation")
    func nonStringUrlNoConfirmation() {
        #expect(parsed(userInfo(deliveredUrl: 42)) == nil)
    }

    @Test("A push with broken callbacks still gives its image")
    func brokenCallbacksKeepImage() {
        var userInfo = userInfo(deliveredUrl: 42)
        userInfo["imageUrl"] = NotificationTestFixtures.imageUrl
        let payload = MindboxNotificationService().parse(request: NotificationTestFixtures.makeRequest(userInfo: userInfo))

        #expect(payload?.withCallbacks == nil)
        #expect(payload?.withImageURL?.imageUrl == NotificationTestFixtures.imageUrl)
    }

    // MARK: - Request

    private func confirmation(_ string: String = "https://api.mindbox.ru/push/delivered") throws -> PushDeliveryConfirmation {
        PushDeliveryConfirmation(url: try #require(URL(string: string)), receivedAt: receivedAt)
    }

    @Test("The request is a POST with the body {}")
    func requestIsPostWithEmptyObject() throws {
        let request = try confirmation().request(sentAt: receivedAt)

        #expect(request.httpMethod == "POST")
        #expect(request.httpBody == Data("{}".utf8))
    }

    @Test("dateTimeOffset is the milliseconds from receiving the push to sending the request")
    func offsetIsMilliseconds() throws {
        let request = try confirmation().request(sentAt: receivedAt.addingTimeInterval(1.234))

        #expect(request.url?.absoluteString == "https://api.mindbox.ru/push/delivered?dateTimeOffset=1234")
    }

    @Test("dateTimeOffset is never negative")
    func offsetIsNotNegative() throws {
        let request = try confirmation().request(sentAt: receivedAt.addingTimeInterval(-5))

        #expect(request.url?.absoluteString == "https://api.mindbox.ru/push/delivered?dateTimeOffset=0")
    }

    @Test("Only dateTimeOffset is added: other query parameters keep their order and encoding")
    func otherParametersKeepTheirEncoding() throws {
        let request = try confirmation("https://api.mindbox.ru/push/delivered?id=42&hash=a%2Bb%3D&name=%D1%8F")
            .request(sentAt: receivedAt.addingTimeInterval(0.5))

        #expect(request.url?.absoluteString == "https://api.mindbox.ru/push/delivered?id=42&hash=a%2Bb%3D&name=%D1%8F&dateTimeOffset=500")
    }

    // MARK: - Headers

    @Test("The request carries the same four headers as the requests of the main module")
    func requestCarriesSDKHeaders() throws {
        let request = try confirmation().request(sentAt: receivedAt)
        let headers = try #require(request.allHTTPHeaderFields)

        #expect(headers.count == 4)
        #expect(headers["Mindbox-Integration"] == "iOS-SDK")
        #expect(headers["Mindbox-Integration-Version"] == SDKVersionProvider.sdkVersion)
        #expect(headers["Content-Type"] == "application/json; charset=utf-8")
        #expect(headers["User-Agent"] == PushDeliveryConfirmationHeaders.userAgent(sdkVersion: SDKVersionProvider.sdkVersion, hostBundle: .main))
    }

    @Test("User-Agent has the format of the main module and names the host application")
    func userAgentFormat() throws {
        let bundle = Bundle(for: MindboxNotificationService.self)
        let userAgent = PushDeliveryConfirmationHeaders.userAgent(sdkVersion: "9.9.9", hostBundle: bundle)
        let name = try #require(bundle.bundleIdentifier)
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"

        #expect(userAgent.hasPrefix("mindbox.sdk/9.9.9 (\(UIDevice.current.systemName) \(UIDevice.current.systemVersion); "))
        #expect(userAgent.hasSuffix("; \(PushDeliveryConfirmationHeaders.deviceModel)) \(name)/\(version)"))
        #expect(!PushDeliveryConfirmationHeaders.deviceModel.isEmpty)
    }

    @Test("Outside an extension the host application is the main bundle")
    func hostBundleOutsideExtension() {
        #expect(PushDeliveryConfirmationHeaders.hostApplicationBundle() == Bundle.main)
    }
}
