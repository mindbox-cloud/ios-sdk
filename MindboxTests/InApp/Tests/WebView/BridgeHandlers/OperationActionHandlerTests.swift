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
/// re-checks the shape of every backend outcome. `TransparentViewJSBridgeTests` proves the window's
/// tags reach the handler through the view; whose tags an operation carries is decided here. This
/// suite is the wiring in between: parse, tag, write, answer, and whose lifetime the answer depends on.
@Suite("OperationActionHandler", .tags(.webView))
@MainActor
struct OperationActionHandlerTests {

    private let featureToggleManager = FeatureToggleManager()
    private let config = ConfigLookupSpy()

    init() {
        TestConfiguration.configure()
    }

    private func makeSUT(
        database: DatabaseRepositoryStub = DatabaseRepositoryStub(),
        events: SyncOperationRepositoryStub = SyncOperationRepositoryStub()
    ) -> (handler: OperationActionHandler, database: DatabaseRepositoryStub, events: SyncOperationRepositoryStub, core: InAppCoreManagerMock, host: HostSpy) {
        let core = InAppCoreManagerMock()
        let handler = OperationActionHandler(featureToggleManager: featureToggleManager,
                                            databaseRepository: database,
                                            eventRepository: events,
                                            inAppEventSender: InappMessageEventSender(inAppMessagesManager: core),
                                            inappInCurrentConfig: config.inappInCurrentConfig(withId:))
        return (handler, database, events, core, HostSpy())
    }

    private func request(_ action: BridgeMessage.Action,
                         operation: String = "Test.Operation",
                         body: JSONValue = .object(["field": .string("value")]),
                         inappId: JSONValue? = nil) -> BridgeMessage {
        var payload: [String: JSONValue] = ["operation": .string(operation), "body": body]
        payload["inappId"] = inappId
        return .request(action, payload: .object(payload))
    }

    private func inapp(_ id: String, tags: [String: String]?) -> InApp {
        InApp(id: id,
              isPriority: false,
              delayTime: nil,
              sdkVersion: SdkVersion(min: 8, max: nil),
              targeting: .true(TrueTargeting()),
              frequency: nil,
              displayConditions: .unrestricted,
              form: InAppForm(variants: []),
              tags: tags)
    }

    private func body(of event: Event?) throws -> [String: JSONValue] {
        let event = try #require(event)
        let customEvent = try #require(BodyDecoder<CustomEvent>(decodable: event.body)?.body)
        return try JSONDecoder().decode([String: JSONValue].self, from: Data(customEvent.payload.utf8))
    }

