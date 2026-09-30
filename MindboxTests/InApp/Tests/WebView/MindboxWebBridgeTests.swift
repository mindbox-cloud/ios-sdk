//
//  MindboxWebBridgeTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 06.07.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import UIKit
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

private final class MessageSpy: WebBridgeMessageDelegate {
    private(set) var received: [BridgeMessage] = []
    func webBridge(_ bridge: MindboxWebBridge, didReceiveBridgeMessage message: BridgeMessage) {
        received.append(message)
    }
}

@Suite("MindboxWebBridge answers", .tags(.webView))
@MainActor
struct MindboxWebBridgeAnswerTests {

    enum Surface: CaseIterable {
        case overlay
        case embeddedBlock
    }

    init() {
        TestConfiguration.configure()
    }

    @Test("A request for an action outside the vocabulary is refused with an error envelope, not acknowledged",
          arguments: Surface.allCases)
    func unknownActionIsRefused(surface: Surface) throws {
        let bed = AnswerBed(surface)
        let request = try #require(BridgeMessage(type: .request, action: "totally.new", payload: "{}"))

        try bed.post(request)

        let envelopes = bed.sentEnvelopes()
        #expect(envelopes.count == 1)
        let envelope = try #require(envelopes.last)
        #expect(envelope["type"] as? String == "error")
        #expect(envelope["action"] as? String == "totally.new")
        #expect(envelope["id"] as? String == request.id.uuidString.lowercased())
        let payload = try #require(bed.payloadObject(of: envelope))
        #expect(payload["error"] as? String == "unknown_action")
    }

    @Test("A request for an action outside the vocabulary never reaches the host, a known one still does")
    func unknownActionIsNotForwardedToTheHost() throws {
        let bed = AnswerBed(.overlay)
        let host = MessageSpy()
        bed.bridge.messageDelegate = host
        let unknown = try #require(BridgeMessage(type: .request, action: "totally.new", payload: "{}"))
        let known = BridgeMessage.request(.log, payload: .string("{}"))

        try bed.post(unknown)
        try bed.post(known)

        #expect(bed.sentEnvelopes().map { $0["id"] as? String } == [unknown.id.uuidString.lowercased()])
        #expect(host.received.map(\.id) == [known.id])
    }

    @Test("close, init, click, hide and log are answered exactly once with {\"success\":true}",
          arguments: Surface.allCases, [BridgeMessage.Action.close, .`init`, .click, .hide, .log])
    func lifecycleAndLogAreAnsweredOnce(surface: Surface, action: BridgeMessage.Action) throws {
        let bed = AnswerBed(surface, handlers: [LifecycleActionHandler(), LogActionHandler()])
        let request = BridgeMessage.request(action, payload: .string("{}"))

        try bed.post(request)

        let envelopes = bed.sentEnvelopes()
        #expect(envelopes.count == 1)
        let envelope = try #require(envelopes.first)
        #expect(envelope["type"] as? String == "response")
        #expect(envelope["action"] as? String == action.rawValue)
        #expect(envelope["id"] as? String == request.id.uuidString.lowercased())
        #expect(envelope["payload"] as? String == #"{"success":true}"#)
    }

    @Test("A request for an action only the SDK sends is refused as not served",
          arguments: Surface.allCases, ["motion.event", "initDataUpdated", "localState.changed", "navigationIntercepted"])
    func requestForSDKOnlyActionIsNotServed(surface: Surface, action: String) throws {
        let bed = AnswerBed(surface)
        let request = try #require(BridgeMessage(type: .request, action: action, payload: "{}"))

        try bed.post(request)

        let envelopes = bed.sentEnvelopes()
        #expect(envelopes.count == 1)
        let envelope = try #require(envelopes.first)
        #expect(envelope["type"] as? String == "error")
        #expect(envelope["action"] as? String == action)
        #expect(envelope["id"] as? String == request.id.uuidString.lowercased())
        #expect(envelope["payload"] as? String == #"{"error":"not_served"}"#)
    }

    @Test("The page's answer to a request the SDK sent is not answered back",
          arguments: Surface.allCases, [BridgeMessage.Action.initDataUpdated, .localStateChanged, .motionEvent, .navigationIntercepted])
    func answerToSDKRequestIsNotAnswered(surface: Surface, action: BridgeMessage.Action) throws {
        let bed = AnswerBed(surface)
        let pushed = BridgeMessage(type: .request, action: action, payload: .object([:]))
        bed.bridge.send(pushed)

        try bed.post(BridgeMessage(type: .response, action: action, payload: .object(["success": .bool(true)]), id: pushed.id))

        #expect(bed.sentEnvelopes().map { $0["type"] as? String } == ["request"])
    }

