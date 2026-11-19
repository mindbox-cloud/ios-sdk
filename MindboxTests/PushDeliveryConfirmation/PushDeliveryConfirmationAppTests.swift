//
//  PushDeliveryConfirmationAppTests.swift
//  MindboxTests
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
@_spi(Internal) @testable import Mindbox

@Suite("Push delivery confirmation: the app and guaranteed delivery")
struct PushDeliveryConfirmationAppTests {

    private let store = PushDeliveryConfirmationStore(
        directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    )

    private static func confirmation(host: String, receivedAt: TimeInterval = 1_800_000_000) -> PushDeliveryConfirmation {
        PushDeliveryConfirmation(url: URL(string: "https://\(host)/delivered")!, receivedAt: Date(timeIntervalSince1970: receivedAt))
    }

    private static func event(of confirmation: PushDeliveryConfirmation) throws -> Event {
        Event(type: .pushDeliveryConfirmation, body: String(decoding: try confirmation.encoded(), as: UTF8.self))
    }

    /// Without a configuration or a device UUID: the confirmation needs neither.
    private func repository() -> MBEventRepository {
        let storage = MockPersistenceStorage()
        return MBEventRepository(
            fetcher: MockNetworkFetcher(),
            persistenceStorage: storage,
            trackingIdsResolver: TrackingIdsResolver(),
            trackingHostResolver: TrackingHostResolver(persistenceStorage: storage, declaredTrackingDomains: []),
            pushDeliveryConfirmationSender: PushDeliveryConfirmationSender(timeout: 5, protocolClasses: [PushDeliveryConfirmationAppStub.self])
        )
    }

    private func send(_ event: Event) async -> Result<Void, MindboxError> {
        await withCheckedContinuation { continuation in
            repository().send(event: event) { continuation.resume(returning: $0) }
        }
    }

    // MARK: - Importer

    @Test("Waiting confirmations go to the queue and leave the App Group")
    func importsPendingConfirmations() throws {
        let database = try MockDatabaseRepository(inMemory: true)
        let first = Self.confirmation(host: "a.confirm.mindbox.ru", receivedAt: 100)
        let second = Self.confirmation(host: "b.confirm.mindbox.ru", receivedAt: 200)
        try store.save(first)
        try store.save(second)

        PushDeliveryConfirmationImporter(store: store, databaseRepository: database).importPending()

        let queued = try database.query(fetchLimit: 10)
        #expect(queued.map(\.type) == [.pushDeliveryConfirmation, .pushDeliveryConfirmation])
        let decoded = try queued.map { try PushDeliveryConfirmation(encoded: Data($0.body.utf8)) }
        #expect(decoded.sorted { $0.receivedAt < $1.receivedAt } == [first, second])
        #expect(store.pending().isEmpty)
    }

    @Test("A confirmation the queue does not take stays in the App Group")
    func keepsFileWhenQueueFails() throws {
        let database = try MockDatabaseRepository(inMemory: true)
        try store.save(Self.confirmation(host: "a.confirm.mindbox.ru"))
        let failing = FailingDatabaseRepository(base: database)

        PushDeliveryConfirmationImporter(store: store, databaseRepository: failing).importPending()

        #expect(store.pending().count == 1)
    }

    @Test("Without an App Group there is nothing to import")
    func noStoreNoImport() throws {
        let database = try MockDatabaseRepository(inMemory: true)
        PushDeliveryConfirmationImporter(store: nil, databaseRepository: database).importPending()
        #expect(try database.countEvents() == 0)
    }

    // MARK: - Sending from the queue

    @Test("A queued confirmation goes to the URL from the push as a POST with dateTimeOffset")
    func sendsToPushURL() async throws {
        let host = PushDeliveryConfirmationAppStub.makeHost(answer: .status(200))
        let result = await send(try Self.event(of: Self.confirmation(host: host)))

        #expect((try? result.get()) != nil)
        let request = try #require(PushDeliveryConfirmationAppStub.requests(to: host).first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.query?.hasPrefix("dateTimeOffset=") == true)
    }

    @Test("4xx comes back as a protocol error with its status", arguments: [400, 404, 429])
    func clientErrorIsProtocolError(code: Int) async throws {
        let host = PushDeliveryConfirmationAppStub.makeHost(answer: .status(code))
        let result = await send(try Self.event(of: Self.confirmation(host: host)))

        guard case let .failure(.protocolError(error)) = result else {
            Issue.record("Expected a protocol error, got \(result)")
            return
        }
        #expect(error.httpStatusCode == code)
    }

