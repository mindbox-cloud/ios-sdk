//
//  PushDeliveryConfirmation.swift
//  Mindbox
//
//  Copyright © 2026 Mindbox. All rights reserved.
//
//  `Mindbox/Shared` is compiled into both Mindbox and MindboxNotifications, so it runs inside
//  the notification service extension too. Keep it Foundation only: no UIKit, Core Data,
//  guaranteed delivery or logger, no locks held across awaits and no shared mutable state.
//

import CryptoKit
import Foundation

/// A push that asks the SDK to tell Mindbox it reached the device.
@_spi(Internal)
public struct PushDeliveryConfirmation: Equatable, Sendable {

    /// The URL from the push that takes the confirmation.
    public let url: URL

    /// When the device got the push.
    public let receivedAt: Date

    public init(url: URL, receivedAt: Date) {
        self.url = url
        self.receivedAt = receivedAt
    }

    /// Reads the confirmation URL from `callbacks.deliveredUrl` of the push.
    ///
    /// - Returns: `nil` when the push does not ask for a confirmation or the URL is not https:
    ///   such a push is shown as before and nothing is sent.
    public init?(userInfo: [AnyHashable: Any], receivedAt: Date = Date()) {
        let nested = userInfo["aps"] as? [AnyHashable: Any]
        let callbacks = (userInfo[PayloadKey.callbacks] ?? nested?[PayloadKey.callbacks]) as? [AnyHashable: Any]
        guard let string = callbacks?[PayloadKey.deliveryUrl] as? String,
              let url = Self.strictURL(string.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme?.lowercased() == "https",
              url.host?.isEmpty == false else {
            return nil
        }
        self.init(url: url, receivedAt: receivedAt)
    }

    /// The URL exactly as the push gave it. iOS 17 and later would percent-encode characters a URL may not contain,
    /// which can break its signature, while iOS 15 and 16 refuse such a string, as Android does: it asks for no confirmation.
    private static func strictURL(_ string: String) -> URL? {
        if #available(iOS 17.0, macOS 14.0, *) {
            return URL(string: string, encodingInvalidCharacters: false)
        }
        return URL(string: string)
    }

    /// One push gives one id: it names the file of the confirmation.
    public var id: String {
        // The Mindbox module has its own `SHA256`.
        CryptoKit.SHA256.hash(data: Data(url.absoluteString.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    /// The request that confirms the delivery when it is sent at `sentAt`: a POST with the body `{}`.
    public func request(sentAt: Date = Date()) -> URLRequest {
        var request = URLRequest(url: urlWithOffset(sentAt: sentAt))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{}".utf8)
        return request
    }

    /// Milliseconds between getting the push and sending the confirmation, never below zero.
    func dateTimeOffset(sentAt: Date) -> Int64 {
        max(0, Int64((sentAt.timeIntervalSince(receivedAt) * 1000).rounded()))
    }

    /// The other parameters go as the push gave them. Decoded query items would turn `%2B` into `+`,
    /// which the backend reads as a space, and the signature in the URL would no longer match.
    private func urlWithOffset(sentAt: Date) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        var items = components.percentEncodedQueryItems ?? []
        items.removeAll { $0.name == Self.dateTimeOffsetName }
        items.append(URLQueryItem(name: Self.dateTimeOffsetName, value: String(dateTimeOffset(sentAt: sentAt))))
        components.percentEncodedQueryItems = items
        return components.url ?? url
    }

    static let dateTimeOffsetName = "dateTimeOffset"

    /// How long the notification service extension waits for the answer before the push is shown.
    /// Until then the app leaves the file of the confirmation alone: the extension may still be sending it.
    public static let extensionWaitLimit: TimeInterval = 5

    enum PayloadKey {
        static let callbacks = "callbacks"
        static let deliveryUrl = "deliveredUrl"
    }
}

// MARK: - Stored form

/// The extension leaves the confirmation in this form for the app, and the app keeps it
/// in this form in the guaranteed delivery queue. An app update may read what an older
/// extension wrote, so fields are only ever added.
@_spi(Internal)
extension PushDeliveryConfirmation {

    public func encoded() throws -> Data {
        try Self.encoder.encode(Record(version: Record.currentVersion, url: url, receivedAt: receivedAt))
    }

    public init(encoded data: Data) throws {
        let record = try Self.decoder.decode(Record.self, from: data)
        self.init(url: record.url, receivedAt: record.receivedAt)
    }

    private struct Record: Codable {
        static let currentVersion = 1

        let version: Int
        let url: URL
        let receivedAt: Date
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = .sortedKeys
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }
}
