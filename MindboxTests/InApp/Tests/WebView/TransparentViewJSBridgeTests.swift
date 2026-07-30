//
//  TransparentViewJSBridgeTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 08.07.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import UIKit
import WebKit
@_spi(Internal) @testable import Mindbox

@MainActor
@Suite("TransparentView JS-bridge operation tags tests")
final class TransparentViewJSBridgeTests {

    private let featureToggleManager = FeatureToggleManager()
    private let databaseRepository = DatabaseRepositorySpy()
    private let eventRepository = EventRepositorySpy()
    private let facade = WebViewFacadeSpy()

    init() {
        TestConfiguration.configure()
    }

    // MARK: - asyncOperation

    @Test("asyncOperation merges in-app tags into the operation body when the feature is enabled", .tags(.inAppTags, .webView))
    func asyncOperationMergesTagsWhenEnabled() throws {
        let view = makeView(tags: ["templateType": "Popup"])
        send(.asyncOperation, payload: #"{"operation":"Test.Operation","body":{"field":"value"}}"#, to: view)

        let customEvent = try #require(queuedCustomEvent())
        #expect(customEvent.name == "Test.Operation")

        let body = try #require(decodedPayload(of: customEvent))
        #expect(body["field"] == .string("value"))
        #expect(body["tags"] == .object(["templateType": .string("Popup")]))
        #expect(facade.sentMessages.last?.type == .response)
    }

    @Test("asyncOperation omits tags from the operation body when the feature is disabled", .tags(.inAppTags, .webView))
    func asyncOperationOmitsTagsWhenDisabled() throws {
        applyTagsToggle(enabled: false)
        let view = makeView(tags: ["templateType": "Popup"])
        send(.asyncOperation, payload: #"{"operation":"Test.Operation","body":{"field":"value"}}"#, to: view)

        let customEvent = try #require(queuedCustomEvent())
        let body = try #require(decodedPayload(of: customEvent))
        #expect(body["field"] == .string("value"))
        #expect(body.keys.contains("tags") == false)
    }

    @Test("asyncOperation keeps client-provided tag values on key collision", .tags(.inAppTags, .webView))
    func asyncOperationKeepsClientTagsOnCollision() throws {
        let view = makeView(tags: ["templateType": "Popup", "source": "server"])
        send(.asyncOperation, payload: #"{"operation":"Test.Operation","body":{"tags":{"templateType":"client"}}}"#, to: view)

        let customEvent = try #require(queuedCustomEvent())
        let body = try #require(decodedPayload(of: customEvent))
        #expect(body["tags"] == .object([
            "templateType": .string("client"),
            "source": .string("server")
        ]))
    }

