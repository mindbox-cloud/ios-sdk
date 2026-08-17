//
//  OperationActionHandlerTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 14.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
@_spi(Internal) @testable import Mindbox

/// What the handler does with an operation request: what it writes, what it answers, and what it
/// refuses.
///
/// Two neighbours own the rest of this action deliberately. `TransparentViewSyncOperationResponseTests`
/// covers `makeSyncOperationResponse` on its own, as the pure mapping it is, so nothing here
/// re-checks the shape of every backend outcome. `TransparentViewJSBridgeTests` covers the tag merge
/// through the view, which is where the tags come from. This suite is the wiring in between: parse,
/// write, answer, and whose lifetime the answer depends on.
@Suite("OperationActionHandler", .tags(.webView))
@MainActor
struct OperationActionHandlerTests {

    init() {
        TestConfiguration.configure()
    }

    private func makeSUT(
        database: DatabaseRepositoryStub = DatabaseRepositoryStub(),
        events: SyncOperationRepositoryStub = SyncOperationRepositoryStub()
    ) -> (handler: OperationActionHandler, database: DatabaseRepositoryStub, events: SyncOperationRepositoryStub, host: HostSpy) {
        let handler = OperationActionHandler(featureToggleManager: FeatureToggleManager(),
                                            databaseRepository: database,
                                            eventRepository: events)
        return (handler, database, events, HostSpy())
    }

    private func request(_ action: BridgeMessage.Action,
                         operation: String = "Test.Operation",
                         body: JSONValue = .object(["field": .string("value")])) -> BridgeMessage {
        .request(action, payload: .object(["operation": .string(operation), "body": body]))
    }

    @Test("Owns both operation actions")
    func ownsOperationActions() {
        #expect(OperationActionHandler().actions == [.asyncOperation, .syncOperation])
    }

    // MARK: - asyncOperation

    @Test("An async operation is queued as a custom event and confirmed")
    func asyncOperationIsQueuedAndConfirmed() throws {
        let sut = makeSUT()

        sut.handler.handle(request(.asyncOperation, operation: "Test.Async"), host: sut.host)

        let event = try #require(sut.database.created.first)
        #expect(event.type == .customEvent)
        let customEvent = try #require(BodyDecoder<CustomEvent>(decodable: event.body)?.body)
        #expect(customEvent.name == "Test.Async")

        let response = try #require(sut.host.sent.first)
        #expect(response.type == .response)
        #expect(response.payload == .object(["success": .bool(true)]))
    }

    /// The queue is a database write, and a database can be full or broken. The page is told so
    /// rather than being left to believe the operation is on its way.
    @Test("A queue that fails is reported to the page instead of being confirmed")
    func asyncOperationFailureIsReported() throws {
        let database = DatabaseRepositoryStub()
        database.createError = DatabaseRepositoryStub.StubError.full
        let sut = makeSUT(database: database)

        sut.handler.handle(request(.asyncOperation), host: sut.host)

        let response = try #require(sut.host.sent.first)
        #expect(response.type == .error)
        #expect(sut.host.sent.count == 1, "a failed queue is answered once, not confirmed as well")
    }

    @Test("A queued operation does not reach the network")
    func asyncOperationDoesNotSend() {
        let sut = makeSUT()

        sut.handler.handle(request(.asyncOperation), host: sut.host)

        #expect(sut.events.sentRaw.isEmpty)
    }

    // MARK: - syncOperation

