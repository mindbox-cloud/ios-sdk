//
//  PushDeliveryConfirmation.swift
//  MindboxNotifications
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

struct PushDeliveryConfirmation: Equatable, Sendable {

    static let dateTimeOffsetName = "dateTimeOffset"

    let url: URL
    let receivedAt: Date

    init(url: URL, receivedAt: Date) {
        self.url = url
        self.receivedAt = receivedAt
    }

    init?(deliveredUrl: String?, receivedAt: Date = Date()) {
        guard let deliveredUrl,
              let url = URL(string: deliveredUrl),
              url.scheme?.lowercased() == "https",
              url.host?.isEmpty == false,
              URLComponents(url: url, resolvingAgainstBaseURL: false) != nil else {
            return nil
        }
        self.init(url: url, receivedAt: receivedAt)
    }

    func request(sentAt: Date = Date(), headers: [String: String] = PushDeliveryConfirmationHeaders.make()) -> URLRequest {
        var request = URLRequest(url: requestURL(sentAt: sentAt))
        request.httpMethod = "POST"
        request.httpBody = Data("{}".utf8)
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        return request
    }

    func requestURL(sentAt: Date) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        let milliseconds = max(0, Int64((sentAt.timeIntervalSince(receivedAt) * 1000).rounded()))
        let offset = URLQueryItem(name: Self.dateTimeOffsetName, value: String(milliseconds))
        components.percentEncodedQueryItems = (components.percentEncodedQueryItems ?? []) + [offset]
        return components.url ?? url
    }
}
