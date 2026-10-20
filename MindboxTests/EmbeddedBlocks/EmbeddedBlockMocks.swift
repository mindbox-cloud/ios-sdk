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

    private(set) var recordedOnMainThread: [Bool] = []

    var shownIds: [String] { shows.map(\.inAppId) }

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
        recordedOnMainThread.append(Thread.isMainThread)
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

    var isOfAnEndedSession = false

    private(set) var callSessions: [Int?] = []

    private(set) var reservations: [Reservation] = []
    private(set) var commits: [Commit] = []
    private(set) var releases: [InappShowBudgetOwner] = []
    private(set) var releasedOnMainThread: [Bool] = []
    private(set) var cooldowns: [InappFrequency?] = []

    var reservedOwners: [InappShowBudgetOwner] { reservations.map(\.owner) }

    func reserve(_ owner: InappShowBudgetOwner, inAppId: String, isPriority: Bool, frequency: InappFrequency?, inSession sessionEpoch: Int?) -> InappShowReservationOutcome? {
        callSessions.append(sessionEpoch)
        guard !isOfAnEndedSession else { return nil }

        reservations.append(Reservation(owner: owner, inAppId: inAppId, isPriority: isPriority, frequency: frequency))
        return refusedInAppIds.contains(inAppId) ? .refused : .granted
    }

    func commit(_ owner: InappShowBudgetOwner, inAppId: String, frequency: InappFrequency?, inSession sessionEpoch: Int?, to ledger: inout InappSessionLedger) {
        callSessions.append(sessionEpoch)
        commits.append(Commit(owner: owner, inAppId: inAppId, frequency: frequency))
    }

    func release(_ owner: InappShowBudgetOwner, inSession sessionEpoch: Int?, from ledger: inout InappSessionLedger) {
        callSessions.append(sessionEpoch)
        releases.append(owner)
        releasedOnMainThread.append(Thread.isMainThread)
    }

    func recordCooldown(frequency: InappFrequency?) {
        cooldowns.append(frequency)
    }

    func saveShowHistory() {}
}

final class EmbeddedBlockFailureReporterMock {

    private(set) var reported: [(inAppId: String, reason: InAppShowFailureReason, details: String, tags: [String: String]?)] = []

    var reasons: [InAppShowFailureReason] { reported.map(\.reason) }

    private(set) var unansweredWaits: [TimeInterval] = []

    func report(_ inAppId: String, _ tags: [String: String]?, _ reason: InAppShowFailureReason, _ details: String) {
        reported.append((inAppId, reason, details, tags))
    }

    func reportUnansweredWait(_ waited: TimeInterval) {
        unansweredWaits.append(waited)
    }
}

extension BridgeMessage {

    static func pageRequest(_ action: Action, _ payload: [String: JSONValue] = [:]) -> BridgeMessage {
        let json = (try? JSONEncoder().encode(payload)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return BridgeMessage(type: .request, action: action, payload: .string(json))
    }
}

final class EmbeddedBlockPageMock: EmbeddedBlockPageHosting {

    let view = UIView()

    var onContentRendered: ((Int) -> Void)?

    var onUnreadableContentReport: (() -> Void)?

    var onShowableQuestion: (([String], @escaping ([String]) -> Void) -> Void)?

    var onShowInAppRequest: ((String, [String: JSONValue], @escaping (Result<Void, BridgeErrorCode>) -> Void) -> Void)?

    var onDataPushConfirmed: (() -> Void)?

    var onLoadFailure: ((String) -> Void)?

    var isUserPresent = true

    var loadCount = 0
    var cancelCount = 0

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
        onLoadFailure?("Failed to fetch page HTML")
    }

    func reportRendered(_ count: Int) {
        send(.contentRendered, ["count": .int(count)])
    }

    func reportRenderedWithoutCount() {
        send(.contentRendered)
    }

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

    func bridgeDidAskShowableInapps(_ ids: [String], completion: @escaping ([String]) -> Void) {
        page.onShowableQuestion?(ids, completion)
    }

