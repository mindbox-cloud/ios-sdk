//
//  EmbeddedBlockMocks.swift
//  MindboxTests
//
//  Created by vailence on 06.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit
import WebKit
import MindboxLogger
@_spi(Internal) @testable import Mindbox

extension EmbeddedBlockWebContent {

    /// `unlimited`, the frequency blocks arrive with by contract — so the default block writes no show.
    static let stub = EmbeddedBlockWebContent(inAppId: "block-inapp-id",
                                              baseUrl: "https://inapp.local/stories",
                                              contentUrl: "https://mindbox.ru/block.html",
                                              frequency: .unlimited,
                                              tags: ["templateType": "Embedded"],
                                              params: [:])

    static let other = EmbeddedBlockWebContent(inAppId: "other-inapp-id",
                                               baseUrl: "https://inapp.local/stories",
                                               contentUrl: "https://mindbox.ru/another-block.html",
                                               frequency: .unlimited,
                                               tags: nil,
                                               params: [:])

    static func counted(_ frequency: InappFrequency = .once(OnceFrequency(kind: .lifetime))) -> EmbeddedBlockWebContent {
        EmbeddedBlockWebContent(inAppId: stub.inAppId,
                                baseUrl: stub.baseUrl,
                                contentUrl: stub.contentUrl,
                                frequency: frequency,
                                tags: stub.tags,
                                params: [:])
    }

    static func delayed(_ timeSpan: String = "00:00:05", params: [String: JSONValue] = [:]) -> EmbeddedBlockWebContent {
        EmbeddedBlockWebContent(inAppId: "delayed-inapp-id",
                                baseUrl: stub.baseUrl,
                                contentUrl: stub.contentUrl,
                                frequency: .unlimited,
                                tags: stub.tags,
                                params: params,
                                delayTime: timeSpan)
    }
}

final class InappShowAccountingMock: InappShowAccounting {

    private(set) var shows: [InappShow] = []

    private(set) var cooldowns: [InappFrequency?] = []

    private(set) var places: [String] = []

    var shownIds: [String] { shows.map(\.inAppId) }

    func recordShow(_ show: InappShow) {
        shows.append(show)
    }

    func recordCooldown(frequency: InappFrequency?) {
        cooldowns.append(frequency)
    }

    func recordBlockShow(_ show: InappShow, at place: String) {
        places.append(place)
        shows.append(show)
    }
}

final class EmbeddedBlockFailureReporterMock {

    private(set) var reported: [(inAppId: String, reason: InAppShowFailureReason, details: String, tags: [String: String]?)] = []

    var reasons: [InAppShowFailureReason] { reported.map(\.reason) }

    /// Failures with no in-app behind them — the SDK never answered the block — by how long it waited.
    private(set) var unansweredWaits: [TimeInterval] = []

    func report(_ content: EmbeddedBlockWebContent, _ reason: InAppShowFailureReason, _ details: String) {
        reported.append((content.inAppId, reason, details, content.tags))
    }

    func reportUnansweredWait(_ waited: TimeInterval) {
        unansweredWaits.append(waited)
    }
}

extension BridgeMessage {

    /// The envelope carries the payload as a JSON string — objects built here would skip the parsing the real path does.
    static func pageRequest(_ action: Action, _ payload: [String: JSONValue] = [:]) -> BridgeMessage {
        let json = (try? JSONEncoder().encode(payload)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return BridgeMessage(type: .request, action: action, payload: .string(json))
    }
}

/// A page without WebKit: tests decide what it tells the native side and when.
/// The envelopes a test sends go through the real action handlers — only WebKit is taken out.
final class EmbeddedBlockPageMock: EmbeddedBlockPageHosting {

    let view = UIView()

    var onContentRendered: ((Int) -> Void)?

    var onUnreadableContentReport: (() -> Void)?

    var onShowableQuestion: (([String], @escaping ([String]) -> Void) -> Void)?

    var onShowInAppRequest: ((String, [String: JSONValue]) -> Void)?

