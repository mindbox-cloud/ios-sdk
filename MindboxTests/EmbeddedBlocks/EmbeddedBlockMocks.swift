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

extension EmbeddedBlockResolutionFailure {

    static let broken = EmbeddedBlockResolutionFailure(inAppId: "broken-inapp-id",
                                                       tags: ["templateType": "Broken"],
                                                       reason: .unknownError,
                                                       details: "In-app broken-inapp-id won place 'block-id' but is not an embedded block")
}

final class InappShowAccountingMock: InappShowAccounting {

    private(set) var shows: [InappShow] = []

    private(set) var cooldowns: [InappFrequency?] = []

    private(set) var places: [String] = []

    private(set) var sessionEpochs: [Int] = []

    var shownIds: [String] { shows.map(\.inAppId) }

    /// Set: every block show goes on to it as well — the real ledger decides what goes out.
    var accountant: InappShowAccounting?

    func recordShow(_ show: InappShow) {
        shows.append(show)
    }

    func recordCooldown(frequency: InappFrequency?) {
        cooldowns.append(frequency)
    }

    func recordBlockShow(_ show: InappShow, at place: String, sessionEpoch: Int) {
        places.append(place)
        shows.append(show)
        sessionEpochs.append(sessionEpoch)
        accountant?.recordBlockShow(show, at: place, sessionEpoch: sessionEpoch)
    }
}

final class InappShowBudgetMock: InappShowBudgeting {

    struct Reservation: Equatable {
        let owner: InappShowBudgetOwner
        let inAppId: String
        let isPriority: Bool
        let frequency: InappFrequency?
    }

    struct Commit: Equatable {
        let owner: InappShowBudgetOwner
        let inAppId: String
        let frequency: InappFrequency?
    }

    var refusedInAppIds: Set<String> = []

    /// `true` — every reservation is answered as one of a session the budget no longer counts.
    var isOfAnEndedSession = false

    /// The session each reserve, commit and release was made in, in call order.
    private(set) var callSessions: [Int?] = []

    /// Run inside `reserve`, `commit` and `release`, before the call is recorded.
    var onReserve: (() -> Void)?
    var onCommit: (() -> Void)?
    var onRelease: (() -> Void)?

    private(set) var reservations: [Reservation] = []
    private(set) var commits: [Commit] = []
    private(set) var releases: [InappShowBudgetOwner] = []
    private(set) var releasedOnMainThread: [Bool] = []
    private(set) var cooldowns: [InappFrequency?] = []

    var reservedOwners: [InappShowBudgetOwner] { reservations.map(\.owner) }

    func reserve(_ owner: InappShowBudgetOwner, inAppId: String, isPriority: Bool, frequency: InappFrequency?, inSession sessionEpoch: Int?) -> InappShowReservationOutcome? {
        onReserve?()
        callSessions.append(sessionEpoch)
        guard !isOfAnEndedSession else { return nil }

        reservations.append(Reservation(owner: owner, inAppId: inAppId, isPriority: isPriority, frequency: frequency))
        return refusedInAppIds.contains(inAppId) ? .refused : .granted
    }

    func commit(_ owner: InappShowBudgetOwner, inAppId: String, frequency: InappFrequency?, inSession sessionEpoch: Int?) {
        onCommit?()
        callSessions.append(sessionEpoch)
        commits.append(Commit(owner: owner, inAppId: inAppId, frequency: frequency))
    }

    func release(_ owner: InappShowBudgetOwner, inSession sessionEpoch: Int?) {
        onRelease?()
        callSessions.append(sessionEpoch)
        releases.append(owner)
        releasedOnMainThread.append(Thread.isMainThread)
    }

    func recordCooldown(frequency: InappFrequency?) {
        cooldowns.append(frequency)
    }
}

final class EmbeddedBlockFailureReporterMock {

    private(set) var reported: [(inAppId: String, reason: InAppShowFailureReason, details: String, tags: [String: String]?)] = []

    var reasons: [InAppShowFailureReason] { reported.map(\.reason) }

    /// Failures with no in-app behind them — the SDK never answered the block — by how long it waited.
    private(set) var unansweredWaits: [TimeInterval] = []

