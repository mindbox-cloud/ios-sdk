//
//  WebViewLocalStateBroadcastTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 8/13/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import UIKit
import MindboxLogger
@_spi(Internal) @testable import Mindbox

@MainActor
@Suite("WebView local state broadcast", .tags(.webView))
final class WebViewLocalStateBroadcastTests {

    private let registry = MindboxWebPageRegistry()
    private let host = BroadcastHostSpy()
    private let handler: LocalStateActionHandler

    init() {
        TestConfiguration.configure()
        // In memory on purpose: a real store would leave watched marks behind for the next suite.
        handler = LocalStateActionHandler(makeStorage: { InMemoryLocalStateStorage() },
                                          webPageRegistry: registry)
    }

    @Test("A write reaches the other live pages with the same keys the writer got back")
    func writeIsBroadcastToOtherPages() throws {
        let listener = WebPageSpy()
        registry.register(listener)

        send(#"{"data":{"inapp.completed.story-1":"2026-08-13T10:00:00Z"}}"#)

        let announced = try #require(listener.received.first)
        #expect(announced.action == .localStateChanged)
        #expect(announced.payload == host.sent.last?.payload)
    }

    @Test("The writer is still answered")
    func writerIsStillAnswered() {
        registry.register(WebPageSpy())

        send(#"{"data":{"inapp.completed.story-1":"2026-08-13T10:00:00Z"}}"#)

        #expect(host.sent.last?.type == .response)
    }

    @Test("The writer does not hear its own write")
    func writerIsExcludedFromTheBroadcast() {
        let listener = WebPageSpy()
        registry.register(host)
        registry.register(listener)

        send(#"{"data":{"inapp.completed.story-1":"2026-08-13T10:00:00Z"}}"#)

        #expect(listener.received.count == 1)
        #expect(host.pushed.isEmpty)
    }

    @Test("A rejected write is not announced")
    func rejectedWriteIsNotBroadcast() {
        let listener = WebPageSpy()
        registry.register(listener)

        send(#"{"nothing":"useful"}"#)

        #expect(host.sent.last?.type == .error)
        #expect(listener.received.isEmpty)
    }

    // MARK: - Helpers

    private func send(_ payload: String) {
        handler.handle(BridgeMessage(type: .request, action: .localStateSet, payload: .string(payload)),
                       host: host)
    }
}

private final class BroadcastHostSpy: WebBridgeHost, MindboxWebPage {

    private(set) var sent: [BridgeMessage] = []
    private(set) var pushed: [(action: BridgeMessage.Action, payload: JSONValue)] = []

    var contentId: String { "writer-page" }
    var logCategory: LogCategory { .webViewInAppMessages }
    var tags: [String: String]? { nil }
    var presentingViewController: UIViewController? { nil }
    var isUserPresent: Bool { true }

    func send(_ message: BridgeMessage) {
        sent.append(message)
    }

    func makeStartPayload() -> JSONValue {
        .string("{}")
    }

    func push(_ action: BridgeMessage.Action, payload: JSONValue) {
        pushed.append((action, payload))
    }
}

private final class InMemoryLocalStateStorage: WebViewLocalStateStorageProtocol {

    private var version = 1
    private var storage: [String: String] = [:]

    func get(keys: [String]) -> WebViewLocalState {
        let data = keys.isEmpty ? storage : storage.filter { keys.contains($0.key) }
        return WebViewLocalState(version: version, data: data)
    }

    func set(data: [String: String?]) -> WebViewLocalState {
        apply(data)
        return WebViewLocalState(version: version, data: storage.filter { data.keys.contains($0.key) })
    }

    func initialize(version: Int, data: [String: String?]) -> WebViewLocalState? {
        guard version > 0 else { return nil }

        self.version = version
        apply(data)
        return WebViewLocalState(version: version, data: storage.filter { data.keys.contains($0.key) })
    }

    private func apply(_ data: [String: String?]) {
        for (key, value) in data {
            if let value {
                storage[key] = value
            } else {
                storage.removeValue(forKey: key)
            }
        }
    }
}

private final class WebPageSpy: MindboxWebPage {

    private(set) var received: [(action: BridgeMessage.Action, payload: JSONValue)] = []

    func push(_ action: BridgeMessage.Action, payload: JSONValue) {
        received.append((action, payload))
    }
}