    func bridgeDidRequestShowInApp(id: String,
                                   params: [String: JSONValue],
                                   completion: @escaping (Result<Void, BridgeErrorCode>) -> Void) {
        page.onShowInAppRequest?(id, params, completion)
    }
}

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

    private(set) var endedShows = 0

    func endShow() {
        endedShows += 1
    }

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

    private(set) var retainedContentReleases = 0

    func releaseRetainedContent() {
        retainedContentReleases += 1
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

    var sessionEpoch = SessionTemporaryStorage.shared.ledger.sessionEpoch

    private(set) var configVersion = ConfigVersion(number: 1)

    private(set) var configPublishedInSession = SessionTemporaryStorage.shared.ledger.sessionEpoch

    var readsNoConfig = false

    var isDeferred = false

    private(set) var resolvedPlaces: [String] = []

    private(set) var triggers: [ApplicationEvent?] = []

    private(set) var resolvedOnMainThread: [Bool] = []

    var resolveCount: Int { resolvedPlaces.count }

    private var pending: [(configVersion: ConfigVersion?, completion: (EmbeddedBlockResolution, TimeInterval, Int, ConfigVersion?) -> Void)] = []

    init(resolution: EmbeddedBlockResolution = .content(.stub)) {
        self.resolution = resolution
    }

    func resolve(_ place: String,
                 trigger: ApplicationEvent?,
                 completion: @escaping (EmbeddedBlockResolution, TimeInterval, Int, ConfigVersion?) -> Void) {
        resolvedPlaces.append(place)
        triggers.append(trigger)
        resolvedOnMainThread.append(Thread.isMainThread)
        let configRead = readsNoConfig ? nil : configVersion

        if isDeferred {
            pending.append((configRead, completion))
        } else {
            completion(resolution, processingDuration, sessionEpoch, configRead)
        }
    }

    @discardableResult
    func publishConfig() -> ConfigVersion {
        configVersion = configVersion.next
        configPublishedInSession = SessionTemporaryStorage.shared.ledger.sessionEpoch
        return configVersion
    }

    func flush() {
        answerPending { $0 }
    }

    func flush(readingConfig version: ConfigVersion) {
        answerPending { $0.map { max($0, version) } }
    }

    private func answerPending(reading configRead: (ConfigVersion?) -> ConfigVersion?) {
        let answered = pending
        pending = []
        answered.forEach { $0.completion(resolution, processingDuration, sessionEpoch, configRead($0.configVersion)) }
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

    private var pending: [([String]) -> Void] = []
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

    func showableInappIds(among ids: [String], askedBy requesterInappId: String, completion: @escaping ([String]) -> Void) {
        askedIds.append(ids)
        askedBy.append(requesterInappId)

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

final class InAppConfigurationManagerStub: InAppConfigurationManagerProtocol {
    weak var delegate: InAppConfigurationDelegate?
    var hasConfig = false

    func prepareConfiguration() {}
    func handleInapps(event: ApplicationEvent?, _ completion: @escaping (InAppFormData?) -> Void) {
        completion(nil)
    }
    func selectInappForPlace(_ place: String,
                             trigger: ApplicationEvent?,
                             _ completion: @escaping (EmbeddedPlaceSelection, TimeInterval, Int, ConfigVersion?) -> Void) {
        completion(.decided(nil), 0, 0, nil)
    }
    func getShowableInappIds(_ ids: [String], askedBy requesterInappId: String, _ completion: @escaping ([String]) -> Void) {
        completion([])
    }
    func getInAppToShowById(_ id: String, params: [String: JSONValue], _ completion: @escaping (InAppFormData?) -> Void) {
        completion(nil)
    }
    func getEmbeddedPlaces(_ completion: @escaping ([String: Set<String>]?) -> Void) {
        completion(nil)
    }
    func resetInappManager() {}
    func inappInCurrentConfig(withId id: String) -> InApp? { nil }
}

final class TestClock {

    private(set) var now: TimeInterval = 1_000_000

    func advance(_ seconds: TimeInterval) {
        now += seconds
    }
}

final class TestScheduler {

    private(set) var lastDelay: TimeInterval?

    private(set) var armCount = 0

    private var pending: [DispatchWorkItem] = []

    func schedule(_ delay: TimeInterval, _ work: DispatchWorkItem) {
        lastDelay = delay
        armCount += 1
        pending.append(work)
    }

    func fireAll() {
        let scheduled = pending
        pending = []
        scheduled.forEach { work in
            guard !work.isCancelled else { return }

            work.perform()
        }
    }
}

final class EmbeddedBlockWaitBudgetBed {

    let duration: TimeInterval

    let clock: TestClock
    let scheduler: TestScheduler

    let center: NotificationCenter

    let presenceBed: AppPresenceBed

    let budget: EmbeddedBlockWaitBudget

    init(placeSystemName: String = "block-id", duration: TimeInterval = 5, applicationState: UIApplication.State = .active) {
        self.duration = duration
        let clock = TestClock()
        let scheduler = TestScheduler()
        let center = NotificationCenter()
        let presenceBed = AppPresenceBed(center: center, clock: clock, applicationState: applicationState)
        self.clock = clock
        self.scheduler = scheduler
        self.center = center
        self.presenceBed = presenceBed
        budget = Self.makeBudget(placeSystemName: placeSystemName, duration: duration, clock: clock, scheduler: scheduler, presence: presenceBed.presence)
    }

    func makeBudget(placeSystemName: String = "block-id") -> EmbeddedBlockWaitBudget {
        Self.makeBudget(placeSystemName: placeSystemName, duration: duration, clock: clock, scheduler: scheduler, presence: presenceBed.presence)
    }

    private static func makeBudget(placeSystemName: String,
                                   duration: TimeInterval,
                                   clock: TestClock,
                                   scheduler: TestScheduler,
                                   presence: EmbeddedBlockAppPresence) -> EmbeddedBlockWaitBudget {
        EmbeddedBlockWaitBudget(placeSystemName: placeSystemName,
                                duration: { duration },
                                now: { clock.now },
                                presence: presence,
                                schedule: { scheduler.schedule($0, $1) })
    }

    func enterBackground() {
        center.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    func enterForeground() {
        center.post(name: UIApplication.willEnterForegroundNotification, object: nil)
    }
}

final class AppPresenceBed {

    var applicationState: UIApplication.State

    var isSDKInitialized = true

    let clock: TestClock

    let center: NotificationCenter

    private(set) var presence: EmbeddedBlockAppPresence!

    init(center: NotificationCenter = NotificationCenter(), clock: TestClock = TestClock(), applicationState: UIApplication.State = .active) {
        self.center = center
        self.clock = clock
        self.applicationState = applicationState
        presence = EmbeddedBlockAppPresence(applicationState: { [weak self] in self?.applicationState ?? .active },
                                            isSDKInitialized: { [weak self] in self?.isSDKInitialized ?? true },
                                            now: { clock.now },
                                            notificationCenter: center)
    }

    func enterBackground() {
        applicationState = .background
        center.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    func returnToApp() {
        center.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        becomeActive()
    }

    func enterForegroundAtLaunch() {
        applicationState = .inactive
        center.post(name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    func returnToAppWithNoSessionCheck() {
        let wasInitialized = isSDKInitialized
        isSDKInitialized = false
        returnToApp()
        isSDKInitialized = wasInitialized
    }

    func becomeActive() {
        applicationState = .active
        center.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    func finishSessionCheck(startedAt: TimeInterval? = nil, startsNewSession: Bool = false) {
        center.post(name: .inappSessionChecked,
                    object: nil,
                    userInfo: [Constants.Notification.sessionCheckStartedAt: startedAt ?? clock.now,
                               Constants.Notification.startsNewSession: startsNewSession])
    }
}

final class EmbeddedPlacesStub {
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

protocol EmbeddedBlockSessionRig: AnyObject {

    var center: NotificationCenter { get }

    var resolver: EmbeddedBlockResolverMock { get }
}

extension EmbeddedBlockSessionRig {

    var currentSessionEpoch: Int { SessionTemporaryStorage.shared.ledger.sessionEpoch }

    func expireSession() {
        SessionTemporaryStorage.shared.erase()
    }

    func announceNewConfig() {
        announceConfig(resolver.publishConfig())
    }

    func announceConfig(_ version: ConfigVersion) {
        center.post(name: .mobileConfigDownloadConcluded,
                    object: nil,
                    userInfo: [Constants.Notification.configVersion: version])
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
    let delayScheduler: TestScheduler

    let center: NotificationCenter

    let clock: TestClock

    let presenceBed: AppPresenceBed

    var applicationState: UIApplication.State {
        get { presenceBed.applicationState }
        set { presenceBed.applicationState = newValue }
    }

    var page: EmbeddedBlockPageMock? { pageFactory.page }

    private let providerAt: (String) -> EmbeddedBlockWebViewProvider

    init(placeSystemName: String = "block-id",
         resolution: EmbeddedBlockResolution = .content(.stub),
         applicationState: UIApplication.State = .active) {
        SessionTemporaryStorage.shared.$ledger.mutate {
            $0.placesReportedUnanswered = []
            $0.servedPlaceDelays = []
            $0.placeShownInappId = [:]
        }

        let clock = TestClock()
        let resolver = EmbeddedBlockResolverMock(resolution: resolution)
        let inappService = InappRequestServiceMock()
        let pageFactory = EmbeddedBlockPageFactoryMock()
        let embeddedPlaces = EmbeddedPlacesStub()
        let center = NotificationCenter()
        let accounting = InappShowAccountingMock()
        let failureReporter = EmbeddedBlockFailureReporterMock()
        let ackScheduler = EmbeddedBlockAckSchedulerMock()
        let delayScheduler = TestScheduler()
        let presenceBed = AppPresenceBed(center: center, clock: clock, applicationState: applicationState)
        let registry = EmbeddedBlockPlaceRegistry(resolver: resolver,
                                                  budget: budget,
                                                  notificationCenter: center,
                                                  fetchEmbeddedPlaces: { embeddedPlaces.fetch($0) },
                                                  presence: presenceBed.presence,
                                                  delayedDelivery: EmbeddedBlockDelayedDelivery(presence: presenceBed.presence,
                                                                                                schedule: { delayScheduler.schedule($0, $1) }),
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
                                         makeStopwatch: {
                                             ForegroundStopwatch(notificationCenter: center,
                                                                 now: { clock.now },
                                                                 isInBackground: { presenceBed.applicationState == .background })
                                         },
                                         now: { clock.now },
                                         appPresence: presenceBed.presence)
        }

        self.clock = clock
        self.accounting = accounting
        self.ackScheduler = ackScheduler
        self.delayScheduler = delayScheduler
        self.failureReporter = failureReporter
        self.center = center
        self.resolver = resolver
        self.inappService = inappService
        self.pageFactory = pageFactory
        self.presenceBed = presenceBed
        self.providerAt = providerAt
        self.provider = providerAt(placeSystemName)
    }

    func makeProvider(placeSystemName: String) -> EmbeddedBlockWebViewProvider {
        providerAt(placeSystemName)
    }

    func announceNewSession() {
        expireSession()
        concludeNewSessionDownload()
    }

    func concludeNewSessionDownload() {
        resolver.sessionEpoch = currentSessionEpoch
        if resolver.configPublishedInSession != currentSessionEpoch {
            resolver.publishConfig()
        }
        announceConfig(resolver.configVersion)
    }

    func renewSession() {
        expireSession()
        resolver.sessionEpoch = currentSessionEpoch
        resolver.publishConfig()
        finishSessionCheck(startsNewSession: true)
    }

    func enterBackground() {
        presenceBed.enterBackground()
    }

    func returnToApp() {
        presenceBed.returnToApp()
    }

    func enterForegroundAtLaunch() {
        presenceBed.enterForegroundAtLaunch()
    }

    func enterForeground() {
        presenceBed.returnToAppWithNoSessionCheck()
    }

    func becomeActive() {
        presenceBed.becomeActive()
    }

    func finishSessionCheck(startedAt: TimeInterval? = nil, startsNewSession: Bool = false) {
        presenceBed.finishSessionCheck(startedAt: startedAt, startsNewSession: startsNewSession)
    }

    func answer(_ resolution: EmbeddedBlockResolution) -> EmbeddedBlockPlaceAnswer {
        EmbeddedBlockPlaceAnswer(resolution: resolution,
                                 processingDuration: 0,
                                 sessionEpoch: resolver.sessionEpoch,
                                 isOperationTriggered: false)
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

final class EmbeddedBlockPlaceMemoryMock: EmbeddedBlockPlaceRemembering {

    private(set) var shownPlaces: Set<String>

    private(set) var remembered: [String] = []

    private(set) var forgotten: [String] = []

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
}

final class EmbeddedBlockRevealAnimationSpy {

    private(set) var runs: [TimeInterval] = []

    var isReduceMotionEnabled = false

    var isDeferred = false

    var holdsAnimations = false

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

    func resolve(_ place: String, completion: @escaping (EmbeddedBlockResolution, TimeInterval, Int, ConfigVersion?) -> Void) {
        resolve(place, trigger: nil, completion: completion)
    }
}