    var onDataPushConfirmed: (() -> Void)?

    var onLoadFailure: (() -> Void)?

    var isUserPresent = true

    var loadCount = 0
    var cancelCount = 0

    /// `cancel()` closes the real web layer for good; modelled, or a test about a stopped page would pass either way.
    private(set) var isClosed = false

    fileprivate(set) var responses: [(action: String, payload: JSONValue)] = []
    fileprivate(set) var refusals: [(action: String, error: String)] = []
    private(set) var initDataPushes: [[String: JSONValue]] = []

    private lazy var host = EmbeddedBlockPageMockHost(page: self)
    private lazy var registry = WebBridgeActionRegistry(handlers: [
        ContentRenderedActionHandler(),
        FilterShowableInappsActionHandler(),
        ShowInAppActionHandler()
    ])

    func load() {
        loadCount += 1
    }

    func cancel() {
        cancelCount += 1
        isClosed = true
    }

    func sendInitData(params: [String: JSONValue]) {
        guard !isClosed else { return }

        initDataPushes.append(params)
    }

    func send(_ action: BridgeMessage.Action, _ payload: [String: JSONValue] = [:]) {
        registry.handle(.pageRequest(action, payload), host: host)
    }

    func failLoad() {
        onLoadFailure?()
    }

    func reportRendered(_ count: Int) {
        send(.contentRendered, ["count": .int(count)])
    }

    func reportRenderedWithoutCount() {
        send(.contentRendered)
    }

    /// On the real page the `initDataUpdated` response is caught before the registry; here that seam is the closure itself.
    func confirmInitData() {
        onDataPushConfirmed?()
    }
}

private final class EmbeddedBlockPageMockHost: WebBridgeHost, WebBridgeContentHosting, WebBridgeInappRequestHosting {

    unowned let page: EmbeddedBlockPageMock

    init(page: EmbeddedBlockPageMock) {
        self.page = page
    }

    var contentId: String { "mock-page" }

    var logCategory: LogCategory { .embeddedBlocks }

    var tags: [String: String]? { nil }

    var presentingViewController: UIViewController? { nil }

    var isUserPresent: Bool { page.isUserPresent }

    func send(_ message: BridgeMessage) {
        switch message.type {
        case .response:
            page.responses.append((message.action, message.payload ?? .null))
        case .error:
            let reason: String
            if case .object(let object)? = message.payload, case .string(let text)? = object["error"] {
                reason = text
            } else {
                reason = ""
            }
            page.refusals.append((message.action, reason))
        case .request:
            break
        }
    }

    func makeStartPayload() -> JSONValue {
        .string("{}")
    }

    func bridgeDidRenderContent(count: Int) {
        page.onContentRendered?(count)
    }

    func bridgeDidReportUnreadableContent() {
        page.onUnreadableContentReport?()
    }

    func bridgeDidAskShowableInapps(_ ids: [String], completion: @escaping ([String]) -> Void) {
        page.onShowableQuestion?(ids, completion)
    }

    func bridgeDidRequestShowInApp(id: String, params: [String: JSONValue]) {
        page.onShowInAppRequest?(id, params)
    }
}

/// Not main-actor isolated because the protocol is not; the main-actor tests keep the web view on the main thread.
final class SharedWebLayerMock: InappWebViewFacadeProtocol {

    let webView = WKWebView()

    private(set) var sentMessages: [BridgeMessage] = []
    private(set) var loads: [(baseUrl: String, contentUrl: String)] = []
    private(set) var initDataPushes: [[String: JSONValue]] = []

    private(set) weak var messageDelegate: WebBridgeMessageDelegate?
    private(set) weak var navigationDelegate: WebBridgeNavigationDelegate?

    private var onLoadFailure: (() -> Void)?

    var sentActions: [String] { sentMessages.map(\.action) }

    func makeView() -> UIView {
        webView
    }