    @Test("5xx comes back as a server error with its status")
    func serverErrorIsServerError() async throws {
        let host = PushDeliveryConfirmationAppStub.makeHost(answer: .status(503))
        let result = await send(try Self.event(of: Self.confirmation(host: host)))

        guard case let .failure(.serverError(error)) = result else {
            Issue.record("Expected a server error, got \(result)")
            return
        }
        #expect(error.httpStatusCode == 503)
    }

    @Test("No connection comes back as a connection error")
    func noConnectionIsConnectionError() async throws {
        let host = PushDeliveryConfirmationAppStub.makeHost(answer: .failure(URLError(.notConnectedToInternet)))
        let result = await send(try Self.event(of: Self.confirmation(host: host)))

        guard case .failure(.connectionError) = result else {
            Issue.record("Expected a connection error, got \(result)")
            return
        }
    }

    @Test("An unreadable event is a client error, so the queue drops it")
    func unreadableEventIsDropped() async {
        let result = await send(Event(type: .pushDeliveryConfirmation, body: "{"))

        guard case let .failure(.protocolError(error)) = result else {
            Issue.record("Expected a protocol error, got \(result)")
            return
        }
        #expect(error.httpStatusCode == 400)
    }

    @Test("Guaranteed delivery keeps the confirmation after 429, 5xx or no connection and drops it after 2xx or other 4xx", arguments: [
        (PushDeliveryConfirmationAppStub.Answer.status(200), false),
        (.status(404), false),
        (.status(429), true),
        (.status(500), true),
        (.failure(URLError(.timedOut)), true)
    ])
    func deliveryOperationKeepsOnlyRetriable(answer: PushDeliveryConfirmationAppStub.Answer, staysQueued: Bool) async throws {
        let database = try MockDatabaseRepository(inMemory: true)
        let event = try Self.event(of: Self.confirmation(host: PushDeliveryConfirmationAppStub.makeHost(answer: answer)))
        try database.create(event: event)

        // The operation holds itself weakly while the request runs.
        let operation = DeliveryOperation(
            databaseRepository: database,
            eventRepository: repository(),
            event: event,
            pauseManager: DeliveryPauseManager(),
            retryDelayManager: DeliveryRetryDelayManager()
        )
        await withCheckedContinuation { continuation in
            operation.completionBlock = { continuation.resume() }
            operation.start()
        }
        withExtendedLifetime(operation) {}

        #expect((try database.readEvent(by: event.transactionId) != nil) == staysQueued)
    }
}

// MARK: - Test doubles

/// Answers confirmation requests per host, so tests running in parallel do not see each other.
final class PushDeliveryConfirmationAppStub: URLProtocol {

    enum Answer: Sendable {
        case status(Int)
        case failure(URLError)
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var answers: [String: Answer] = [:]
    nonisolated(unsafe) private static var received: [URLRequest] = []

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
        case let .status(code):
            guard let url = request.url,
                  let response = HTTPURLResponse(url: url, statusCode: code, httpVersion: nil, headerFields: nil) else { return }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocolDidFinishLoading(self)
        case let .failure(error):
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

/// Takes nothing into the queue.
private final class FailingDatabaseRepository: DatabaseRepositoryProtocol {
    private let base: DatabaseRepositoryProtocol

    init(base: DatabaseRepositoryProtocol) {
        self.base = base
    }

    var limit: Int { base.limit }
    var lifeLimitDate: Date? { base.lifeLimitDate }
    var deprecatedLimit: Int { base.deprecatedLimit }
    var onObjectsDidChange: (() -> Void)? {
        get { base.onObjectsDidChange }
        set { base.onObjectsDidChange = newValue }
    }

    func create(event: Event) throws { throw CocoaError(.fileWriteUnknown) }
    func readEvent(by transactionId: String) throws -> Event? { try base.readEvent(by: transactionId) }
    func update(event: Event) throws { try base.update(event: event) }
    func delete(event: Event) throws { try base.delete(event: event) }
    func query(fetchLimit: Int, retryDeadline: TimeInterval) throws -> [Event] { try base.query(fetchLimit: fetchLimit, retryDeadline: retryDeadline) }
    func removeDeprecatedEventsIfNeeded() throws { try base.removeDeprecatedEventsIfNeeded() }
    func countDeprecatedEvents() throws -> Int { try base.countDeprecatedEvents() }
    func erase() throws { try base.erase() }
    func countEvents() throws -> Int { try base.countEvents() }
}