    func report(_ inAppId: String, _ tags: [String: String]?, _ reason: InAppShowFailureReason, _ details: String) {
        reported.append((inAppId, reason, details, tags))
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

    var onShowableQuestion: (([String], @escaping (Result<[String], BridgeErrorCode>) -> Void) -> Void)?

    var onShowInAppRequest: ((String, [String: JSONValue], @escaping (Result<Void, BridgeErrorCode>) -> Void) -> Void)?

    var onDataPushConfirmed: (() -> Void)?

    var onLoadFailure: (() -> Void)?

    var isUserPresent = true

    var loadCount = 0
    var cancelCount = 0

    /// `cancel()` closes the real web layer for good; modelled, or a test about a stopped page would pass either way.
    private(set) var isClosed = false

    fileprivate(set) var responses: [(action: String, payload: JSONValue)] = []
    fileprivate(set) var refusals: [(action: String, error: String)] = []

    var showInAppResponses: [JSONValue] { responses.filter { $0.action == "showInApp" }.map(\.payload) }
    var showInAppRefusals: [String] { refusals.filter { $0.action == "showInApp" }.map(\.error) }
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

    func makeStartPayload(_ completion: @escaping (JSONValue) -> Void) {
        completion(.string("{}"))
    }

    func bridgeDidRenderContent(count: Int) {
        page.onContentRendered?(count)
    }

    func bridgeDidReportUnreadableContent() {
        page.onUnreadableContentReport?()
    }

    func bridgeDidAskShowableInapps(_ ids: [String], completion: @escaping (Result<[String], BridgeErrorCode>) -> Void) {
        page.onShowableQuestion?(ids, completion)
    }

    func bridgeDidRequestShowInApp(id: String,
                                   params: [String: JSONValue],
                                   completion: @escaping (Result<Void, BridgeErrorCode>) -> Void) {
        page.onShowInAppRequest?(id, params, completion)
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

    func endShow() {}

    private(set) var startPayloadRequests = 0

    func makeStartPayload(_ completion: @escaping (JSONValue) -> Void) {
        startPayloadRequests += 1
        completion(.string("{}"))
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

    /// The session every answer is stamped with; starts at the shared ledger's, as a real answer would.
    var sessionEpoch = SessionTemporaryStorage.shared.ledger.sessionEpoch

    /// `true` — the answer does not arrive until the test calls `flush()`: this is how a resolve
    /// that lands after the block was stopped or reloaded is checked.
    var isDeferred = false

    private(set) var resolvedPlaces: [String] = []

    private(set) var triggers: [ApplicationEvent?] = []

    var resolveCount: Int { resolvedPlaces.count }

    private var pending: [(EmbeddedBlockResolution, TimeInterval, Int) -> Void] = []

    init(resolution: EmbeddedBlockResolution = .content(.stub)) {
        self.resolution = resolution
    }

    func resolve(_ place: String,
                 trigger: ApplicationEvent?,
                 completion: @escaping (EmbeddedBlockResolution, TimeInterval, Int) -> Void) {
        resolvedPlaces.append(place)
        triggers.append(trigger)

        if isDeferred {
            pending.append(completion)
        } else {
            completion(resolution, processingDuration, sessionEpoch)
        }
    }

    /// Answers what is in flight with the resolver's current answer and session.
    func flush() {
        let completions = pending
        pending = []
        completions.forEach { $0(resolution, processingDuration, sessionEpoch) }
    }
}

final class InappRequestServiceMock: InappRequestServing {

    var hasConfig = false

    var allowed: [String] = []

    var isDeferred = false

    private(set) var askedIds: [[String]] = []
    private(set) var askedBy: [String] = []
    private(set) var shown: [(id: String, params: [String: JSONValue])] = []
    private(set) var requesterChecks: [() -> Bool] = []

    private var pending: [(Result<[String], BridgeErrorCode>) -> Void] = []
    private var showCompletions: [(Result<Void, BridgeErrorCode>) -> Void] = []

    func showInapp(id: String,
                   params: [String: JSONValue],
                   proceedIf requesterIsActive: @escaping () -> Bool,
                   completion: @escaping (Result<Void, BridgeErrorCode>) -> Void) {
        shown.append((id, params))
        requesterChecks.append(requesterIsActive)
        showCompletions.append(completion)
    }

    func finishShow(_ outcome: Result<Void, BridgeErrorCode>) {
        let completions = showCompletions
        showCompletions = []
        completions.forEach { $0(outcome) }
    }

    func showableInappIds(among ids: [String], askedBy requesterInappId: String, completion: @escaping (Result<[String], BridgeErrorCode>) -> Void) {
        askedIds.append(ids)
        askedBy.append(requesterInappId)

        if isDeferred {
            pending.append(completion)
        } else {
            completion(.success(allowed))
        }
    }

    func flush() {
        let completions = pending
        pending = []
        completions.forEach { $0(.success(allowed)) }
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

/// The process-wide presence built for one rig: its own notification center, app state and monotonic clock,
/// so a rig's background, return and session check reach only it.
final class AppPresenceBed {

    var applicationState: UIApplication.State = .active

    var isSDKInitialized = true

    let clock: TestClock

    let center: NotificationCenter

    private(set) var presence: EmbeddedBlockAppPresence!

    init(center: NotificationCenter = NotificationCenter(), clock: TestClock = TestClock()) {
        self.center = center
        self.clock = clock
        presence = EmbeddedBlockAppPresence(applicationState: { [weak self] in self?.applicationState ?? .active },
                                            isSDKInitialized: { [weak self] in self?.isSDKInitialized ?? true },
                                            now: { clock.now },
                                            notificationCenter: center)
    }

    /// A block stays started, as UIKit leaves it.
    func enterBackground() {
        applicationState = .background
        center.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    /// The session check this return starts has not ended yet.
    func returnToApp() {
        center.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        becomeActive()
    }

    func becomeActive() {
        applicationState = .active
        center.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    /// A check that decided at `startedAt`, now by default; the reset of an expired session comes before it.
    func finishSessionCheck(startedAt: TimeInterval? = nil, startsNewSession: Bool = false) {
        center.post(name: .inappSessionChecked,
                    object: nil,
                    userInfo: [Constants.Notification.sessionCheckStartedAt: startedAt ?? clock.now,
                               Constants.Notification.startsNewSession: startsNewSession])
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

/// A rig with its own notification center and resolver that crosses real sessions: what the bed and the
/// registry's rig share.
protocol EmbeddedBlockSessionRig: AnyObject {

    var center: NotificationCenter { get }

    var resolver: EmbeddedBlockResolverMock { get }
}

extension EmbeddedBlockSessionRig {

    var currentSessionEpoch: Int { SessionTemporaryStorage.shared.ledger.sessionEpoch }

    /// The real reset: the ledger moves on, while the resolver keeps answering in the previous session.
    func expireSession() {
        SessionTemporaryStorage.shared.erase()
    }

    /// A config download concluded in `sessionEpoch`, the session the resolver answers in by default.
    func announceNewConfig(sessionEpoch: Int? = nil) {
        center.post(name: .mobileConfigDownloadConcluded,
                    object: nil,
                    userInfo: [Constants.Notification.sessionEpoch: sessionEpoch ?? resolver.sessionEpoch])
    }

    @discardableResult
    func announceOperation(_ name: String = "custom.operation") -> ApplicationEvent {
        let event = ApplicationEvent(name: name, model: nil)
        center.post(name: .inAppOperationOccurred, object: event)
        return event
    }
}

final class EmbeddedBlockTestBed: EmbeddedBlockSessionRig {

    let resolver: EmbeddedBlockResolverMock
    let inappService: InappRequestServiceMock
    let pageFactory: EmbeddedBlockPageFactoryMock
    let provider: EmbeddedBlockWebViewProvider
    let accounting: InappShowAccountingMock
    let budget = InappShowBudgetMock()
    let failureReporter: EmbeddedBlockFailureReporterMock
    let ackScheduler: EmbeddedBlockAckSchedulerMock

    /// One per bed: a new config must reach only this provider.
    let center: NotificationCenter

    /// One clock for every seam: the page's rendering time (the block's part of `timeToDisplay`), the ack
    /// wait and the presence's return.
    let clock: TestClock

    /// The bed's process-wide presence: every provider of the bed reads the same return.
    let presenceBed: AppPresenceBed

    var applicationState: UIApplication.State {
        get { presenceBed.applicationState }
        set { presenceBed.applicationState = newValue }
    }

    var page: EmbeddedBlockPageMock? { pageFactory.page }

    private let providerAt: (String) -> EmbeddedBlockWebViewProvider

    init(placeSystemName: String = "block-id",
         resolution: EmbeddedBlockResolution = .content(.stub)) {
        // Once-per-session state lives on the shared singleton — reset, or beds would see each other's silence.
        SessionTemporaryStorage.shared.$ledger.mutate { $0.placesReportedUnanswered = [] }

        let clock = TestClock()
        let resolver = EmbeddedBlockResolverMock(resolution: resolution)
        let inappService = InappRequestServiceMock()
        let pageFactory = EmbeddedBlockPageFactoryMock()
        let embeddedPlaces = EmbeddedPlacesStub()
        let center = NotificationCenter()
        let accounting = InappShowAccountingMock()
        let failureReporter = EmbeddedBlockFailureReporterMock()
        let ackScheduler = EmbeddedBlockAckSchedulerMock()
        let presenceBed = AppPresenceBed(center: center, clock: clock)
        let registry = EmbeddedBlockPlaceRegistry(resolver: resolver,
                                                  budget: budget,
                                                  notificationCenter: center,
                                                  fetchEmbeddedPlaces: { embeddedPlaces.fetch($0) },
                                                  presence: presenceBed.presence,
                                                  delayedDelivery: EmbeddedBlockDelayedDelivery(presence: presenceBed.presence),
                                                  now: { clock.now })
        let providerAt = { (place: String) in
            EmbeddedBlockWebViewProvider(placeSystemName: place,
                                         registry: registry,
                                         inappService: inappService,
                                         makePage: { pageFactory.make($0) },
                                         accounting: accounting,
                                         reportFailure: { failureReporter.report($0, $1, $2, $3) },
                                         reportUnansweredWait: { failureReporter.reportUnansweredWait($0) },
                                         scheduleAckTimeout: { ackScheduler.schedule($0, $1) },
                                         makeStopwatch: { ForegroundStopwatch(notificationCenter: center, now: { clock.now }) },
                                         now: { clock.now },
                                         appPresence: presenceBed.presence)
        }

        self.clock = clock
        self.accounting = accounting
        self.ackScheduler = ackScheduler
        self.failureReporter = failureReporter
        self.center = center
        self.resolver = resolver
        self.inappService = inappService
        self.pageFactory = pageFactory
        self.presenceBed = presenceBed
        self.providerAt = providerAt
        self.provider = providerAt(placeSystemName)
    }

    /// Another block of the bed, created now — what a screen built after a return gets.
    func makeProvider(placeSystemName: String) -> EmbeddedBlockWebViewProvider {
        providerAt(placeSystemName)
    }

    /// The session expired and its config download concluded: every answer from here on is the next session's.
    func announceNewSession() {
        expireSession()
        concludeNewSessionDownload()
    }

    func concludeNewSessionDownload() {
        resolver.sessionEpoch = currentSessionEpoch
        announceNewConfig()
    }

    /// A session check found the session expired: the reset asks the places, answered in the new session.
    func renewSession() {
        expireSession()
        resolver.sessionEpoch = currentSessionEpoch
        finishSessionCheck(startsNewSession: true)
    }

    func enterBackground() {
        presenceBed.enterBackground()
    }

    func returnToApp() {
        presenceBed.returnToApp()
    }

    func becomeActive() {
        presenceBed.becomeActive()
    }

    func finishSessionCheck(startedAt: TimeInterval? = nil, startsNewSession: Bool = false) {
        presenceBed.finishSessionCheck(startedAt: startedAt, startsNewSession: startsNewSession)
    }

    /// An answer as the registry hands it over, in the session the resolver answers in.
    func answer(_ resolution: EmbeddedBlockResolution, isOperationTriggered: Bool = false) -> EmbeddedBlockPlaceAnswer {
        EmbeddedBlockPlaceAnswer(resolution: resolution,
                                 processingDuration: 0,
                                 sessionEpoch: resolver.sessionEpoch,
                                 isOperationTriggered: isOperationTriggered,
                                 isAskedOffScreen: false,
                                 isNewSessionAsk: false)
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

}

/// The place's memory across launches, kept in memory: a fixture built over the same mock is the
/// "next launch" of the block.
final class EmbeddedBlockPlaceMemoryMock: EmbeddedBlockPlaceRemembering {

    private(set) var shownPlaces: Set<String>

    private(set) var remembered: [String] = []

    private(set) var forgotten: [String] = []

    /// The places the block asked about — what it was created for, normalized.
    private(set) var askedPlaces: [String] = []

    init(shownPlaces: Set<String> = []) {
        self.shownPlaces = shownPlaces
    }

    func hasShownContent(at place: String) -> Bool {
        askedPlaces.append(place)
        return shownPlaces.contains(place)
    }

    func rememberShownContent(at place: String) {
        shownPlaces.insert(place)
        remembered.append(place)
    }

    func forgetPlace(_ place: String) {
        shownPlaces.remove(place)
        forgotten.append(place)
    }

    private(set) var forgotAllCount = 0

    func forgetAllPlaces() {
        shownPlaces.removeAll()
        forgotAllCount += 1
    }
}

/// The SDK's reveal animation run on the spot: the animations apply at once, the way UIKit sets the
/// model values, and every run is counted — the fade of the content is one run, the growth of a
/// block that waited hidden another.
final class EmbeddedBlockRevealAnimationSpy {

    private(set) var runs: [TimeInterval] = []

    var isReduceMotionEnabled = false

    /// `true` — the completion waits for `finish()`, as it waits for the end of a real animation.
    var isDeferred = false

    /// `true` — the animations block itself waits for `applyAnimations()`: this is how the state
    /// the animation starts from gets seen, before UIKit would set the model values.
    var holdsAnimations = false

    /// `true` while the animations block runs: what happens then is what UIKit would animate.
    private(set) var isApplyingAnimations = false

    private var pendingAnimations: [() -> Void] = []

    private var pendingCompletions: [() -> Void] = []

    var animation: EmbeddedBlockRevealAnimation {
        EmbeddedBlockRevealAnimation(run: { [weak self] duration, animations, completion in
            guard let self else { return }

            self.runs.append(duration)
            if self.holdsAnimations {
                self.pendingAnimations.append(animations)
            } else {
                self.apply(animations)
            }
            if self.isDeferred {
                self.pendingCompletions.append(completion)
            } else {
                completion()
            }
        }, isReduceMotionEnabled: { [weak self] in
            self?.isReduceMotionEnabled ?? false
        })
    }

    func applyAnimations() {
        let animations = pendingAnimations
        pendingAnimations = []
        animations.forEach(apply)
    }

    func finish() {
        let completions = pendingCompletions
        pendingCompletions = []
        completions.forEach { $0() }
    }

    private func apply(_ animations: () -> Void) {
        isApplyingAnimations = true
        animations()
        isApplyingAnimations = false
    }
}

final class EmbeddedBlockAppearanceSpy {

    private(set) var values: [MindboxEmbeddedBlockAppearance] = []

    var last: MindboxEmbeddedBlockAppearance? { values.last }

    var wasAlwaysVisible: Bool { !values.contains(.collapsed) }

    func record(_ appearance: MindboxEmbeddedBlockAppearance) {
        values.append(appearance)
    }
}

final class EmbeddedBlockViewDelegateMock: MindboxEmbeddedBlockViewDelegate {

    enum Event: Equatable {
        case loaded
        case empty
        case failed(MindboxEmbeddedBlockFailReason)
    }

    private(set) var events: [Event] = []

    func mindboxEmbeddedBlockViewDidLoad(_ blockView: MindboxEmbeddedBlockView) {
        events.append(.loaded)
    }

    func mindboxEmbeddedBlockViewDidBecomeEmpty(_ blockView: MindboxEmbeddedBlockView) {
        events.append(.empty)
    }

    func mindboxEmbeddedBlockViewDidFail(_ blockView: MindboxEmbeddedBlockView,
                                         reason: MindboxEmbeddedBlockFailReason) {
        events.append(.failed(reason))
    }
}

extension EmbeddedBlockResolving {

    func resolve(_ place: String, completion: @escaping (EmbeddedBlockResolution, TimeInterval, Int) -> Void) {
        resolve(place, trigger: nil, completion: completion)
    }
}