    @Test("The page's answer to initDataUpdated confirms the push")
    func answerToInitDataUpdatedConfirmsThePush() throws {
        let bed = AnswerBed(.embeddedBlock)
        let pushed = BridgeMessage(type: .request, action: .initDataUpdated, payload: .object([:]))
        bed.bridge.send(pushed)

        try bed.post(BridgeMessage(type: .response,
                                   action: .initDataUpdated,
                                   payload: .object(["success": .bool(true)]),
                                   id: pushed.id))

        #expect(bed.dataPushConfirmations == 1)
    }

    @Test("A request without a string action gets no answer at all",
          arguments: Surface.allCases, ["", #""action":5,"#, #""action":null,"#])
    func requestWithoutStringActionIsNotAnswered(surface: Surface, actionField: String) {
        let bed = AnswerBed(surface)

        bed.post(rawBody: Self.rawRequest(actionField: actionField))

        #expect(bed.sentScripts().isEmpty)
    }

    @Test("The same raw request with a string action is answered", arguments: Surface.allCases)
    func rawRequestWithStringActionIsAnswered(surface: Surface) {
        let bed = AnswerBed(surface)

        bed.post(rawBody: Self.rawRequest(actionField: #""action":"log","#))

        #expect(bed.sentEnvelopes().count == 1)
    }

    private static func rawRequest(actionField: String) -> String {
        let version = Constants.Versions.webBridgeVersion
        let id = UUID().uuidString.lowercased()
        return #"{"version":\#(version),"type":"request",\#(actionField)"payload":"{}","id":"\#(id)","timestamp":1}"#
    }

    enum AnswerlessRequest: CaseIterable {
        case haptic
        case motionStop
        case motionStart
        case openLink
        case notificationSettings
        case applicationSettings
        case asyncOperation
        case contentRendered

        var message: BridgeMessage {
            switch self {
            case .haptic:
                return .request(.haptic, payload: .object(["type": .string("impact")]))
            case .motionStop:
                return .request(.motionStop)
            case .motionStart:
                return .request(.motionStart, payload: .object(["gestures": .array([.string("flip")])]))
            case .openLink:
                return .request(.openLink, payload: .object(["url": .string("mindbox-test://path")]))
            case .notificationSettings:
                return .request(.settingsOpen, payload: .object(["target": .string("notifications")]))
            case .applicationSettings:
                return .request(.settingsOpen, payload: .object(["target": .string("application")]))
            case .asyncOperation:
                return .request(.asyncOperation, payload: .object(["operation": .string("Test.Async"),
                                                                   "body": .object(["field": .string("value")])]))
            case .contentRendered:
                return .request(.contentRendered, payload: .object(["count": .int(3)]))
            }
        }
    }

    @Test("A request whose handler answers without data gets exactly {\"success\":true} on every surface",
          arguments: Surface.allCases, AnswerlessRequest.allCases)
    func answerWithoutDataIsExactlySuccess(surface: Surface, request: AnswerlessRequest) async throws {
        let bed = AnswerBed(surface, handlers: Self.answerlessHandlers())
        let message = request.message

        try bed.post(message)
        await drainMainQueue(until: { bed.sentEnvelopes().count > 1 })

        let envelopes = bed.sentEnvelopes()
        #expect(envelopes.count == 1)
        let envelope = try #require(envelopes.first)
        #expect(envelope["type"] as? String == "response")
        #expect(envelope["id"] as? String == message.id.uuidString.lowercased())
        #expect(envelope["payload"] as? String == #"{"success":true}"#)
    }

    @Test("A show the block's service accepted gets exactly {\"success\":true}")
    func acceptedShowIsExactlySuccess() throws {
        let bed = AnswerBed(.embeddedBlock, handlers: [ShowInAppActionHandler()])
        let message = BridgeMessage.request(.showInApp, payload: .object(["inappId": .string("story-1")]))

        try bed.post(message)

        let envelopes = bed.sentEnvelopes()
        #expect(envelopes.count == 1)
        let envelope = try #require(envelopes.first)
        #expect(envelope["type"] as? String == "response")
        #expect(envelope["id"] as? String == message.id.uuidString.lowercased())
        #expect(envelope["payload"] as? String == #"{"success":true}"#)
    }

    private static func answerlessHandlers() -> [WebBridgeActionHandler] {
        let opener = URLOpenerSpy()
        opener.result = true

        return [
            HapticActionHandler(makeService: { HapticServiceSpy() }),
            MotionActionHandler(makeService: { MotionServiceSpy(result: MotionStartResult(started: [.flip], unavailable: [])) }),
            OpenLinkActionHandler(urlOpener: opener),
            SettingsActionHandler(urlOpener: opener, openNotificationSettings: { $0(true) }),
            OperationActionHandler(featureToggleManager: FeatureToggleManager(),
                                   databaseRepository: QueueStub(),
                                   inAppEventSender: InappMessageEventSender(inAppMessagesManager: InAppCoreManagerMock())),
            ContentRenderedActionHandler()
        ]
    }
}

@MainActor
private final class AnswerBed {

    final class EvaluationSpyWebView: WKWebView {
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

    let bridge: MindboxWebBridge
    private(set) var dataPushConfirmations = 0

    private let webView = EvaluationSpyWebView(frame: .zero, configuration: WKWebViewConfiguration())
    private let navigationFactory = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
    private var host: WebBridgeHost?

    init(_ surface: MindboxWebBridgeAnswerTests.Surface,
         handlers: [WebBridgeActionHandler] = WebBridgeActionHandlerFactory.makeHandlers()) {
        bridge = MindboxWebBridge(webView: webView)
        let facade = BridgeForwardingFacade(bridge: bridge, webView: webView)
        let registry = WebBridgeActionRegistry(handlers: handlers)

        switch surface {
        case .overlay:
            let view = TransparentView(frame: .zero,
                                       params: [:],
                                       userAgent: "",
                                       operation: nil,
                                       inAppId: "inapp-1",
                                       tags: nil,
                                       actionRegistry: registry)
            view.facade = facade
            view.webPageRegistry = MindboxWebPageRegistry()
            facade.setBridgeMessageDelegate(view)
            host = view
        case .embeddedBlock:
            let page = EmbeddedBlockWebViewPage(content: .stub,
                                                facade: facade,
                                                registry: MindboxWebPageRegistry(),
                                                actionRegistry: registry)
            page.onDataPushConfirmed = { [weak self] in
                self?.dataPushConfirmations += 1
            }
            page.onShowInAppRequest = { _, _, completion in completion(.success(())) }
            host = page
        }

        bridge.expectContentNavigation(nil)
        // swiftlint:disable:next force_unwrapping
        bridge.webView(webView, didCommit: navigationFactory.loadHTMLString("<html></html>", baseURL: nil)!)
    }

    func post(_ message: BridgeMessage) throws {
        let body = try #require(message.jsonString())
        post(rawBody: body)
    }

    func post(rawBody body: String) {
        bridge.userContentController(
            webView.configuration.userContentController,
            didReceive: FakeScriptMessage(name: Constants.WebViewBridgeJS.handlerName, body: body)
        )
    }

    func sentScripts() -> [String] {
        webView.scripts
    }

    func sentEnvelopes() -> [[String: Any]] {
        webView.scripts.compactMap { script in
            guard let start = script.range(of: ".emit("),
                  let end = script.range(of: ");return", options: .backwards),
                  let unescaped = (try? JSONSerialization.jsonObject(with: Data(script[start.upperBound..<end.lowerBound].utf8),
                                                                     options: .fragmentsAllowed)) as? String else { return nil }

            return (try? JSONSerialization.jsonObject(with: Data(unescaped.utf8))) as? [String: Any]
        }
    }

    func payloadObject(of envelope: [String: Any]) -> [String: Any]? {
        (envelope["payload"] as? String).flatMap { (try? JSONSerialization.jsonObject(with: Data($0.utf8))) as? [String: Any] }
    }
}

private final class BridgeForwardingFacade: InappWebViewFacadeProtocol {

    private let bridge: MindboxWebBridge
    private let webView: WKWebView

    init(bridge: MindboxWebBridge, webView: WKWebView) {
        self.bridge = bridge
        self.webView = webView
    }

    func makeView() -> UIView { webView }
    func loadHTML(baseUrl: String, contentUrl: String, onFailure: @escaping () -> Void) {}
    func applyViewSettings(scrollViewDelegate: UIScrollViewDelegate?) {}
    func cleanWebView() {}
    func makeStartPayload(_ completion: @escaping (JSONValue) -> Void) { completion(.string("{}")) }
    func sendInitDataUpdated(params: [String: JSONValue]) {}
    func sendToJS(_ message: BridgeMessage) { bridge.send(message) }
    func evaluateJavaScript(_ script: String, completion: @escaping (Result<Any?, Error>) -> Void) {}
    func setBridgeMessageDelegate(_ delegate: WebBridgeMessageDelegate?) { bridge.messageDelegate = delegate }
    func setNavigationDelegate(_ delegate: WebBridgeNavigationDelegate?) { bridge.navigationDelegate = delegate }
    func retryContentLoadBypassingCache(failedURL: String?, onPurgeOutcome: @escaping (_ didRemoveAnything: Bool) -> Void) {}
    func releaseRetainedContent() {}
}

private final class QueueStub: DatabaseRepositoryProtocol {

    var limit: Int = 0
    var lifeLimitDate: Date?
    var deprecatedLimit: Int = 0
    var onObjectsDidChange: (() -> Void)?

    func create(event: Event) throws {}
    func readEvent(by transactionId: String) throws -> Event? { nil }
    func update(event: Event) throws {}
    func delete(event: Event) throws {}
    func query(fetchLimit: Int, retryDeadline: TimeInterval) throws -> [Event] { [] }
    func removeDeprecatedEventsIfNeeded() throws {}
    func countDeprecatedEvents() throws -> Int { 0 }
    func erase() throws {}
    func countEvents() throws -> Int { 0 }
}