    @Test("A sync operation is sent as a sync event and its body is handed back untouched")
    func syncOperationForwardsRawBody() async throws {
        let sut = makeSUT()
        let message = request(.syncOperation, operation: "Test.Sync")

        sut.handler.handle(message, host: sut.host)
        sut.events.answer(.success(Data(#"{"status":"Success"}"#.utf8)))
        await drainMainQueue(until: { !sut.host.sent.isEmpty })

        let event = try #require(sut.events.sentRaw.first)
        #expect(event.type == .syncEvent)

        let response = try #require(sut.host.sent.first)
        #expect(response.type == .response)
        #expect(response.payload == .string(#"{"status":"Success"}"#))
        #expect(response.id == message.id, "the answer belongs to the request that asked")
        #expect(response.action == message.action)
    }

    @Test("A sync operation that fails reaches the page as an error")
    func syncOperationFailureReachesThePage() async throws {
        let sut = makeSUT()

        sut.handler.handle(request(.syncOperation), host: sut.host)
        sut.events.answer(.failure(.connectionError))
        await drainMainQueue(until: { !sut.host.sent.isEmpty })

        let response = try #require(sut.host.sent.first)
        #expect(response.type == .error)
    }

    @Test("A sync operation is not written to the queue")
    func syncOperationDoesNotQueue() async {
        let sut = makeSUT()

        sut.handler.handle(request(.syncOperation), host: sut.host)
        sut.events.answer(.success(Data()))
        await drainMainQueue(until: { !sut.host.sent.isEmpty })

        #expect(sut.database.created.isEmpty)
    }

    /// A backend answer arrives whenever it arrives, and by then the show may be over. Waiting on
    /// it must not be what keeps the page — and the whole handler set behind it — alive.
    @Test("A request in flight does not hold the page alive")
    func pendingSyncOperationDoesNotHoldThePage() {
        let sut = makeSUT()
        weak var page: HostSpy?

        do {
            let host = HostSpy()
            page = host
            sut.handler.handle(request(.syncOperation), host: host)
        }

        #expect(sut.events.pending != nil, "the request is still waiting for its answer")
        #expect(page == nil, "the page must not be held by a request that has not answered yet")
    }

    @Test("An answer that arrives after the page is gone is dropped")
    func answerAfterThePageIsGoneIsDropped() async {
        let sut = makeSUT()
        weak var page: HostSpy?

        do {
            let host = HostSpy()
            page = host
            sut.handler.handle(request(.syncOperation), host: host)
        }

        sut.events.answer(.success(Data(#"{"status":"Success"}"#.utf8)))
        // Nothing arrives to be waited for, so the queue is drained for its own sake: the answer
        // has nowhere to go, and going there anyway is what this guards against.
        await drainMainQueue(until: { false }, turns: 3)

        #expect(page == nil)
    }

    // MARK: - Refusals

    @Test("A request without a payload is refused", arguments: [BridgeMessage.Action.asyncOperation, .syncOperation])
    func missingPayloadIsRefused(action: BridgeMessage.Action) throws {
        let sut = makeSUT()

        sut.handler.handle(.request(action), host: sut.host)

        let response = try #require(sut.host.sent.first)
        #expect(response.type == .error)
        #expect(sut.database.created.isEmpty)
        #expect(sut.events.sentRaw.isEmpty)
    }

    @Test("A payload that is not an object at all is refused")
    func nonObjectPayloadIsRefused() throws {
        let sut = makeSUT()

        sut.handler.handle(.request(.asyncOperation, payload: .array([.string("nope")])), host: sut.host)

        #expect(try #require(sut.host.sent.first).type == .error)
        #expect(sut.database.created.isEmpty)
    }

    @Test("A request without an operation name is refused")
    func missingOperationNameIsRefused() throws {
        let sut = makeSUT()

        sut.handler.handle(.request(.asyncOperation, payload: .object(["body": .object([:])])), host: sut.host)

        #expect(try #require(sut.host.sent.first).type == .error)
        #expect(sut.database.created.isEmpty)
    }

    /// The name is what the operation *is*: an empty one would reach the backend as an anonymous
    /// event nobody can act on.
    @Test("An empty operation name is refused")
    func emptyOperationNameIsRefused() throws {
        let sut = makeSUT()

        sut.handler.handle(request(.asyncOperation, operation: ""), host: sut.host)

        #expect(try #require(sut.host.sent.first).type == .error)
        #expect(sut.database.created.isEmpty)
    }

    @Test("An operation name that is not a string is refused")
    func nonStringOperationNameIsRefused() throws {
        let sut = makeSUT()
        let payload = JSONValue.object(["operation": .int(42), "body": .object([:])])

        sut.handler.handle(.request(.asyncOperation, payload: payload), host: sut.host)

        #expect(try #require(sut.host.sent.first).type == .error)
        #expect(sut.database.created.isEmpty)
    }

    @Test("A request without a body is refused", arguments: [BridgeMessage.Action.asyncOperation, .syncOperation])
    func missingBodyIsRefused(action: BridgeMessage.Action) throws {
        let sut = makeSUT()

        sut.handler.handle(.request(action, payload: .object(["operation": .string("Test.Op")])), host: sut.host)

        #expect(try #require(sut.host.sent.first).type == .error)
        #expect(sut.database.created.isEmpty)
        #expect(sut.events.sentRaw.isEmpty)
    }

    /// An empty body is a body: an operation may legitimately carry nothing.
    @Test("An empty body is accepted")
    func emptyBodyIsAccepted() throws {
        let sut = makeSUT()

        sut.handler.handle(request(.asyncOperation, body: .object([:])), host: sut.host)

        #expect(try #require(sut.host.sent.first).type == .response)
        #expect(sut.database.created.count == 1)
    }
}

// MARK: - Doubles

/// Records what was written and can refuse to write.
private final class DatabaseRepositoryStub: DatabaseRepositoryProtocol {

    enum StubError: Error {
        case full
    }

    var limit: Int = 0
    var lifeLimitDate: Date?
    var deprecatedLimit: Int = 0
    var onObjectsDidChange: (() -> Void)?

    /// Set to make the next write fail.
    var createError: Error?

    private(set) var created: [Event] = []

    func create(event: Event) throws {
        if let createError {
            throw createError
        }

        created.append(event)
    }

    func readEvent(by transactionId: String) throws -> Event? {
        created.first { $0.transactionId == transactionId }
    }

    func update(event: Event) throws {}
    func delete(event: Event) throws {}
    func query(fetchLimit: Int, retryDeadline: TimeInterval) throws -> [Event] { [] }
    func removeDeprecatedEventsIfNeeded() throws {}
    func countDeprecatedEvents() throws -> Int { 0 }
    func erase() throws { created.removeAll() }
    func countEvents() throws -> Int { created.count }
}

/// Holds its answer back until the test gives one.
///
/// The pause is the point: while the request is in flight is the only moment in which what the SDK
/// keeps alive can be observed at all.
private final class SyncOperationRepositoryStub: EventRepository {

    private(set) var sentRaw: [Event] = []
    private(set) var pending: ((Result<Data, MindboxError>) -> Void)?

    func answer(_ result: Result<Data, MindboxError>) {
        let completion = pending
        pending = nil
        completion?(result)
    }

    func sendRaw(event: Event, completion: @escaping (Result<Data, MindboxError>) -> Void) {
        sentRaw.append(event)
        pending = completion
    }

    func send(event: Event, completion: @escaping (Result<Void, MindboxError>) -> Void) {
        completion(.success(()))
    }

    func send<T>(type: T.Type, event: Event, completion: @escaping (Result<T, MindboxError>) -> Void) where T: Decodable {}

    func cancelAllRequests() {}
}
