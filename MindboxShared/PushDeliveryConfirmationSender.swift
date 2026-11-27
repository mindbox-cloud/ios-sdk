//
//  PushDeliveryConfirmationSender.swift
//  MindboxShared
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

@_spi(Internal)
public final class PushDeliveryConfirmationSender: Sendable {

    public static let responseTimeout: TimeInterval = 3

    private let session: URLSession
    private let headers: [String: String]

    public init(
        headers: [String: String],
        timeout: TimeInterval = PushDeliveryConfirmationSender.responseTimeout,
        protocolClasses: [AnyClass] = []
    ) {
        self.headers = headers
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpShouldSetCookies = false
        configuration.protocolClasses = protocolClasses + (configuration.protocolClasses ?? [])
        session = URLSession(configuration: configuration)
    }

    deinit {
        session.finishTasksAndInvalidate()
    }

    public func send(_ confirmation: PushDeliveryConfirmation, sentAt: Date = Date()) async -> Int? {
        let answer = try? await session.data(for: confirmation.request(sentAt: sentAt, headers: headers))
        return (answer?.1 as? HTTPURLResponse)?.statusCode
    }
}
