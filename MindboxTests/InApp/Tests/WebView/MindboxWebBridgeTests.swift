//
//  MindboxWebBridgeTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 06.07.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import WebKit
@_spi(Internal) @testable import Mindbox

/// A reused (pre-warmed) WebView delivers navigation callbacks from previous owners'
/// loads; leftovers must never reach the show's delegate.
@Suite("MindboxWebBridge navigation staleness", .tags(.webView))
@MainActor
struct MindboxWebBridgeStalenessTests {

    private final class DelegateSpy: WebBridgeNavigationDelegate {
        private(set) var startCount = 0
        private(set) var finishCount = 0
        private(set) var failCount = 0
        private(set) var finishURLs: [URL?] = []

        func webBridge(_ bridge: MindboxWebBridge, didStartProvisionalNavigation url: URL?) { startCount += 1 }
        func webBridge(_ bridge: MindboxWebBridge, didFinishNavigation url: URL?) {
            finishCount += 1
            finishURLs.append(url)
        }
        func webBridge(_ bridge: MindboxWebBridge, didFailProvisionalNavigation url: URL?, error: Error) { failCount += 1 }
        func webBridge(_ bridge: MindboxWebBridge, decidePolicyFor url: URL?, navigationType: WKNavigationType,
                       decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }
    }

    private let webView: WKWebView
    private let bridge: MindboxWebBridge
    private let spy: DelegateSpy
    // Source of real, distinct WKNavigation objects; separate from `webView` so its async
    // delegate callbacks can never reach the bridge under test.
    private let navigationFactory = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())

    init() {
        webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        bridge = MindboxWebBridge(webView: webView)
        spy = DelegateSpy()
        bridge.navigationDelegate = spy
    }

    private func makeNavigation() -> WKNavigation {
        // swiftlint:disable:next force_unwrapping
        navigationFactory.loadHTMLString("<html></html>", baseURL: nil)!
    }

    @Test("Before the show's own load every navigation callback is stale")
    func everythingIsStaleBeforeContentLoad() {
        bridge.webView(webView, didStartProvisionalNavigation: makeNavigation())
        bridge.webView(webView, didFinish: makeNavigation())

        #expect(spy.startCount == 0)
        #expect(spy.finishCount == 0)
    }

    @Test("Only the expected navigation's callbacks reach the delegate")
    func strangerNavigationsAreFiltered() {
        let expected = makeNavigation()
        bridge.expectContentNavigation(expected)

        let stranger = makeNavigation()
        bridge.webView(webView, didStartProvisionalNavigation: stranger)
        bridge.webView(webView, didFinish: stranger)
        #expect(spy.startCount == 0)
        #expect(spy.finishCount == 0)

        bridge.webView(webView, didStartProvisionalNavigation: expected)
        bridge.webView(webView, didFinish: expected)
        #expect(spy.startCount == 1)
        #expect(spy.finishCount == 1)
    }

    @Test("After the expected navigation finished the filter opens for page-initiated navigations")
    func filterOpensAfterExpectedFinish() {
        let expected = makeNavigation()
        bridge.expectContentNavigation(expected)
        bridge.webView(webView, didFinish: expected)
        #expect(spy.finishCount == 1)

        bridge.webView(webView, didFinish: makeNavigation())
        #expect(spy.finishCount == 2)
    }

    @Test("A nil expected navigation (loadHTMLString returned nil) fails open, not closed")
    func nilExpectedNavigationFailsOpen() {
        bridge.expectContentNavigation(nil)

        bridge.webView(webView, didFinish: makeNavigation())

        #expect(spy.finishCount == 1)
    }

    @Test("A nil callback navigation fails open, mirroring the nil-expected case")
    func nilCallbackNavigationFailsOpen() {
        bridge.expectContentNavigation(makeNavigation())

        bridge.webView(webView, didFailProvisionalNavigation: nil, withError: NSError(domain: "test", code: 2))
        #expect(spy.failCount == 1)

        bridge.webView(webView, didFinish: nil)
        #expect(spy.finishCount == 1)
    }

    @Test("Stale failure callbacks never close the show")
    func staleFailuresAreFiltered() {
        bridge.expectContentNavigation(makeNavigation())

        bridge.webView(webView, didFailProvisionalNavigation: makeNavigation(),
                       withError: NSError(domain: "test", code: 1))

        #expect(spy.failCount == 0)
    }

    @Test("Stale non-provisional failures are filtered too")
    func staleDidFailIsFiltered() {
        bridge.expectContentNavigation(makeNavigation())

        bridge.webView(webView, didFail: makeNavigation(), withError: NSError(domain: "test", code: 3))

        #expect(spy.failCount == 0)
    }

    @Test("The expected navigation's non-provisional failure reaches the delegate")
    func expectedDidFailReachesDelegate() {
        let expected = makeNavigation()
        bridge.expectContentNavigation(expected)

        bridge.webView(webView, didFail: expected, withError: NSError(domain: "test", code: 4))

        #expect(spy.failCount == 1)
    }

    @Test("Only the show's own finish reports the content URL; page navigations report their real URL")
    func finishReportsPerNavigationURL() {
        let contentURL = URL(string: "https://content.mindbox.ru/index.html")
        bridge.updateContentURL(contentURL)
        let expected = makeNavigation()
        bridge.expectContentNavigation(expected)

        bridge.webView(webView, didFinish: expected)
        // The unloaded test instance's real URL is nil — distinct from contentURL.
        bridge.webView(webView, didFinish: makeNavigation())

        #expect(spy.finishURLs.count == 2)
        #expect(spy.finishURLs.first == contentURL)
        #expect(spy.finishURLs.last == URL?.none)
    }
}

