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

    /// The same page under a frequency whose shows are counted.
    static func counted(_ frequency: InappFrequency = .once(OnceFrequency(kind: .lifetime))) -> EmbeddedBlockWebContent {
        EmbeddedBlockWebContent(inAppId: stub.inAppId,
                                baseUrl: stub.baseUrl,
                                contentUrl: stub.contentUrl,
                                frequency: frequency,
                                tags: stub.tags,
                                params: [:])
    }
}

/// Where a block's shows are written down in tests.
final class EmbeddedBlockShowRecorderMock {

    private(set) var recorded: [String] = []

    func record(_ inAppId: String) {
        recorded.append(inAppId)
    }
}

/// Where a block's show event goes in tests. Apart from the recorder above: the backend hears about
/// every show, the history is written only for the frequencies that count them.
final class EmbeddedBlockShowReporterMock {

    private(set) var reported: [(inAppId: String, timeToDisplay: String, tags: [String: String]?)] = []

    var inAppIds: [String] { reported.map(\.inAppId) }

    func report(_ content: EmbeddedBlockWebContent, _ timeToDisplay: String) {
        reported.append((content.inAppId, timeToDisplay, content.tags))
    }
}

/// Where a block's failures are reported in tests.
final class EmbeddedBlockFailureReporterMock {

    private(set) var reported: [(inAppId: String, reason: InAppShowFailureReason, details: String, tags: [String: String]?)] = []

    var reasons: [InAppShowFailureReason] { reported.map(\.reason) }

    func report(_ content: EmbeddedBlockWebContent, _ reason: InAppShowFailureReason, _ details: String) {
        reported.append((content.inAppId, reason, details, content.tags))
    }
}

extension BridgeMessage {

    /// A request the way a page sends one: the envelope carries the payload as a JSON string, so
    /// tests that build objects here would not exercise the parsing the real path goes through.
    static func pageRequest(_ action: Action, _ payload: [String: JSONValue] = [:]) -> BridgeMessage {
        let json = (try? JSONEncoder().encode(payload)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return BridgeMessage(type: .request, action: action, payload: .string(json))
    }
}

/// A page without WebKit: tests decide what it tells the native side and when.
///
/// The envelopes a test sends go through the real action handlers, exactly as the real page's
/// registry dispatches them — so the provider tests keep exercising the parsing and the answers
/// the production path has, with only WebKit taken out.
final class EmbeddedBlockPageMock: EmbeddedBlockPageHosting {

    let view = UIView()

    var onContentRendered: ((Int) -> Void)?

    var onUnreadableContentReport: (() -> Void)?

    var onFeedQuestion: (([String], @escaping ([String]) -> Void) -> Void)?

    var onShowInAppRequest: ((String, [String: JSONValue]) -> Void)?

    var onDataPushConfirmed: (() -> Void)?

    var onLoadFailure: (() -> Void)?

    var isUserPresent = true

    var loadCount = 0
    var cancelCount = 0

    /// `cancel()` closes the real page's web layer for good — the facade drops everything it is asked
    /// to send afterwards. Modelled here, or a test about a stopped page would pass either way.
    private(set) var isClosed = false

    fileprivate(set) var responses: [(action: String, payload: JSONValue)] = []
    fileprivate(set) var refusals: [(action: String, error: String)] = []
    private(set) var initDataPushes: [[String: JSONValue]] = []

