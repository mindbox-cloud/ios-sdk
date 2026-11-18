//
//  PushDeliveryConfirmationTests.swift
//  MindboxNotificationsTests
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
@_spi(Internal) @testable import MindboxNotifications

@Suite("Push delivery confirmation: payload, request, stored form", .tags(.notifications, .deliveryConfirmation))
struct PushDeliveryConfirmationTests {

    private static let url = "https://confirm.mindbox.ru/delivered?token=abc"
    private static let receivedAt = Date(timeIntervalSince1970: 1_800_000_000)

    private static func userInfo(callbacks: Any?) -> [AnyHashable: Any] {
        var userInfo: [AnyHashable: Any] = ["uniqueKey": "key", "aps": ["alert": ["title": "t"]]]
        userInfo["callbacks"] = callbacks
        return userInfo
    }

    private static func queryItems(of request: URLRequest) throws -> [URLQueryItem] {
        let url = try #require(request.url)
        return try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
    }

    // MARK: - Payload

    @Test("Reads the URL from deliveredUrl in the callbacks of the push")
    func readsURLFromPayload() throws {
        let confirmation = try #require(PushDeliveryConfirmation(
            userInfo: Self.userInfo(callbacks: ["deliveredUrl": Self.url]),
            receivedAt: Self.receivedAt
        ))
        #expect(confirmation.url.absoluteString == Self.url)
        #expect(confirmation.receivedAt == Self.receivedAt)
    }

    @Test("Reads the URL from aps in the legacy payload")
    func readsURLFromLegacyPayload() {
        let userInfo: [AnyHashable: Any] = [
            "aps": ["uniqueKey": "key", "callbacks": ["deliveredUrl": Self.url]]
        ]
        #expect(PushDeliveryConfirmation(userInfo: userInfo)?.url.absoluteString == Self.url)
    }

    @Test("A push without callbacks or the URL field asks for no confirmation")
    func noConfirmationWithoutField() {
        #expect(PushDeliveryConfirmation(userInfo: Self.userInfo(callbacks: nil)) == nil)
        #expect(PushDeliveryConfirmation(userInfo: Self.userInfo(callbacks: [String: Any]())) == nil)
        #expect(PushDeliveryConfirmation(userInfo: Self.userInfo(callbacks: ["deliveredUrl": 42])) == nil)
        #expect(PushDeliveryConfirmation(userInfo: Self.userInfo(callbacks: ["deliveryNotificationUrl": Self.url])) == nil)
        #expect(PushDeliveryConfirmation(userInfo: Self.userInfo(callbacks: Self.url)) == nil)
    }

    @Test("A URL other than https asks for no confirmation", arguments: [
        "",
        "   ",
        "not a url",
        "http://confirm.mindbox.ru/delivered",
        "ftp://confirm.mindbox.ru/delivered",
        "https://",
        "/delivered"
    ])
    func noConfirmationForUnusableURL(value: String) {
        #expect(PushDeliveryConfirmation(userInfo: Self.userInfo(callbacks: ["deliveredUrl": value])) == nil)
    }

    // MARK: - Request

    @Test("The request is a POST with the JSON body {} and keeps the query of the URL")
    func requestIsPost() throws {
        let confirmation = PushDeliveryConfirmation(url: try #require(URL(string: Self.url)), receivedAt: Self.receivedAt)
        let request = confirmation.request(sentAt: Self.receivedAt.addingTimeInterval(1.5))

        #expect(request.httpMethod == "POST")
        #expect(request.httpBody == Data("{}".utf8))
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let items = try Self.queryItems(of: request)
        #expect(items == [URLQueryItem(name: "token", value: "abc"), URLQueryItem(name: "dateTimeOffset", value: "1500")])
    }

    @Test("dateTimeOffset replaces one already in the URL")
    func offsetReplacesExisting() throws {
        let url = try #require(URL(string: "https://confirm.mindbox.ru/d?dateTimeOffset=7&a=1"))
        let confirmation = PushDeliveryConfirmation(url: url, receivedAt: Self.receivedAt)
        let request = confirmation.request(sentAt: Self.receivedAt.addingTimeInterval(0.25))

        let items = try Self.queryItems(of: request)
        #expect(items == [URLQueryItem(name: "a", value: "1"), URLQueryItem(name: "dateTimeOffset", value: "250")])
    }

    @Test("The other parameters go exactly as the push gave them: %2B stays %2B, not a + the backend reads as a space")
    func otherParametersKeepTheirEncoding() throws {
        let url = try #require(URL(string: "https://confirm.mindbox.ru/d?hash=a%2Bb%3D&s=x+y&p=abc==&e=%20"))
        let confirmation = PushDeliveryConfirmation(url: url, receivedAt: Self.receivedAt)
        let request = confirmation.request(sentAt: Self.receivedAt.addingTimeInterval(0.25))

        #expect(request.url?.absoluteString == "https://confirm.mindbox.ru/d?hash=a%2Bb%3D&s=x+y&p=abc==&e=%20&dateTimeOffset=250")
    }

    @Test("dateTimeOffset never goes below zero when the clock moved back")
    func offsetNotNegative() throws {
        let confirmation = PushDeliveryConfirmation(url: try #require(URL(string: Self.url)), receivedAt: Self.receivedAt)
        #expect(confirmation.dateTimeOffset(sentAt: Self.receivedAt.addingTimeInterval(-60)) == 0)
    }

    // MARK: - Id

    @Test("One URL gives one id, another URL another id")
    func idFollowsURL() throws {
        let first = PushDeliveryConfirmation(url: try #require(URL(string: Self.url)), receivedAt: Self.receivedAt)
        let sameLater = PushDeliveryConfirmation(url: try #require(URL(string: Self.url)), receivedAt: Date())
        let other = PushDeliveryConfirmation(url: try #require(URL(string: Self.url + "x")), receivedAt: Self.receivedAt)

        #expect(first.id == sameLater.id)
        #expect(first.id != other.id)
        #expect(first.id.count == 64)
    }

    // MARK: - Stored form

    @Test("The stored form reads back to the same confirmation")
    func storedFormRoundTrip() throws {
        let confirmation = PushDeliveryConfirmation(url: try #require(URL(string: Self.url)), receivedAt: Self.receivedAt)
        #expect(try PushDeliveryConfirmation(encoded: confirmation.encoded()) == confirmation)
    }

    @Test("The stored form is the one both modules agree on")
    func storedFormIsStable() throws {
        let confirmation = PushDeliveryConfirmation(url: try #require(URL(string: Self.url)), receivedAt: Self.receivedAt)
        let json = try #require(String(data: try confirmation.encoded(), encoding: .utf8))
        #expect(json == #"{"receivedAt":1800000000000,"url":"https:\/\/confirm.mindbox.ru\/delivered?token=abc","version":1}"#)
    }

    @Test("A stored form from a newer SDK with more fields still reads")
    func readsNewerStoredForm() throws {
        let json = #"{"version":2,"url":"https:\/\/confirm.mindbox.ru\/d","receivedAt":1800000000000,"attempts":3}"#
        let confirmation = try PushDeliveryConfirmation(encoded: Data(json.utf8))
        #expect(confirmation.url.absoluteString == "https://confirm.mindbox.ru/d")
        #expect(confirmation.receivedAt == Self.receivedAt)
    }
}
