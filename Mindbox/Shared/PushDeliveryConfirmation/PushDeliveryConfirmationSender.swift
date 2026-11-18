//
//  PushDeliveryConfirmationSender.swift
//  Mindbox
//
//  Copyright © 2026 Mindbox. All rights reserved.
//
//  Shared with MindboxNotifications: see the note in PushDeliveryConfirmation.swift.
//

import Foundation

/// What the backend answered to a delivery confirmation. Only the HTTP status counts, the body is not read.
@_spi(Internal)
public enum PushDeliveryConfirmationOutcome: Equatable, Sendable {

    /// 2xx: the backend took the confirmation.
    case delivered

    /// 4xx other than 429: the backend refused it, sending it again will not help.
    case rejected(statusCode: Int)

    /// 429: the backend is overloaded, the confirmation goes again later.
    case throttled

    /// 5xx, a redirect, any other status or no response at all: the confirmation goes again later.
    case failed(statusCode: Int?)

    init(statusCode: Int) {
        switch statusCode {
        case 200..<300:
            self = .delivered
        case Self.tooManyRequests:
            self = .throttled
        case 400..<500:
            self = .rejected(statusCode: statusCode)
        default:
            self = .failed(statusCode: statusCode)
        }
    }

    /// Nothing is left to send: the backend either took the confirmation or refused it.
    public var isFinal: Bool {
        switch self {
        case .delivered, .rejected:
            return true
        case .throttled, .failed:
            return false
        }
    }

    public static let tooManyRequests = 429
}

/// Sends a delivery confirmation once, without retries.
@_spi(Internal)
public final class PushDeliveryConfirmationSender: Sendable {

    private let session: URLSession

    /// - Parameters:
    ///   - timeout: The whole time a request may take, from start to the last byte of the response.
    ///     `nil` keeps the system timeouts, as for the other requests of the SDK.
    ///   - protocolClasses: URL protocols to put in front of the system ones; tests use it to stub responses.
    public init(timeout: TimeInterval? = nil, protocolClasses: [AnyClass] = []) {
        let configuration = URLSessionConfiguration.ephemeral
        if let timeout {
            configuration.timeoutIntervalForRequest = timeout
            configuration.timeoutIntervalForResource = timeout
        }
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpShouldSetCookies = false
        configuration.protocolClasses = protocolClasses + (configuration.protocolClasses ?? [])
        session = URLSession(configuration: configuration)
    }

    deinit {
        session.finishTasksAndInvalidate()
    }

    public func send(_ confirmation: PushDeliveryConfirmation, sentAt: Date = Date()) async -> PushDeliveryConfirmationOutcome {
        do {
            let (_, response) = try await session.data(for: confirmation.request(sentAt: sentAt), delegate: RedirectRefusal())
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode else {
                return .failed(statusCode: nil)
            }
            return PushDeliveryConfirmationOutcome(statusCode: statusCode)
        } catch {
            return .failed(statusCode: nil)
        }
    }
}

/// A redirect would turn the POST into a GET to another address, so the redirect response itself is the answer.
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