    private lazy var host = EmbeddedBlockPageMockHost(page: self)
    private lazy var registry = WebBridgeActionRegistry(handlers: [
        ContentRenderedActionHandler(),
        CheckInappsTargetingActionHandler(),
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

    /// The page reporting how many items it drew — its only statement about itself, and the one the
    /// container turns into a state.
    func reportRendered(_ count: Int) {
        send(.contentRendered, ["count": .int(count)])
    }

    /// A report whose count cannot be read. Not "nothing to show": nobody can say what is on screen.
    func reportRenderedWithoutCount() {
        send(.contentRendered)
    }

    /// The page answering the `initDataUpdated` it was pushed. On the real page the response is
    /// caught before the registry; here that seam is the closure itself.
    func confirmInitData() {
        onDataPushConfirmed?()
    }
}

/// The host the mock's registry dispatches into: capability calls come back as the mock's
/// closures, answers are recorded instead of sent to JS.
private final class EmbeddedBlockPageMockHost: WebBridgeHost, WebBridgeContentHosting, WebBridgeFeedHosting {

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

    func bridgeDidAskRenderableInapps(_ ids: [String], completion: @escaping ([String]) -> Void) {
        page.onFeedQuestion?(ids, completion)
    }

    func bridgeDidRequestShowInApp(id: String, params: [String: JSONValue]) {
        page.onShowInAppRequest?(id, params)
    }
}

/// The shared web layer without WebKit doing any work: the web view exists (the page configures it
/// and the bridge needs one), but nothing loads, and every message the page sends is recorded.
///
/// Not main-actor isolated, because the protocol it stands in for is not either — the block tests
/// that drive it are, which is what keeps the web view on the main thread.
final class SharedWebLayerMock: InappWebViewFacadeProtocol {

    let webView = WKWebView()

    private(set) var sentMessages: [BridgeMessage] = []
    private(set) var readyAnswers: [UUID] = []
    private(set) var loads: [(baseUrl: String, contentUrl: String)] = []
    private(set) var initDataPushes: [[String: JSONValue]] = []

    private(set) weak var messageDelegate: WebBridgeMessageDelegate?
    private(set) weak var navigationDelegate: WebBridgeNavigationDelegate?

    /// Fired instead of a network failure, so a test can fail a load without a server.
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

    /// How many times the page asked for the start payload — one per `ready` answered.
    private(set) var startPayloadRequests = 0

    func makeStartPayload() -> JSONValue {
        startPayloadRequests += 1
        return .string("{}")
    }

    /// Implemented rather than left to the protocol's default, so the test sees the push instead of the
    /// no-op the default would quietly provide.
    func sendInitDataUpdated(params: [String: JSONValue]) {
        initDataPushes.append(params)
    }

    private(set) var cacheBypassingRetries: [String?] = []

    /// Same reason as above: the default is a silent no-op, and these tests are about the call being made.
    func retryContentLoadBypassingCache(failedURL: String?, onPurgeOutcome: @escaping (_ didRemoveAnything: Bool) -> Void) {
        cacheBypassingRetries.append(failedURL)
        onPurgeOutcome(true)
    }

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

    /// `true` — the answer does not arrive until the test calls `flush()`: this is how a resolve
    /// that lands after the block was stopped or reloaded is checked.
    var isDeferred = false

    private(set) var resolvedPlaces: [String] = []

    /// The operation each resolve carried — `nil` for a resolve nobody's operation stands behind.
    private(set) var triggers: [ApplicationEvent?] = []

    var resolveCount: Int { resolvedPlaces.count }

    private var pending: [(EmbeddedBlockResolution) -> Void] = []

    init(resolution: EmbeddedBlockResolution = .content(.stub)) {
        self.resolution = resolution
    }

    func resolve(_ place: String,
                 trigger: ApplicationEvent?,
                 completion: @escaping (EmbeddedBlockResolution) -> Void) {
        resolvedPlaces.append(place)
        triggers.append(trigger)

        if isDeferred {
            pending.append(completion)
        } else {
            completion(resolution)
        }
    }

    func flush() {
        let completions = pending
        pending = []
        completions.forEach { $0(resolution) }
    }
}

/// The feed's questions answered by the test instead of by the selection.
final class EmbeddedBlockFeedServiceMock: EmbeddedBlockFeedServing {

    var allowed: [String] = []

    /// `true` — the answer waits for `flush()`: this is how an answer that lands after the block was
    /// stopped or reloaded is checked.
    var isDeferred = false

    private(set) var askedIds: [[String]] = []
    private(set) var shown: [(id: String, params: [String: JSONValue])] = []

    private var pending: [(FeedAnswer) -> Void] = []

    /// How many times the answer was vouched for — one round of `Inapp.Targeting` per call.
    private(set) var vouchCount = 0

    func showInapp(id: String, params: [String: JSONValue]) {
        shown.append((id, params))
    }

    func renderableInappIds(among ids: [String], completion: @escaping (FeedAnswer) -> Void) {
        askedIds.append(ids)

        if isDeferred {
            pending.append(completion)
        } else {
            completion(answer)
        }
    }

    func flush() {
        let completions = pending
        pending = []
        completions.forEach { $0(answer) }
    }

    private var answer: FeedAnswer {
        FeedAnswer(inappIds: allowed) { [weak self] in
            self?.vouchCount += 1
        }
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

    private var pending: [DispatchWorkItem] = []

    func schedule(_ delay: TimeInterval, _ work: DispatchWorkItem) {
        lastDelay = delay
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

    /// The budget the bed was built with — tests compare the armed delay against this rather than
    /// against a literal that lives in another file.
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

/// The set of embedded places "the config" addresses, readable at fetch time — how a test steers
/// the registry's operation gate.
final class EmbeddedPlacesStub {
    /// `nil` — no config seen: the gate stays open. A place maps to the operations its in-apps
    /// listen to — an empty set means "in the config, but no operation wakes it".
    var places: [String: Set<String>]?

    /// `true` — the fetch does not answer until `flush()`. The real fetch hops to the config manager's
    /// queue, so there is a window where the registry has asked and not yet heard back.
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

/// Where the provider's ACK waits land in tests, fired by hand instead of by the clock.
final class EmbeddedBlockAckSchedulerMock {

    private(set) var scheduled: [(delay: TimeInterval, work: DispatchWorkItem)] = []

    var pendingCount: Int { scheduled.filter { !$0.work.isCancelled }.count }

    func schedule(_ delay: TimeInterval, _ work: DispatchWorkItem) {
        scheduled.append((delay, work))
    }

    /// Runs the latest wait the way the clock would — a cancelled one stays cancelled.
    func fire() {
        guard let last = scheduled.last, !last.work.isCancelled else { return }

        last.work.perform()
    }
}

/// The provider with all dependencies substituted — the shared rig for the provider and container
/// tests. The container is tested through a real provider — and the provider through a real place
/// registry: the seams inside the block are the page and the resolver, and there is nothing else
/// to substitute.
final class EmbeddedBlockTestBed {

    let resolver: EmbeddedBlockResolverMock
    let feed: EmbeddedBlockFeedServiceMock
    let pageFactory: EmbeddedBlockPageFactoryMock
    let registry: EmbeddedBlockPlaceRegistry
    let provider: EmbeddedBlockWebViewProvider
    let showRecorder: EmbeddedBlockShowRecorderMock
    let showReporter: EmbeddedBlockShowReporterMock
    let failureReporter: EmbeddedBlockFailureReporterMock
    let ackScheduler: EmbeddedBlockAckSchedulerMock

    /// One per bed: a new config must reach only this provider.
    let center: NotificationCenter

    /// What the registry's operation gate sees after the next config announcement.
    let embeddedPlaces: EmbeddedPlacesStub

    var page: EmbeddedBlockPageMock? { pageFactory.page }

    init(placeSystemName: String = "block-id",
         resolution: EmbeddedBlockResolution = .content(.stub)) {
        // The show-event dedup lives on the shared session singleton — each bed starts its own
        // "session" or the show tests would see each other's reports.
        SessionTemporaryStorage.shared.blockShowsReportedInSession = []

        let resolver = EmbeddedBlockResolverMock(resolution: resolution)
        let feed = EmbeddedBlockFeedServiceMock()
        let pageFactory = EmbeddedBlockPageFactoryMock()
        let embeddedPlaces = EmbeddedPlacesStub()
        let center = NotificationCenter()
        let showRecorder = EmbeddedBlockShowRecorderMock()
        let showReporter = EmbeddedBlockShowReporterMock()
        let failureReporter = EmbeddedBlockFailureReporterMock()
        let ackScheduler = EmbeddedBlockAckSchedulerMock()
        let registry = EmbeddedBlockPlaceRegistry(resolver: resolver,
                                                  notificationCenter: center,
                                                  fetchEmbeddedPlaces: { embeddedPlaces.fetch($0) })

        self.showRecorder = showRecorder
        self.showReporter = showReporter
        self.ackScheduler = ackScheduler
        self.failureReporter = failureReporter
        self.embeddedPlaces = embeddedPlaces
        self.center = center
        self.resolver = resolver
        self.feed = feed
        self.pageFactory = pageFactory
        self.registry = registry
        self.provider = EmbeddedBlockWebViewProvider(placeSystemName: placeSystemName,
                                                     registry: registry,
                                                     feed: feed,
                                                     makePage: { pageFactory.make($0) },
                                                     recordShow: { showRecorder.record($0) },
                                                     reportShow: { showReporter.report($0, $1) },
                                                     reportFailure: { failureReporter.report($0, $1, $2) },
                                                     scheduleAckTimeout: { ackScheduler.schedule($0, $1) })
    }

    /// A new mobile config landed. Posted synchronously on the main queue, which is where the
    /// registry observes.
    func announceNewConfig() {
        center.post(name: .mobileConfigDownloaded, object: nil)
    }

    /// The place resolving to the same page with new params — what a config edit that only touches
    /// the catalog looks like to the provider.
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

    /// An operation the pipeline agreed to handle — the push side of the block.
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