    func loadHTML(baseUrl: String, contentUrl: String, onFailure: @escaping () -> Void) {
        loads.append((baseUrl, contentUrl))
        onLoadFailure = onFailure
    }

    func failLoad() {
        onLoadFailure?()
    }

    func applyViewSettings(scrollViewDelegate: UIScrollViewDelegate?) {}

    func cleanWebView() {}

    private(set) var startPayloadRequests = 0

    func makeStartPayload() -> JSONValue {
        startPayloadRequests += 1
        return .string("{}")
    }

    func sendInitDataUpdated(params: [String: JSONValue]) {
        initDataPushes.append(params)
    }

    private(set) var cacheBypassingRetries: [String?] = []

    func retryContentLoadBypassingCache(failedURL: String?, onPurgeOutcome: @escaping (_ didRemoveAnything: Bool) -> Void) {
        cacheBypassingRetries.append(failedURL)
        onPurgeOutcome(true)
    }

    func releaseRetainedContent() {}

    func sendToJS(_ message: BridgeMessage) {
        sentMessages.append(message)
    }

    func evaluateJavaScript(_ script: String, completion: @escaping (Result<Any?, Error>) -> Void) {
        completion(.success(nil))
    }

    func setBridgeMessageDelegate(_ delegate: WebBridgeMessageDelegate?) {
        messageDelegate = delegate
    }

    func setNavigationDelegate(_ delegate: WebBridgeNavigationDelegate?) {
        navigationDelegate = delegate
    }
}

/// Counts how many pages were made and with what content: a reload must make a new one.
final class EmbeddedBlockPageFactoryMock {

    private(set) var pages: [EmbeddedBlockPageMock] = []
    private(set) var contents: [EmbeddedBlockWebContent] = []

    var page: EmbeddedBlockPageMock? { pages.last }

    func make(_ content: EmbeddedBlockWebContent) -> EmbeddedBlockPageHosting {
        contents.append(content)
        let page = EmbeddedBlockPageMock()
        pages.append(page)
        return page
    }
}

final class EmbeddedBlockResolverMock: EmbeddedBlockResolving {

    var resolution: EmbeddedBlockResolution

    var processingDuration: TimeInterval = 0

    /// `true` — the answer does not arrive until the test calls `flush()`: this is how a resolve
    /// that lands after the block was stopped or reloaded is checked.
    var isDeferred = false

    private(set) var resolvedPlaces: [String] = []

    private(set) var triggers: [ApplicationEvent?] = []

    var resolveCount: Int { resolvedPlaces.count }

    private var pending: [(EmbeddedBlockResolution, TimeInterval) -> Void] = []

    init(resolution: EmbeddedBlockResolution = .content(.stub)) {
        self.resolution = resolution
    }

    func resolve(_ place: String,
                 trigger: ApplicationEvent?,
                 completion: @escaping (EmbeddedBlockResolution, TimeInterval) -> Void) {
        resolvedPlaces.append(place)
        triggers.append(trigger)

        if isDeferred {
            pending.append(completion)
        } else {
            completion(resolution, processingDuration)
        }
    }

    func flush() {
        let completions = pending
        pending = []
        completions.forEach { $0(resolution, processingDuration) }
    }
}

final class EmbeddedBlockInappServiceMock: EmbeddedBlockInappServing {

    var hasConfig = false

    var allowed: [String] = []

    var isDeferred = false

    private(set) var askedIds: [[String]] = []
    private(set) var askedBy: [String] = []
    private(set) var shown: [(id: String, params: [String: JSONValue])] = []

    private var pending: [([String]) -> Void] = []

    func showInapp(id: String, params: [String: JSONValue]) {
        shown.append((id, params))
    }

    func showableInappIds(among ids: [String], askedBy blockInappId: String, completion: @escaping ([String]) -> Void) {
        askedIds.append(ids)
        askedBy.append(blockInappId)

        if isDeferred {
            pending.append(completion)
        } else {
            completion(allowed)
        }
    }