    @Test("asyncOperation without a body responds with a bridge error and queues nothing", .tags(.inAppTags, .webView))
    func asyncOperationWithoutBodySendsBridgeError() throws {
        let view = makeView(tags: ["templateType": "Popup"])
        send(.asyncOperation, payload: #"{"operation":"Test.Operation"}"#, to: view)

        #expect(databaseRepository.createdEvents.isEmpty)
        #expect(facade.sentMessages.last?.type == .error)
    }

    @Test("asyncOperation with an empty operation name responds with a bridge error and queues nothing", .tags(.inAppTags, .webView))
    func asyncOperationWithEmptyNameSendsBridgeError() throws {
        let view = makeView(tags: ["templateType": "Popup"])
        send(.asyncOperation, payload: #"{"operation":"","body":{"field":"value"}}"#, to: view)

        #expect(databaseRepository.createdEvents.isEmpty)
        #expect(facade.sentMessages.last?.type == .error)
    }

    // MARK: - syncOperation

    @Test("syncOperation merges in-app tags into the operation body when the feature is enabled", .tags(.inAppTags, .webView))
    func syncOperationMergesTagsWhenEnabled() throws {
        let view = makeView(tags: ["templateType": "Snackbar"])
        send(.syncOperation, payload: #"{"operation":"Test.Sync","body":{"field":"value"}}"#, to: view)

        let event = try #require(eventRepository.sentRawEvents.first)
        let customEvent = try #require(BodyDecoder<CustomEvent>(decodable: event.body)?.body)
        #expect(customEvent.name == "Test.Sync")

        let body = try #require(decodedPayload(of: customEvent))
        #expect(body["field"] == .string("value"))
        #expect(body["tags"] == .object(["templateType": .string("Snackbar")]))
    }

    @Test("syncOperation omits tags from the operation body when the feature is disabled", .tags(.inAppTags, .webView))
    func syncOperationOmitsTagsWhenDisabled() throws {
        applyTagsToggle(enabled: false)
        let view = makeView(tags: ["templateType": "Snackbar"])
        send(.syncOperation, payload: #"{"operation":"Test.Sync","body":{"field":"value"}}"#, to: view)

        let event = try #require(eventRepository.sentRawEvents.first)
        let customEvent = try #require(BodyDecoder<CustomEvent>(decodable: event.body)?.body)
        let body = try #require(decodedPayload(of: customEvent))
        #expect(body.keys.contains("tags") == false)
    }

    // MARK: - Helpers

    private func makeView(tags: [String: String]?) -> TransparentView {
        let view = TransparentView(
            frame: .zero,
            params: [:],
            userAgent: "",
            operation: nil,
            inAppId: "inapp-1",
            tags: tags
        )
        view.facade = facade
        view.featureToggleManager = featureToggleManager
        view.databaseRepository = databaseRepository
        view.eventRepository = eventRepository
        return view
    }

    private func send(_ action: BridgeMessage.Action, payload: String, to view: TransparentView) {
        let bridge = MindboxWebBridge(webView: WKWebView())
        let message = BridgeMessage(type: .request, action: action, payload: .string(payload))
        view.webBridge(bridge, didReceiveBridgeMessage: message)
    }

    private func queuedCustomEvent() -> CustomEvent? {
        guard let event = databaseRepository.createdEvents.first else { return nil }
        return BodyDecoder<CustomEvent>(decodable: event.body)?.body
    }

    private func decodedPayload(of customEvent: CustomEvent) -> [String: JSONValue]? {
        guard let data = customEvent.payload.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([String: JSONValue].self, from: data)
    }

    private func applyTagsToggle(enabled: Bool) {
        featureToggleManager.applyFeatureToggles(
            Settings.FeatureToggles(shouldSendInAppShowError: nil, shouldSendInAppTags: enabled, shouldPrewarmInAppWebView: nil, shouldCacheInAppWebView: nil)
        )
    }
}

// MARK: - Spies

private final class WebViewFacadeSpy: InappWebViewFacadeProtocol {
    private(set) var sentMessages: [BridgeMessage] = []

    func makeView() -> UIView { UIView() }
    func loadHTML(baseUrl: String, contentUrl: String, onFailure: @escaping () -> Void) {}
    func applyViewSettings(scrollViewDelegate: UIScrollViewDelegate?) {}
    func cleanWebView() {}
    func sendReadyEvent(id: UUID) {}
    func sendToJS(_ message: BridgeMessage) { sentMessages.append(message) }
    func evaluateJavaScript(_ script: String, completion: @escaping (Result<Any?, Error>) -> Void) {}
    func setBridgeMessageDelegate(_ delegate: WebBridgeMessageDelegate?) {}
    func setNavigationDelegate(_ delegate: WebBridgeNavigationDelegate?) {}
}

private final class DatabaseRepositorySpy: DatabaseRepositoryProtocol {
    var limit: Int = 0
    var lifeLimitDate: Date?
    var deprecatedLimit: Int = 0
    var onObjectsDidChange: (() -> Void)?
    private(set) var createdEvents: [Event] = []

    func create(event: Event) throws {
        createdEvents.append(event)
    }

    func readEvent(by transactionId: String) throws -> Event? {
        createdEvents.first(where: { $0.transactionId == transactionId })
    }

    func update(event: Event) throws {}
    func delete(event: Event) throws {}
    func query(fetchLimit: Int, retryDeadline: TimeInterval) throws -> [Event] { [] }
    func removeDeprecatedEventsIfNeeded() throws {}
    func countDeprecatedEvents() throws -> Int { 0 }
    func erase() throws { createdEvents.removeAll() }
    func countEvents() throws -> Int { createdEvents.count }
}

private final class EventRepositorySpy: EventRepository {
    private(set) var sentRawEvents: [Event] = []

    func send(event: Event, completion: @escaping (Result<Void, MindboxError>) -> Void) {
        completion(.success(()))
    }

    func send<T>(type: T.Type, event: Event, completion: @escaping (Result<T, MindboxError>) -> Void) where T: Decodable {}

    func sendRaw(event: Event, completion: @escaping (Result<Data, MindboxError>) -> Void) {
        sentRawEvents.append(event)
        completion(.success(Data(#"{"status":"Success"}"#.utf8)))
    }

    func cancelAllRequests() {}
}