/// Script messages have their own gate: until the show's own document commits, a reused
/// WebView's previous document (e.g. a dying prewarm page) can still post to the freshly
/// attached handler — answering it could present a page that must never be shown.
@Suite("MindboxWebBridge message gate", .tags(.webView))
@MainActor
struct MindboxWebBridgeMessageGateTests {

    private final class MessageSpy: WebBridgeMessageDelegate {
        private(set) var received: [BridgeMessage] = []
        func webBridge(_ bridge: MindboxWebBridge, didReceiveBridgeMessage message: BridgeMessage) {
            received.append(message)
        }
    }

    /// WKScriptMessage's real initializer is WebKit-internal; the bridge only reads
    /// `name` and `body`.
    private final class FakeScriptMessage: WKScriptMessage {
        private let fakeName: String
        private let fakeBody: Any

        init(name: String, body: Any) {
            self.fakeName = name
            self.fakeBody = body
            super.init()
        }

        override var name: String { fakeName }
        override var body: Any { fakeBody }
    }

    private let webView: WKWebView
    private let bridge: MindboxWebBridge
    private let spy: MessageSpy
    private let navigationFactory = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())

    init() {
        webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        bridge = MindboxWebBridge(webView: webView)
        spy = MessageSpy()
        bridge.messageDelegate = spy
    }

    private func makeNavigation() -> WKNavigation {
        // swiftlint:disable:next force_unwrapping
        navigationFactory.loadHTMLString("<html></html>", baseURL: nil)!
    }

    private func postValidMessage() throws {
        let message = try #require(BridgeMessage(type: .request, action: "log", payload: "hi"))
        let body = try #require(message.jsonString())
        bridge.userContentController(
            webView.configuration.userContentController,
            didReceive: FakeScriptMessage(name: Constants.WebViewBridgeJS.handlerName, body: body)
        )
    }

    @Test("Messages are dropped until the show's own navigation commits")
    func messagesGatedUntilExpectedCommit() throws {
        try postValidMessage()
        #expect(spy.received.isEmpty)

        let expected = makeNavigation()
        bridge.expectContentNavigation(expected)

        try postValidMessage()
        #expect(spy.received.isEmpty)

        // A stale (stranger) commit must not open the gate.
        bridge.webView(webView, didCommit: makeNavigation())
        try postValidMessage()
        #expect(spy.received.isEmpty)

        bridge.webView(webView, didCommit: expected)
        try postValidMessage()
        #expect(spy.received.count == 1)
    }

    @Test("A nil expected navigation opens the gate at the first commit (fail-open)")
    func nilExpectedNavigationGateOpensOnCommit() throws {
        bridge.expectContentNavigation(nil)

        try postValidMessage()
        #expect(spy.received.isEmpty)

        bridge.webView(webView, didCommit: makeNavigation())
        try postValidMessage()
        #expect(spy.received.count == 1)
    }

    @Test("A reload re-arms the gate until the new document commits")
    func reloadRearmsGate() throws {
        let first = makeNavigation()
        bridge.expectContentNavigation(first)
        bridge.webView(webView, didCommit: first)
        bridge.webView(webView, didFinish: first)
        try postValidMessage()
        #expect(spy.received.count == 1)

        let reload = makeNavigation()
        bridge.expectContentNavigation(reload)
        try postValidMessage()
        #expect(spy.received.count == 1)

        bridge.webView(webView, didCommit: reload)
        try postValidMessage()
        #expect(spy.received.count == 2)
    }
}

