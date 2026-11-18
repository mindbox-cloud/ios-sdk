//
//  PushDeliveryConfirmationStub.swift
//  MindboxNotificationsTests
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
@_spi(Internal) @testable import MindboxNotifications

/// Answers delivery confirmation requests the way a test tells it to and remembers what came in.
///
/// Each test takes its own host from `makeHost(answer:)`, so tests running in parallel do not see each other.
final class PushDeliveryConfirmationStub: URLProtocol {

    enum Answer {
        case status(Int, headers: [String: String] = [:])
        case failure(URLError)
        /// Never answers: the request runs into its timeout.
        case silence
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var answers: [String: Answer] = [:]
    nonisolated(unsafe) private static var received: [URLRequest] = []

    /// A new host that answers with `answer`.
    static func makeHost(answer: Answer) -> String {
        let host = "\(UUID().uuidString.lowercased()).confirm.mindbox.ru"
        lock.withLock { answers[host] = answer }
        return host
    }

    static func requests(to host: String) -> [URLRequest] {
        lock.withLock { received.filter { $0.url?.host == host } }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let answer = Self.lock.withLock {
            Self.received.append(request)
            return request.url?.host.flatMap { Self.answers[$0] } ?? .status(404)
        }
        switch answer {
        case let .status(code, headers):
            guard let url = request.url,
                  let response = HTTPURLResponse(url: url, statusCode: code, httpVersion: nil, headerFields: headers) else {
                return
            }
            if (300..<400).contains(code), let location = headers["Location"], let target = URL(string: location) {
                // When the redirect is refused, the loading goes on with the redirect response below.
                client?.urlProtocol(self, wasRedirectedTo: URLRequest(url: target), redirectResponse: response)
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocolDidFinishLoading(self)
        case let .failure(error):
            client?.urlProtocol(self, didFailWithError: error)
        case .silence:
            break
        }
    }

    override func stopLoading() {}
}

extension PushDeliveryConfirmationStub {

    /// A sender that goes through the stub.
    static func sender(timeout: TimeInterval = 5) -> PushDeliveryConfirmationSender {
        PushDeliveryConfirmationSender(timeout: timeout, protocolClasses: [PushDeliveryConfirmationStub.self])
    }
}
