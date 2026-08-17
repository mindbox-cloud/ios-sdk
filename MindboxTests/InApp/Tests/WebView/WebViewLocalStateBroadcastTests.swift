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

/// A write to local state is announced, not only answered. That is what lets a feed grey a ring while
/// the story that wrote the mark is still on top of it — the feed never asks, so nobody would tell it.
@MainActor
@Suite("WebView local state broadcast", .tags(.webView))
final class WebViewLocalStateBroadcastTests {

    private let registry = MindboxWebPageRegistry()
    private let host = BroadcastHostSpy()
    private let handler: LocalStateActionHandler

    init() {
        TestConfiguration.configure()
        // In memory on purpose: the announcement is what is under test, and a real store would leave
        // watched marks behind for whatever suite runs next.
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

    /// The response still goes to the writer: the announcement is in addition to the answer, not
    /// instead of it.
    @Test("The writer is still answered")
    func writerIsStillAnswered() {
        registry.register(WebPageSpy())

        send(#"{"data":{"inapp.completed.story-1":"2026-08-13T10:00:00Z"}}"#)

        #expect(host.sent.last?.type == .response)
    }

    /// The page that wrote already holds the answer — hearing the broadcast too would make it
    /// repaint over its own write.
    @Test("The writer does not hear its own write")
    func writerIsExcludedFromTheBroadcast() {
        let listener = WebPageSpy()
        registry.register(host)
        registry.register(listener)

        send(#"{"data":{"inapp.completed.story-1":"2026-08-13T10:00:00Z"}}"#)

        #expect(listener.received.count == 1)
        #expect(host.pushed.isEmpty)
    }

    /// A payload with nothing to store is an error, and an error is not news: announcing it would make
    /// every other page redraw over a write that never happened.
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

/// The page that is writing: a bridge host for the handler, and a page the registry could hold —
/// so the author-exclusion promise is checkable on the same object identity the handler passes.
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