    private func applyTagsToggle(enabled: Bool) {
        featureToggleManager.applyFeatureToggles(
            Settings.FeatureToggles(shouldSendInAppShowError: nil, shouldSendInAppTags: enabled, shouldPrewarmInAppWebView: nil, shouldCacheInAppWebView: nil)
        )
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
        #expect(response.payload == .object(["error": .string("operation_failed")]))
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

    // MARK: - In-apps

    @Test("A queued operation reaches in-apps under its name and body, as one from the app does")
    func asyncOperationReachesInApps() throws {
        let sut = makeSUT()
        let body: JSONValue = .object(["viewProductCategory": .object(["productCategory": .object(["ids": .object(["website": .string("cat-1")])])])])

        sut.handler.handle(request(.asyncOperation, operation: "Test.Async", body: body), host: sut.host)

        #expect(sut.core.sendEventCalled.count == 1)
        let event = try #require(sut.core.sendEventCalled.first?.applicationEvent)
        #expect(event.name == "test.async")
        #expect(event.model == InappOperationJSONModel(viewProductCategory: .init(productCategory: .init(ids: ["website": "cat-1"]))))
    }

    @Test("An operation reaches in-apps even when the queue refuses it, as one from the app does")
    func refusedQueueStillReachesInApps() throws {
        let database = DatabaseRepositoryStub()
        database.createError = DatabaseRepositoryStub.StubError.full
        let sut = makeSUT(database: database)

        sut.handler.handle(request(.asyncOperation), host: sut.host)

        #expect(sut.core.sendEventCalled.count == 1)
        #expect(try #require(sut.host.sent.first).type == .error)
    }

    @Test("A sync operation reaches in-apps with its body when it is sent, without waiting for the backend")
    func syncOperationReachesInAppsBeforeTheAnswer() throws {
        let sut = makeSUT()
        let body: JSONValue = .object(["viewProduct": .object(["product": .object(["ids": .object(["website": .string("sku-1")])])])])

        sut.handler.handle(request(.syncOperation, operation: "Test.Sync", body: body), host: sut.host)

        #expect(sut.events.pending != nil, "the backend has not answered yet")
        #expect(sut.core.sendEventCalled.count == 1)
        let event = try #require(sut.core.sendEventCalled.first?.applicationEvent)
        #expect(event.name == "test.sync")
        #expect(event.model == InappOperationJSONModel(viewProduct: .init(product: .init(ids: ["website": "sku-1"]))))
    }

    // MARK: - Tags

    @Test("An operation naming another in-app carries that in-app's tags instead of the window's", .tags(.inAppTags))
    func namedInappTagsReplaceTheWindows() throws {
        config.inapps = [inapp("story-2", tags: ["templateType": "Story"])]
        let sut = makeSUT()
        sut.host.tags = ["templateType": "Window", "campaign": "window-only"]

        sut.handler.handle(request(.asyncOperation, inappId: .string("story-2")), host: sut.host)

        let body = try body(of: sut.database.created.first)
        #expect(body["tags"] == .object(["templateType": .string("Story")]))
        #expect(body["field"] == .string("value"))
        #expect(config.askedIds == ["story-2"])
    }

    @Test("An operation that names no other in-app carries the window's tags and looks nothing up",
          .tags(.inAppTags),
          arguments: [
            #"{"operation":"Test.Operation","body":{}}"#,
            #"{"operation":"Test.Operation","body":{},"inappId":null}"#,
            #"{"operation":"Test.Operation","body":{},"inappId":"test-content-id"}"#
          ])
    func windowTagsWhenNoOtherInappIsNamed(payload: String) throws {
        config.inapps = [inapp("test-content-id", tags: ["templateType": "FromConfig"])]
        let sut = makeSUT()
        sut.host.tags = ["templateType": "Window"]

        sut.handler.handle(.request(.asyncOperation, payload: .string(payload)), host: sut.host)

        let body = try body(of: sut.database.created.first)
        #expect(body["tags"] == .object(["templateType": .string("Window")]))
        #expect(config.askedIds.isEmpty)
    }

    @Test("An unknown in-app id sends the operation without any SDK tags, and the queue confirms it", .tags(.inAppTags))
    func unknownInappSendsWithoutTags() throws {
        let sut = makeSUT()
        sut.host.tags = ["templateType": "Window"]

        sut.handler.handle(request(.asyncOperation, inappId: .string("gone-story")), host: sut.host)

        let body = try body(of: sut.database.created.first)
        #expect(body.keys.contains("tags") == false)
        #expect(config.askedIds == ["gone-story"])
        #expect(try #require(sut.host.sent.first).payload == .object(["success": .bool(true)]))
    }

    @Test("An unknown in-app id on a sync operation sends without SDK tags and hands the backend body back", .tags(.inAppTags))
    func unknownInappSyncOperationReturnsTheBackendBody() async throws {
        let sut = makeSUT()
        sut.host.tags = ["templateType": "Window"]

        sut.handler.handle(request(.syncOperation, inappId: .string("gone-story")), host: sut.host)
        sut.events.answer(.success(Data(#"{"status":"Success"}"#.utf8)))
        await drainMainQueue(until: { !sut.host.sent.isEmpty })

        let body = try body(of: sut.events.sentRaw.first)
        #expect(body.keys.contains("tags") == false)
        let response = try #require(sut.host.sent.first)
        #expect(response.type == .response)
        #expect(response.payload == .string(#"{"status":"Success"}"#))
    }

    @Test("A named in-app without tags adds none, and the window's do not stand in", .tags(.inAppTags))
    func namedInappWithoutTagsAddsNone() throws {
        config.inapps = [inapp("story-2", tags: nil)]
        let sut = makeSUT()
        sut.host.tags = ["templateType": "Window"]

        sut.handler.handle(request(.asyncOperation, inappId: .string("story-2")), host: sut.host)

        let body = try body(of: sut.database.created.first)
        #expect(body.keys.contains("tags") == false)
    }

    @Test("An in-app id that is not a non-empty string is refused, and nothing is queued, sent or announced",
          .tags(.inAppTags),
          arguments: [BridgeMessage.Action.asyncOperation, .syncOperation], [#"42"#, #""""#])
    func invalidInappIdIsRefused(action: BridgeMessage.Action, inappId: String) throws {
        let sut = makeSUT()
        let payload = #"{"operation":"Test.Operation","body":{},"inappId":\#(inappId)}"#

        sut.handler.handle(.request(action, payload: .string(payload)), host: sut.host)

        let response = try #require(sut.host.sent.first)
        #expect(response.type == .error)
        #expect(response.payload == .object(["error": .string("invalid_payload")]))
        #expect(sut.database.created.isEmpty)
        #expect(sut.events.sentRaw.isEmpty)
        #expect(sut.core.sendEventCalled.isEmpty)
        #expect(config.askedIds.isEmpty)
    }

    @Test("With the tags toggle off no tags are added, yet a named in-app is still looked up", .tags(.inAppTags))
    func toggleOffStillLooksUp() throws {
        applyTagsToggle(enabled: false)
        config.inapps = [inapp("story-2", tags: ["templateType": "Story"])]
        let sut = makeSUT()
        sut.host.tags = ["templateType": "Window"]

        sut.handler.handle(request(.asyncOperation, inappId: .string("story-2")), host: sut.host)

        let body = try body(of: sut.database.created.first)
        #expect(body.keys.contains("tags") == false)
        #expect(config.askedIds == ["story-2"])
    }

    @Test("The page's own tag keys win over the named in-app's", .tags(.inAppTags))
    func pageTagKeysWinOverTheNamedInapps() throws {
        config.inapps = [inapp("story-2", tags: ["templateType": "Story", "campaign": "story-campaign"])]
        let sut = makeSUT()
        let body: JSONValue = .object(["tags": .object(["templateType": .string("client")])])

        sut.handler.handle(request(.asyncOperation, body: body, inappId: .string("story-2")), host: sut.host)

        let sentBody = try self.body(of: sut.database.created.first)
        #expect(sentBody["tags"] == .object([
            "templateType": .string("client"),
            "campaign": .string("story-campaign")
        ]))
    }

    @Test("A sync operation naming another in-app carries that in-app's tags", .tags(.inAppTags))
    func syncOperationCarriesTheNamedInappsTags() throws {
        config.inapps = [inapp("story-2", tags: ["templateType": "Story"])]
        let sut = makeSUT()
        sut.host.tags = ["templateType": "Window"]

        sut.handler.handle(request(.syncOperation, inappId: .string("story-2")), host: sut.host)

        let body = try body(of: sut.events.sentRaw.first)
        #expect(body["tags"] == .object(["templateType": .string("Story")]))
    }

    // MARK: - Refusals

    @Test("A request without a payload is refused", arguments: [BridgeMessage.Action.asyncOperation, .syncOperation])
    func missingPayloadIsRefused(action: BridgeMessage.Action) throws {
        let sut = makeSUT()

        sut.handler.handle(.request(action), host: sut.host)

        let response = try #require(sut.host.sent.first)
        #expect(response.type == .error)
        #expect(response.payload == .object(["error": .string("invalid_payload")]))
        #expect(sut.database.created.isEmpty)
        #expect(sut.events.sentRaw.isEmpty)
        #expect(sut.core.sendEventCalled.isEmpty)
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

private final class ConfigLookupSpy {

    var inapps: [InApp] = []
    private(set) var askedIds: [String] = []

    func inappInCurrentConfig(withId id: String) -> InApp? {
        askedIds.append(id)
        return inapps.first { $0.id == id }
    }
}

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
