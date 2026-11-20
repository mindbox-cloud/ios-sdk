//
//  PushDeliveryConfirmationSender.swift
//  MindboxNotifications
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

final class PushDeliveryConfirmationSender: Sendable {

    static let responseTimeout: TimeInterval = 3

    private let session: URLSession

    init(timeout: TimeInterval = PushDeliveryConfirmationSender.responseTimeout, protocolClasses: [AnyClass] = []) {
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

    func send(_ confirmation: PushDeliveryConfirmation, sentAt: Date = Date()) async -> Int? {
        let answer = try? await session.data(for: confirmation.request(sentAt: sentAt), delegate: RedirectRefusal())
        return (answer?.1 as? HTTPURLResponse)?.statusCode
    }
}

private final class RedirectRefusal: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest
    ) async -> URLRequest? {
        nil
    }
}