    func flush() {
        let completions = pending
        pending = []
        completions.forEach { $0(allowed) }
    }
}

/// A clock that moves only when asked to. Monotonic seconds, matching the timeout's clock seam;
/// a negative `advance` models the backward jump a monotonic clock never makes.
final class TestClock {

    private(set) var now: TimeInterval = 1_000_000

    func advance(_ seconds: TimeInterval) {
        now += seconds
    }
}

/// A scheduler that never fires on its own: "time is up" is declared by the test.
///
/// Thanks to it the waiting budget is checked without a single sleep: both in its own tests and in
/// the tests of the container, which is handed the budget from outside.
final class TestScheduler {

    /// The delay of the last arm — which is the remainder of the budget given to the countdown.
    private(set) var lastDelay: TimeInterval?

    private(set) var armCount = 0

    private var pending: [DispatchWorkItem] = []

    func schedule(_ delay: TimeInterval, _ work: DispatchWorkItem) {
        lastDelay = delay
        armCount += 1
        pending.append(work)
    }

    /// Performs the armed work, skipping what was cancelled: `pause()` and `reset()` cancel it
    /// exactly the way they would cancel work on a real queue.
    func fireAll() {
        let scheduled = pending
        pending = []
        scheduled.forEach { work in
            guard !work.isCancelled else { return }

            work.perform()
        }
    }
}

/// The waiting budget with a substituted clock, scheduler and notification center — everything
/// that makes it different from the real one, gathered in one place.
final class EmbeddedBlockWaitBudgetBed {

    let duration: TimeInterval

    let clock: TestClock
    let scheduler: TestScheduler

    /// One per bed: the background and the return from it must reach only this budget.
    let center: NotificationCenter

    let budget: EmbeddedBlockWaitBudget

    init(placeSystemName: String = "block-id", duration: TimeInterval = 5) {
        self.duration = duration
        let clock = TestClock()
        let scheduler = TestScheduler()
        let center = NotificationCenter()
        self.clock = clock
        self.scheduler = scheduler
        self.center = center
        budget = EmbeddedBlockWaitBudget(placeSystemName: placeSystemName,
                                            duration: { duration },
                                            now: { clock.now },
                                            notificationCenter: center,
                                            schedule: { scheduler.schedule($0, $1) })
    }

    func enterBackground() {
        center.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    func enterForeground() {
        center.post(name: UIApplication.willEnterForegroundNotification, object: nil)
    }
}

final class EmbeddedPlacesStub {
    /// `nil` — no config seen (gate open); a place maps to the operations its in-apps listen to, an empty set wakes nothing.
    var places: [String: Set<String>]?

    var isDeferred = false

    private var pending: [([String: Set<String>]?) -> Void] = []

    func fetch(_ completion: @escaping ([String: Set<String>]?) -> Void) {
        if isDeferred {
            pending.append(completion)
        } else {
            completion(places)
        }
    }

    func flush() {
        let completions = pending
        pending = []
        completions.forEach { $0(places) }
    }
}

final class EmbeddedBlockAckSchedulerMock {

    private(set) var scheduled: [(delay: TimeInterval, work: DispatchWorkItem)] = []

    func schedule(_ delay: TimeInterval, _ work: DispatchWorkItem) {
        scheduled.append((delay, work))
    }

    func fire() {
        guard let last = scheduled.last, !last.work.isCancelled else { return }

        last.work.perform()
    }
}

/// The provider with all dependencies substituted — the shared rig for the provider and container
/// tests. The container runs through a real provider, the provider through a real place registry.
final class EmbeddedBlockContentProviderFactoryMock: EmbeddedBlockContentProviderMaking {

    private(set) var requestedPlaces: [String] = []

    private let provider: EmbeddedBlockWebViewProvider

    init(provider: EmbeddedBlockWebViewProvider) {
        self.provider = provider
    }

    func makeProvider(placeSystemName: String) -> EmbeddedBlockWebViewProvider {
        requestedPlaces.append(placeSystemName)
        return provider
    }
}

final class EmbeddedBlockTestBed {