@Suite("MindboxWebBridge blanket answers", .tags(.webView))
@MainActor
struct MindboxWebBridgeBlanketAnswerTests {

    private final class EvaluationSpyWebView: WKWebView {
        private(set) var scripts: [String] = []
        override func evaluateJavaScript(_ javaScriptString: String, completionHandler: (@MainActor @Sendable (Any?, (any Error)?) -> Void)? = nil) {
            scripts.append(javaScriptString)
            completionHandler?(true, nil)
        }
    }

    private final class FakeScriptMessage: WKScriptMessage {
        private let fakeName: String
        private let fakeBody: Any

        init(name: String, body: Any) {
            self.fakeName = name
            self.fakeBody = body
            super.init()
        }

        override var name: String { fakeName }
        override var body: Any { fakeBody }
    }

    private let webView = EvaluationSpyWebView(frame: .zero, configuration: WKWebViewConfiguration())
    private let navigationFactory = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
    private let bridge: MindboxWebBridge

    init() {
        bridge = MindboxWebBridge(webView: webView)
        bridge.expectContentNavigation(nil)
        // swiftlint:disable:next force_unwrapping
        bridge.webView(webView, didCommit: navigationFactory.loadHTMLString("<html></html>", baseURL: nil)!)
    }

    private func post(_ message: BridgeMessage) throws {
        let body = try #require(message.jsonString())
        bridge.userContentController(
            webView.configuration.userContentController,
            didReceive: FakeScriptMessage(name: Constants.WebViewBridgeJS.handlerName, body: body)
        )
    }

    private func sentEnvelopes() -> [[String: Any]] {
        webView.scripts.compactMap { script in
            guard let start = script.range(of: ".emit("),
                  let end = script.range(of: ");return", options: .backwards),
                  let unescaped = (try? JSONSerialization.jsonObject(with: Data(script[start.upperBound..<end.lowerBound].utf8),
                                                                     options: .fragmentsAllowed)) as? String else { return nil }

            return (try? JSONSerialization.jsonObject(with: Data(unescaped.utf8))) as? [String: Any]
        }
    }

    private func payloadObject(of envelope: [String: Any]) -> [String: Any]? {
        (envelope["payload"] as? String).flatMap { (try? JSONSerialization.jsonObject(with: Data($0.utf8))) as? [String: Any] }
    }

    @Test("A request for an action outside the vocabulary is refused with an error envelope, not acknowledged")
    func unknownActionIsRefused() throws {
        let request = try #require(BridgeMessage(type: .request, action: "totally.new", payload: "{}"))

        try post(request)

        let envelopes = sentEnvelopes()
        #expect(envelopes.count == 1)
        let envelope = try #require(envelopes.last)
        #expect(envelope["type"] as? String == "error")
        #expect(envelope["action"] as? String == "totally.new")
        #expect(envelope["id"] as? String == request.id.uuidString.lowercased())
        let payload = try #require(payloadObject(of: envelope))
        #expect(payload["error"] as? String == "unknown action 'totally.new'")
    }

    @Test("A known non-deferred request keeps its blanket success")
    func knownNonDeferredRequestIsAcknowledged() throws {
        let request = try #require(BridgeMessage(type: .request, action: "log", payload: #"{"message":"hi"}"#))

        try post(request)

        let envelope = try #require(sentEnvelopes().last)
        #expect(envelope["type"] as? String == "response")
        #expect(envelope["id"] as? String == request.id.uuidString.lowercased())
        let payload = try #require(payloadObject(of: envelope))
        #expect(payload["success"] as? Bool == true)
    }
}
