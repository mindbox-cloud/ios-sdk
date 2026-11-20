//
//  PushDeliveryConfirmationStub.swift
//  MindboxNotificationsTests
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
@testable import MindboxNotifications

final class PushDeliveryConfirmationStub: URLProtocol {

    enum Answer {
        case status(Int)
        case redirect(to: String)
        case failure(URLError.Code)
        case silence
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var answers: [String: Answer] = [:]
    nonisolated(unsafe) private static var received: [String: [URLRequest]] = [:]

    static func makeHost(answering answer: Answer) -> String {
        let host = "\(UUID().uuidString.lowercased()).confirmation.test"
        lock.withLock { answers[host] = answer }
        return host
    }

    static func requests(to host: String) -> [URLRequest] {
        lock.withLock { received[host] ?? [] }
    }

    static func body(of request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else {
            return nil
        }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host?.hasSuffix(".confirmation.test") == true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let host = url.host else { return }
        let answer = Self.lock.withLock {
            Self.received[host, default: []].append(request)
            return Self.answers[host]
        }
        switch answer {
        case .status(let code):
            respond(url: url, code: code, headers: nil)
        case .redirect(let location):
            guard let target = URL(string: location),
                  let response = HTTPURLResponse(url: url, statusCode: 302, httpVersion: nil, headerFields: ["Location": location]) else {
                return
            }
            client?.urlProtocol(self, wasRedirectedTo: URLRequest(url: target), redirectResponse: response)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocolDidFinishLoading(self)
        case .failure(let code):
            client?.urlProtocol(self, didFailWithError: URLError(code))
        case .silence, .none:
            break
        }
    }

    override func stopLoading() {}

    private func respond(url: URL, code: Int, headers: [String: String]?) {
        guard let response = HTTPURLResponse(url: url, statusCode: code, httpVersion: nil, headerFields: headers) else {
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocolDidFinishLoading(self)
    }
}

extension PushDeliveryConfirmationSender {
    static func stubbed(timeout: TimeInterval = PushDeliveryConfirmationSender.responseTimeout) -> PushDeliveryConfirmationSender {
        PushDeliveryConfirmationSender(timeout: timeout, protocolClasses: [PushDeliveryConfirmationStub.self])
    }
}

extension PushDeliveryConfirmationStore {
    static func temporary() -> PushDeliveryConfirmationStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PushDeliveryConfirmationTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return PushDeliveryConfirmationStore(directory: directory)
    }

    var fileNames: [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
    }
}
