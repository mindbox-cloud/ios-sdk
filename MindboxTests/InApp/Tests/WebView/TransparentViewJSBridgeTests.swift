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
    private let showController = ShowControllerSpy()
    private var closes = 0
    private var failures: [InAppPresentationError] = []
    private weak var controllerUnderTest: WebViewController?
    private var timeoutFlagsSeenAtClose: [Bool?] = []
    private var windowLookups = 0
    private var presentations = 0
    /// Registry entries are weak, so the view a test built is held here as well: a local could
    /// otherwise be released before an assertion that needs the page still registered.
    private var viewUnderTest: TransparentView?

    enum ShowState {
        case open
        case closed
    }

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

    // MARK: - Broadcasts

    @Test("A popup joins the broadcast set on its first ready, and only once", .tags(.webView))
    func popupJoinsTheBroadcastSetOnReady() {
        let registry = MindboxWebPageRegistry()
        let view = makeView(tags: nil, webPageRegistry: registry)

        send(.ready, payload: "{}", to: view)
        send(.ready, payload: "{}", to: view)

        #expect(registry.count == 1)
    }

    @Test("A broadcast reaches the popup's page as a request carrying the payload", .tags(.webView))
    func broadcastReachesThePopupAsARequest() throws {
        let registry = MindboxWebPageRegistry()
        let view = makeView(tags: nil, webPageRegistry: registry)
        send(.ready, payload: "{}", to: view)

        registry.broadcast(.localStateChanged, payload: .object(["version": .int(3)]), excluding: nil)

        #expect(facade.sentRequests.count == 1)
        let pushed = try #require(facade.sentRequests.first)
        #expect(pushed.type == .request)
        #expect(pushed.parsedAction == .localStateChanged)
        #expect(pushed.payload == .object(["version": .int(3)]))
    }

    @Test("The popup that wrote is excluded by identity, so it never hears itself", .tags(.webView))
    func popupDoesNotHearItsOwnWrite() {
        let registry = MindboxWebPageRegistry()
        let view = makeView(tags: nil, webPageRegistry: registry)
        send(.ready, payload: "{}", to: view)

        registry.broadcast(.localStateChanged, payload: .object(["version": .int(3)]), excluding: view)

        #expect(facade.sentRequests.isEmpty)
    }

    @Test("Each broadcast reaches the popup under an id of its own", .tags(.webView))
    func eachBroadcastCarriesItsOwnId() {
        let registry = MindboxWebPageRegistry()
        let view = makeView(tags: nil, webPageRegistry: registry)
        send(.ready, payload: "{}", to: view)

        registry.broadcast(.localStateChanged, payload: .object([:]), excluding: nil)
        registry.broadcast(.localStateChanged, payload: .object([:]), excluding: nil)

        #expect(facade.sentRequests.count == 2)
        #expect(facade.sentRequests[0].id != facade.sentRequests[1].id)
    }

    @Test("A broadcast reaches the popup's page while it is open, and not after the page closed it",
          .tags(.webView), arguments: [(ShowState.open, 1), (.closed, 0)])
    func broadcastReachesThePopupOnlyWhileOpen(state: ShowState, expectedPushes: Int) {
        let registry = MindboxWebPageRegistry()
        let view = makeView(tags: nil, webPageRegistry: registry, handlers: [LifecycleActionHandler()])
        send(.ready, payload: "{}", to: view)
        if state == .closed {
            send(.close, payload: "{}", to: view)
        }

        registry.broadcast(.localStateChanged, payload: .object(["version": .int(3)]), excluding: nil)

        #expect(facade.sentRequests.count == expectedPushes)
    }

    // MARK: - Page close

    enum BackToBack: CaseIterable {
        case closeThenError
        case errorThenClose
    }

    @Test("A page close and a page error back to back close the popup once", .tags(.webView), arguments: BackToBack.allCases)
    func pageCloseAndPageErrorCloseThePopupOnce(order: BackToBack) {
        let view = makeView(tags: nil, handlers: [LifecycleActionHandler()])
        send(.`init`, payload: "{}", to: view)

        switch order {
        case .closeThenError:
            send(.close, payload: "{}", to: view)
            receivePageError(to: view)
        case .errorThenClose:
            receivePageError(to: view)
            send(.close, payload: "{}", to: view)
        }

        #expect(showController.events == ["init", "close"])
    }

    @Test("After the page closed the popup, a later page request is neither acted on nor answered", .tags(.webView))
    func pageRequestAfterAPageCloseIsIgnored() {
        let view = makeView(tags: nil, handlers: [LifecycleActionHandler()])
        send(.`init`, payload: "{}", to: view)
        send(.close, payload: "{}", to: view)

        send(.click, payload: "{}", to: view)

        #expect(showController.events == ["init", "close"])
        #expect(facade.sentMessages.count == 2)
    }

    @Test("After the page closed the popup, a ready check that gives up fails nothing", .tags(.webView))
    func readyCheckGivingUpAfterAPageCloseFailsNothing() async throws {
        let view = makeView(tags: nil, handlers: [LifecycleActionHandler()])
        send(.`init`, payload: "{}", to: view)
        view.webBridge(MindboxWebBridge(webView: WKWebView()), didFinishNavigation: URL(string: "https://inapp.local/index.html"))

        send(.close, payload: "{}", to: view)
        let readyCheckBudget = Double(WebViewReadyChecker.maxAttempts + 2) * WebViewReadyChecker.retryDelay
        try await Task.sleep(nanoseconds: UInt64(readyCheckBudget * 1_000_000_000))

        #expect(showController.events == ["init", "close"])
    }

    @Test("A close the page did not ask for leaves the page unanswered and the popup closed once", .tags(.webView))
    func closeThePageDidNotAskForSilencesThePage() throws {
        let show = try makeShow()

        show.controller.closeTapWebViewVC()
        send(.close, payload: "{}", to: show.page)
        receivePageError(to: show.page)

        #expect(closes == 1)
        #expect(facade.sentMessages.isEmpty)
    }

    @Test("A popup that has closed is not closed again, whichever path asks", .tags(.webView))
    func closedPopupIsNotClosedAgain() throws {
        let show = try makeShow()

        show.controller.closeTapWebViewVC()
        show.controller.onClose()

        #expect(closes == 1)
    }

    enum Failure: CaseIterable {
        case loadFailure
        case timeout
    }

    @Test("A load failure or a timeout that closes the popup reports once, closes once, and marks the close as failed before it closes",
          .tags(.webView), arguments: Failure.allCases)
    func failureThatClosesThePopupIsReportedOnceAndMarkedBeforeTheClose(failure: Failure) throws {
        let show = try makeShow()

        report(failure, on: show.controller)

        #expect(failures.count == 1)
        #expect(closes == 1)
        #expect(timeoutFlagsSeenAtClose == [true])
    }

    @Test("A load failure or a timeout after the popup closed reports no failure", .tags(.webView), arguments: Failure.allCases)
    func lateFailureAfterACloseReportsNothing(failure: Failure) throws {
        let show = try makeShow()

        show.controller.closeTapWebViewVC()
        report(failure, on: show.controller)

        #expect(failures.isEmpty)
        #expect(closes == 1)
    }

    @Test("A popup closed between its init and the reveal is never shown", .tags(.webView))
    func popupClosedBeforeTheRevealIsNeverShown() async throws {
        let show = try makeShow(window: UIWindow())

        show.controller.onInit()
        show.controller.onClose()
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }

        #expect(windowLookups == 0)
        #expect(presentations == 0)
    }

    @Test("A hide the page asks for reaches the window while the popup is open, and none once it closed right after",
          .tags(.webView), arguments: [(ShowState.open, 1), (.closed, 0)])
    func hideReachesTheWindowOnlyWhileOpen(state: ShowState, expectedLookups: Int) async throws {
        let show = try makeShow(window: UIWindow())

        show.controller.onHide()
        if state == .closed {
            show.controller.onClose()
        }
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }

        #expect(windowLookups == expectedLookups)
    }

    @Test("A popup released without any close still tears its handlers down, once", .tags(.webView))
    func popupReleasedWithoutACloseTearsItsHandlersDown() {
        let handler = TearDownSpy()
        weak var released: TransparentView?

        autoreleasepool {
            released = makeView(tags: nil, handlers: [handler])
            viewUnderTest = nil
        }

        #expect(released == nil)
        #expect(handler.tearDowns == 1)
    }

    // MARK: - Closed show navigation

    @Test("A finished navigation starts a ready check while the popup is open, and none after it closed",
          .tags(.webView), arguments: [(ShowState.open, 1), (.closed, 0)])
    func finishedNavigationStartsAReadyCheckOnlyWhileOpen(state: ShowState, expectedChecks: Int) throws {
        let show = try makeShow()
        if state == .closed {
            show.controller.closeTapWebViewVC()
        }

        show.page.webBridge(MindboxWebBridge(webView: WKWebView()), didFinishNavigation: URL(string: "https://inapp.local/index.html"))

        #expect(facade.evaluateJavaScriptCalls == expectedChecks)
    }

    @Test("A script HTTP error is retried bypassing the cache while the popup is open, and not after the page closed it",
          .tags(.webView), arguments: [(ShowState.open, 1), (.closed, 0)])
    func scriptHTTPErrorIsRetriedOnlyWhileOpen(state: ShowState, expectedRetries: Int) {
        let view = makeView(tags: nil, handlers: [LifecycleActionHandler()])
        if state == .closed {
            send(.close, payload: "{}", to: view)
        }

        view.webBridge(MindboxWebBridge(webView: WKWebView()), didReceiveHTTPError: "https://inapp.local/bundle.js")

        #expect(facade.cacheBypassRetries == expectedRetries)
    }

    @Test("A link the page activates is cancelled and decided once either way, and handed to the page only while the popup is open",
          .tags(.webView), arguments: [(ShowState.open, [BridgeMessage.Action.navigationIntercepted]), (.closed, [])])
    func activatedLinkIsCancelledAndHandedToThePageOnlyWhileOpen(state: ShowState, expectedHandOvers: [BridgeMessage.Action]) throws {
        let show = try makeShow()
        if state == .closed {
            show.controller.closeTapWebViewVC()
        }
        var verdicts: [WKNavigationActionPolicy] = []

        show.page.webBridge(MindboxWebBridge(webView: WKWebView()),
                            decidePolicyFor: URL(string: "https://example.com/promo"),
                            navigationType: .linkActivated) { verdicts.append($0) }

        #expect(verdicts == [.cancel])
        #expect(facade.sentMessages.map(\.parsedAction) == expectedHandOvers)
    }

    @Test("After the popup closed, a navigation of type other is still allowed, decided once", .tags(.webView))
    func otherNavigationAfterACloseIsStillAllowed() throws {
        let show = try makeShow()
        show.controller.closeTapWebViewVC()
        var verdicts: [WKNavigationActionPolicy] = []

        show.page.webBridge(MindboxWebBridge(webView: WKWebView()),
                            decidePolicyFor: URL(string: "about:blank"),
                            navigationType: .other) { verdicts.append($0) }

        #expect(verdicts == [.allow])
    }

    // MARK: - Helpers

    private func makeView(tags: [String: String]?,
                          webPageRegistry: MindboxWebPageRegistry = MindboxWebPageRegistry(),
                          handlers: [WebBridgeActionHandler]? = nil) -> TransparentView {
        // The real dispatch path, with doubles behind the handler: this suite is about what
        // reaches the repositories, and it should keep proving the view routes there at all.
        let handler = OperationActionHandler(featureToggleManager: self.featureToggleManager,
                                             databaseRepository: self.databaseRepository,
                                             eventRepository: self.eventRepository)
        let view = TransparentView(
            frame: .zero,
            params: [:],
            userAgent: "",
            operation: nil,
            inAppId: "inapp-1",
            tags: tags,
            actionRegistry: WebBridgeActionRegistry(handlers: handlers ?? [handler]),
            noCacheRetryPolicy: WebViewNoCacheRetryPolicy { true }
        )
        view.facade = facade
        view.webPageRegistry = webPageRegistry
        view.delegate = showController
        view.webViewAction = showController
        viewUnderTest = view
        return view
    }

    private func makeShow(window: UIWindow? = nil) throws -> (controller: WebViewController, page: TransparentView) {
        let layer = WebviewContentBackgroundLayer(baseUrl: "https://inapp.local/",
                                                  contentUrl: "data:text/html;base64,PGh0bWw+PC9odG1sPg==",
                                                  params: [:])
        let model = ModalFormVariant(content: InappFormVariantContent(background: ContentBackground(layers: [.webview(layer)]),
                                                                      elements: nil))
        let controller = WebViewController(model: model,
                                           id: "inapp-1",
                                           imagesDict: [:],
                                           onPresented: { [weak self] in self?.presentations += 1 },
                                           onTapAction: { _, _ in },
                                           onCloseInApp: { [weak self] in
                                               guard let self else { return }
                                               self.closes += 1
                                               self.timeoutFlagsSeenAtClose.append(self.controllerUnderTest?.isTimeoutClose)
                                           },
                                           onError: { [weak self] in self?.failures.append($0) },
                                           windowProvider: { [weak self] in
                                               self?.windowLookups += 1
                                               return window
                                           },
                                           operation: nil,
                                           tags: nil)
        controllerUnderTest = controller
        controller.loadViewIfNeeded()
        let page = try #require(controller.view.subviews.compactMap { $0 as? TransparentView }.first)
        page.facade = facade
        return (controller, page)
    }

    private func send(_ action: BridgeMessage.Action, payload: String, to view: TransparentView) {
        let bridge = MindboxWebBridge(webView: WKWebView())
        let message = BridgeMessage(type: .request, action: action, payload: .string(payload))
        view.webBridge(bridge, didReceiveBridgeMessage: message)
    }

    private func report(_ failure: Failure, on controller: WebViewController) {
        switch failure {
        case .loadFailure:
            controller.closeLoadFailedWebViewVC(reason: "load failure")
        case .timeout:
            controller.closeTimeoutWebViewVC()
        }
    }

    private func receivePageError(to view: TransparentView) {
        let bridge = MindboxWebBridge(webView: WKWebView())
        let error = BridgeMessage(type: .error,
                                  action: .localStateChanged,
                                  payload: .object(["error": .string("localState.changed payload is missing the data object")]))
        view.webBridge(bridge, didReceiveBridgeMessage: error)
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
    private(set) var evaluateJavaScriptCalls = 0
    private(set) var cacheBypassRetries = 0
    var sentRequests: [BridgeMessage] { sentMessages.filter { $0.type == .request } }

    func makeView() -> UIView { UIView() }
    func loadHTML(baseUrl: String, contentUrl: String, onFailure: @escaping () -> Void) {}
    func applyViewSettings(scrollViewDelegate: UIScrollViewDelegate?) {}
    func cleanWebView() {}
    func makeStartPayload(_ completion: @escaping (JSONValue) -> Void) { completion(.string("{}")) }
    func sendToJS(_ message: BridgeMessage) { sentMessages.append(message) }
    func evaluateJavaScript(_ script: String, completion: @escaping (Result<Any?, Error>) -> Void) {
        evaluateJavaScriptCalls += 1
        completion(.success(false))
    }
    func setBridgeMessageDelegate(_ delegate: WebBridgeMessageDelegate?) {}
    func setNavigationDelegate(_ delegate: WebBridgeNavigationDelegate?) {}
    func sendInitDataUpdated(params: [String: JSONValue]) {}
    func retryContentLoadBypassingCache(failedURL: String?, onPurgeOutcome: @escaping (_ didRemoveAnything: Bool) -> Void) {
        cacheBypassRetries += 1
    }
    func releaseRetainedContent() {}
}

private final class TearDownSpy: WebBridgeActionHandler {
    let actions: Set<BridgeMessage.Action> = []
    private(set) var tearDowns = 0

    func handle(_ message: BridgeMessage, host: WebBridgeHost) {}
    func tearDown() { tearDowns += 1 }
}

final class ShowControllerSpy: WebViewAction, WebVCDelegate {
    private(set) var events: [String] = []

    func onInit() { events.append("init") }
    func onCompleted(data: String) { events.append("completed") }
    func onClose() { events.append("close") }
    func onHide() { events.append("hide") }
    func closeTapWebViewVC() { events.append("closeTap") }
    func closeTimeoutWebViewVC() { events.append("closeTimeout") }
    func closeLoadFailedWebViewVC(reason: String) { events.append("closeLoadFailed") }
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