    let resolver: EmbeddedBlockResolverMock
    let inappService: EmbeddedBlockInappServiceMock
    let pageFactory: EmbeddedBlockPageFactoryMock
    let provider: EmbeddedBlockWebViewProvider
    let accounting: InappShowAccountingMock
    let failureReporter: EmbeddedBlockFailureReporterMock
    let ackScheduler: EmbeddedBlockAckSchedulerMock

    /// One per bed: a new config must reach only this provider.
    let center: NotificationCenter

    var page: EmbeddedBlockPageMock? { pageFactory.page }

    init(placeSystemName: String = "block-id",
         resolution: EmbeddedBlockResolution = .content(.stub)) {
        // Once-per-session state lives on the shared singleton — reset, or beds would see each other's silence.
        SessionTemporaryStorage.shared.$ledger.mutate { $0.placesReportedUnanswered = [] }

        let resolver = EmbeddedBlockResolverMock(resolution: resolution)
        let inappService = EmbeddedBlockInappServiceMock()
        let pageFactory = EmbeddedBlockPageFactoryMock()
        let embeddedPlaces = EmbeddedPlacesStub()
        let center = NotificationCenter()
        let accounting = InappShowAccountingMock()
        let failureReporter = EmbeddedBlockFailureReporterMock()
        let ackScheduler = EmbeddedBlockAckSchedulerMock()
        let registry = EmbeddedBlockPlaceRegistry(resolver: resolver,
                                                  notificationCenter: center,
                                                  fetchEmbeddedPlaces: { embeddedPlaces.fetch($0) })

        self.accounting = accounting
        self.ackScheduler = ackScheduler
        self.failureReporter = failureReporter
        self.center = center
        self.resolver = resolver
        self.inappService = inappService
        self.pageFactory = pageFactory
        self.provider = EmbeddedBlockWebViewProvider(placeSystemName: placeSystemName,
                                                     registry: registry,
                                                     inappService: inappService,
                                                     makePage: { pageFactory.make($0) },
                                                     accounting: accounting,
                                                     reportFailure: { failureReporter.report($0, $1, $2) },
                                                     reportUnansweredWait: { failureReporter.reportUnansweredWait($0) },
                                                     scheduleAckTimeout: { ackScheduler.schedule($0, $1) })
    }

    func announceNewConfig() {
        center.post(name: .mobileConfigDownloaded, object: nil)
    }

    func deliverSamePageWithNewData(_ marker: String = "fresh") {
        let fresh = EmbeddedBlockWebContent(inAppId: EmbeddedBlockWebContent.stub.inAppId,
                                            baseUrl: EmbeddedBlockWebContent.stub.baseUrl,
                                            contentUrl: EmbeddedBlockWebContent.stub.contentUrl,
                                            frequency: EmbeddedBlockWebContent.stub.frequency,
                                            tags: EmbeddedBlockWebContent.stub.tags,
                                            params: [marker: .bool(true)])
        resolver.resolution = .content(fresh)
        announceNewConfig()
    }

    func announceOperation(_ name: String = "custom.operation") -> ApplicationEvent {
        let event = ApplicationEvent(name: name, model: nil)
        center.post(name: .inAppOperationOccurred, object: event)
        return event
    }
}

final class EmbeddedBlockViewDelegateMock: MindboxEmbeddedBlockViewDelegate {

    enum Event: Equatable {
        case loaded
        case failed
    }

    private(set) var events: [Event] = []

    func mindboxEmbeddedBlockViewDidLoad(_ blockView: MindboxEmbeddedBlockView) {
        events.append(.loaded)
    }

    func mindboxEmbeddedBlockViewDidFail(_ blockView: MindboxEmbeddedBlockView) {
        events.append(.failed)
    }
}

extension EmbeddedBlockResolving {

    func resolve(_ place: String, completion: @escaping (EmbeddedBlockResolution, TimeInterval) -> Void) {
        resolve(place, trigger: nil, completion: completion)
    }
}
