//
//  EmbeddedBlockWebViewProvider.swift
//  Mindbox
//
//  Created by vailence on 03.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit
import QuartzCore
import MindboxLogger

/// Embedded block content — a web page found by the block id.
///
/// An instance belongs to one container: `start()` and `stop()` mirror its visibility, in cycles, and a `start()` after a
/// return waits for that return's session check. After `stop()` the container hears nothing until the next `start()`, which
/// it relies on when it collapses an expired block. A collapse held while the user looked drops the page at `stop()` and lands
/// on the next `start()`, unless its session has ended by then: the block then begins anew.
final class EmbeddedBlockWebViewProvider {

    /// Reports every state change on the main thread. Set by the container.
    var onStateChange: ((EmbeddedBlockState) -> Void)?

    var onContentArrived: (() -> Void)?

    var onContentDelayed: (() -> Void)?

    /// The content really started: at once on `start()`, or when the return's session check it waited for ended.
    var onStarted: (() -> Void)?

    var isStartPending: Bool { deferred.isStartAwaitingSessionCheck }

    var contentView: UIView? { isReady ? page?.view : nil }

    var isAwaitingAnswer: Bool { page == nil }

    /// While set, the block keeps loading on purpose: content is coming, the SDK is not silent.
    private(set) var isAwaitingDelayedContent = false

    private let placeSystemName: String
    private let registry: EmbeddedBlockPlaceRegistering
    private let inappService: InappRequestServing
    private let makePage: (EmbeddedBlockWebContent) -> EmbeddedBlockPageHosting

    private let accounting: InappShowAccounting

    private let failures: EmbeddedBlockFailureReporter

    private var page: EmbeddedBlockPageHosting?

    private var content: EmbeddedBlockWebContent?

    private var isStarted = false

    private var isPaused = false

    private var outcome: EmbeddedBlockState = .loading

    private var isReady: Bool { outcome == .ready }

    private var loadGeneration = 0

    /// The page has drawn something and nothing has been asked of it since. A stray repeat must not
    /// un-show a shown block; a rebuild and a data push both invite a fresh report.
    private var didReportShownContent = false

    private var pageShow: EmbeddedBlockPageShow?

    private let makeStopwatch: () -> ForegroundStopwatch

    private let appPresence: EmbeddedBlockAppPresence

    private let dataPushWait: EmbeddedBlockDataPushWait

    private var deferred = EmbeddedBlockDeferredAnswers()

    init(placeSystemName: String,
         registry: EmbeddedBlockPlaceRegistering,
         inappService: InappRequestServing,
         makePage: @escaping (EmbeddedBlockWebContent) -> EmbeddedBlockPageHosting,
         accounting: InappShowAccounting,
         reportFailure: @escaping EmbeddedBlockFailureReporter.Report,
         reportUnansweredWait: @escaping (_ waited: TimeInterval) -> Void,
         scheduleAckTimeout: @escaping EmbeddedBlockWaitScheduling = { delay, work in
             DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
         },
         makeStopwatch: @escaping () -> ForegroundStopwatch = { ForegroundStopwatch() },
         now: @escaping () -> TimeInterval = { CACurrentMediaTime() },
         appPresence: EmbeddedBlockAppPresence = .shared) {
        self.placeSystemName = placeSystemName
        self.registry = registry
        self.inappService = inappService
        self.makePage = makePage
        self.accounting = accounting
        self.failures = EmbeddedBlockFailureReporter(placeSystemName: placeSystemName,
                                                     report: reportFailure,
                                                     reportUnansweredWait: reportUnansweredWait)
        self.makeStopwatch = makeStopwatch
        self.appPresence = appPresence
        self.dataPushWait = EmbeddedBlockDataPushWait(placeSystemName: placeSystemName, now: now, schedule: scheduleAckTimeout, presence: appPresence)

        appPresence.subscribe(self)

        registry.register(self, place: placeSystemName)
    }

    func start() {
        guard !isStarted else { return }

        guard !appPresence.isAwaitingSessionCheck else {
            deferred.isStartAwaitingSessionCheck = true
            return
        }

        deferred.isStartAwaitingSessionCheck = false
        isStarted = true
        isPaused = false
        page?.isUserPresent = true
        defer { onStarted?() }

        failures.flushHeld()

        // First, as on Android: a page the parked answer replaces or drops is not resumed. A reset after this
        // read re-asks the started place.
        let generation = loadGeneration
        let parked = deferred.takeParked(unlessEndedIn: SessionTemporaryStorage.shared.ledger)
        if let parked {
            take(parked, isParked: true)
        }

        guard parked != nil || (page != nil && !outcome.isFailed) else {
            beginAttempt()
            return
        }

        if loadGeneration == generation, page != nil, !outcome.isFailed {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': back on screen, resuming its attempt at \(outcome)",
                          category: .embeddedBlocks)
            onStateChange?(outcome)
            if outcome == .ready {
                catchUpShownPage()
            }
            dataPushWait.resumeIfSuspended()
        }

        askThePlaceAgain()
    }

    private func askThePlaceAgain() {
        registry.blockAppeared(placeSystemName)
    }

    func stop() {
        deferred.isStartAwaitingSessionCheck = false
        guard isStarted else { return }

        isStarted = false
        isPaused = true
        // The outcome is deliberately not reset: otherwise every pass of the block across the screen
        // would cost a full reload.
        dataPushWait.suspend()
        // The page stays alive off screen, so it has to be told that nobody is looking.
        page?.isUserPresent = false

        if deferred.parkHeld() {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': the user left a block its place no longer shows — dropping its page, the collapse waits for the return",
                          category: .embeddedBlocks)
            dropPage()
        }
    }

    func abandonAttempt() {
        isStarted = false
        isPaused = false
        deferred.reset()
        dropPage()
        registry.blockAttemptEnded(placeSystemName)
    }

    func teardown() {
        failures.discardHeld()
        abandonAttempt()
    }

    /// A new attempt, started as `start()` starts one.
    func reload() {
        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)' is reloading", category: .embeddedBlocks)

        dropPage()
        deferred.reset()
        loadGeneration += 1
        isStarted = false
        isPaused = false

        start()
    }

    private func beginAttempt() {
        onStateChange?(.loading)
        outcome = .loading
        isAwaitingDelayedContent = false

        if page != nil {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': the page from the previous attempt cannot be resumed, dropping it",
                          category: .embeddedBlocks)
            dropPage()
        }

        registry.blockAppeared(placeSystemName)
    }

    // MARK: - The registry's answer

    func apply(_ answer: EmbeddedBlockPlaceAnswer) {
        guard isStarted else {
            if isPaused {
                failures.report(failureOf: answer)
                deferred.park(answer)
            }
            return
        }

        take(answer, isParked: false)
    }

    /// What an operation brings applies at once; only a collapse nobody on screen asked for waits for the
    /// user to leave. A parked answer was decided while nobody looked and was reported then: it applies now.
    private func take(_ answer: EmbeddedBlockPlaceAnswer, isParked: Bool) {
        isAwaitingDelayedContent = false

        if answer.resolution.content == nil, !isParked, isReady, !answer.isOperationTriggered {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': its place no longer shows this content — keeping it on screen until the user leaves",
                          category: .embeddedBlocks)
            failures.report(failureOf: answer)
            deferred.hold(answer)
            return
        }

        deferred.lift()

        switch answer.resolution {
        case .empty:
            dropPage()
            guard outcome != .empty else { return }

            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': nothing at this place — collapsing",
                          category: .embeddedBlocks)
            outcome = .empty
            onStateChange?(.empty)

        case .failure(let failure):
            dropPage()
            let failed = EmbeddedBlockState.failed(MindboxEmbeddedBlockFailReason(failure.reason))
            guard outcome != failed else { return }

            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': \(failure.details) — failing",
                          level: .error, category: .embeddedBlocks)
            settle(failed)
            if !isParked { failures.report(failure, isBlockOnScreen: isStarted) }

        case .configUnavailable:
            dropPage()
            let failed = EmbeddedBlockState.failed(MindboxEmbeddedBlockFailReason(.waitBudgetExceeded))
            guard outcome != failed else { return }

            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': the SDK has no config to answer with — failing",
                          level: .error, category: .embeddedBlocks)
            if !isParked { failures.reportUnansweredWaitOnce(answer.processingDuration, inSession: answer.sessionEpoch) }
            settle(failed)

        case .targetingUnavailable:
            dropPage()
            let failed = EmbeddedBlockState.failed(.networkError)
            guard outcome != failed else { return }

            // A 5xx the pass reported for every candidate it cut, and offline is not reported at all;
            // nothing to add here.
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': the place could not be checked — failing",
                          level: .error, category: .embeddedBlocks)
            settle(failed)

        case .content(let fresh):
            applyContent(fresh, of: answer)
        }
    }

    func contentIsDelayed() {
        guard isStarted, page == nil else { return }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': content is coming after its delay — waiting",
                      category: .embeddedBlocks)
        isAwaitingDelayedContent = true
        onContentDelayed?()
    }

    private func applyContent(_ fresh: EmbeddedBlockWebContent, of answer: EmbeddedBlockPlaceAnswer) {
        // Only a block that shows something is talked to; one that shows nothing is rebuilt. A page
        // confirms a data push and stays exactly as it was, so a collapsed block told about its content
        // would sit waiting for a report that never comes. Rebuilding revives it, in sync with Android.
        if let current = content, page != nil, isAttemptAlive, fresh.isSamePage(as: current) {
            content = fresh
            pageShow?.confirm(answer)
            if fresh.params != current.params {
                pageShow?.requireRefresh()
            }

            if pageShow?.isRefreshDue != true {
                Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': the place resolved to the same page with the same data — nothing to tell the page",
                              category: .embeddedBlocks)
            }
            catchUpShownPage()
            return
        }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': \(rebuildReason)", category: .embeddedBlocks)
        buildPage(with: fresh, sessionEpoch: answer.sessionEpoch, processingDuration: answer.processingDuration)
    }

    /// A page that has drawn and is on screen takes the data it is owed; one that has not is told once it
    /// draws — a page still loading drops a push it has no listener for yet.
    private func catchUpShownPage() {
        guard let page, let content, pageShow?.isRefreshDue == true else {
            accountForShow()
            return
        }

        guard isStarted, isReady, !deferred.isHolding, appPresence.isPresent else {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': new data for a page that has not drawn yet, that the user cannot see or that its place no longer shows — telling it once it can",
                          category: .embeddedBlocks)
            return
        }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': same page, new data — telling the page",
                      category: .embeddedBlocks)
        pageShow?.refreshSent()
        didReportShownContent = false
        page.sendInitData(params: content.params)
        armDataPushAck()
    }

    private var rebuildReason: String {
        guard page != nil else { return "building its page" }

        return isAttemptAlive
            ? "the place points at another page — rebuilding it"
            : "nothing is shown here — rebuilding its page to revive it"
    }

    private func buildPage(with fresh: EmbeddedBlockWebContent, sessionEpoch: Int, processingDuration: TimeInterval) {
        dropPage()

        if outcome != .loading {
            onStateChange?(.loading)
        }
        outcome = .loading
        loadGeneration += 1
        didReportShownContent = false
        pageShow = EmbeddedBlockPageShow(builtFor: sessionEpoch, processingDuration: processingDuration, makeStopwatch: makeStopwatch)

        let page = makePage(fresh)
        page.isUserPresent = true
        page.onContentRendered = { [weak self] count in
            self?.applyContentRendered(count)
        }
        page.onUnreadableContentReport = { [weak self] in
            self?.handleUnreadableContentReport()
        }
        page.onShowableQuestion = { [weak self, weak page] ids, completion in
            self?.answerShowableQuestion(ids, askedFrom: page, completion: completion)
        }
        page.onShowInAppRequest = { [weak self, weak page] inappId, params, completion in
            self?.showInapp(id: inappId, params: params, askedFrom: page, completion: completion)
        }
        page.onDataPushConfirmed = { [weak self] in
            self?.dataPushWait.acknowledge()
        }
        page.onLoadFailure = { [weak self] in
            self?.handleLoadFailure()
        }
        self.page = page
        self.content = fresh

        onContentArrived?()

        page.load()
    }

    /// Detached from us first, so that its late messages do not end up in the new attempt.
    private func dropPage() {
        dataPushWait.cancel()
        page?.detachCallbacks()
        page?.cancel()
        page = nil
        content = nil
        pageShow = nil
        deferred.lift()
    }

    // MARK: - The data push's confirmation

    /// An error answer to the push confirms nothing: like silence, it leaves the page to be rebuilt
    /// when the ack budget runs out — unless its place no longer shows it: then the page only waits for
    /// the user to leave, and content that lifts the hold hands it the data again.
    private func armDataPushAck() {
        dataPushWait.arm { [weak self] in
            guard let self, let content = self.content, let pageShow = self.pageShow else { return }

            guard !self.deferred.isHolding else {
                self.pageShow?.requireRefresh()
                return
            }

            Logger.common(message: "[EmbeddedBlock] Block '\(self.placeSystemName)': the page never confirmed the data push — rebuilding it",
                          level: .error, category: .embeddedBlocks)
            self.buildPage(with: content, sessionEpoch: pageShow.confirmedEpoch, processingDuration: pageShow.processingDurationOfARebuild)
        }
    }

    // MARK: - The page's reports

    private func settle(_ newOutcome: EmbeddedBlockState) {
        outcome = newOutcome

        if !isAttemptAlive {
            registry.blockAttemptEnded(placeSystemName)
        }

        guard isStarted else { return }

        onStateChange?(newOutcome)
    }

    func handleLoadFailure() {
        fail(.webviewLoadFailed, "The block's page failed to load")
    }

    func failSilentPage() {
        fail(.presentationFailed, "The block's page did not report itself in time")
        abandonAttempt()
    }

    /// The SDK never answered within the block's budget. The block fails every time — the host and
    /// the analytics must agree it was a failure, not an empty place — while the analytics hear about
    /// it once per place per session, with no in-app to pin it on. Any answer, "nothing" included,
    /// would have disarmed the budget instead.
    ///
    /// Unlike `configUnavailable` — an instant answer that leaves the block started, so the next
    /// config revives it at once — a timeout abandons the attempt: a late answer is dropped and the
    /// block asks afresh on its next appearance. In sync with Android, where `onConfigTimeout` gives
    /// up and `onConfigUnavailable` does not.
    func failUnanswered(waited: TimeInterval) {
        failures.reportUnansweredWaitOnce(waited)
        settle(.failed(MindboxEmbeddedBlockFailReason(.waitBudgetExceeded)))
        abandonAttempt()
    }

    private func fail(_ reason: InAppShowFailureReason, _ details: String) {
        settle(.failed(MindboxEmbeddedBlockFailReason(reason)))

        guard let content = content else { return }

        failures.report(EmbeddedBlockResolutionFailure(inAppId: content.inAppId, tags: content.tags, reason: reason, details: details),
                        isBlockOnScreen: isStarted)
    }

    private var isAttemptAlive: Bool {
        outcome == .loading || outcome == .ready
    }

    /// A page whose block has collapsed or failed is still alive and can still ask — but no user
    /// touch stands behind it, and the in-app would appear over the app out of nowhere.
    private func showInapp(id inappId: String, params: [String: JSONValue], askedFrom page: EmbeddedBlockPageHosting?, completion: @escaping (Result<Void, BridgeErrorCode>) -> Void) {
        guard isShowing(page) else {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': refused a show request from a block that is not shown",
                          category: .embeddedBlocks)
            completion(.failure(.notVisible))
            return
        }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': showing in-app \(inappId) with \(params.count) param(s)",
                      category: .embeddedBlocks)

        inappService.showInapp(id: inappId, params: params, proceedIf: { [weak self, weak page] in self?.isShowing(page) ?? false }, completion: completion)
    }

    private func isShowing(_ page: EmbeddedBlockPageHosting?) -> Bool { isStarted && isAttemptAlive && page != nil && self.page === page }

    /// A question shows nothing, so it is answered for as long as the page is the block's: while it is loading, which is exactly
    /// when a page asks, and off screen — a page left without an answer would empty itself before the user is back.
    private func answerShowableQuestion(_ ids: [String], askedFrom page: EmbeddedBlockPageHosting?, completion: @escaping (Result<[String], BridgeErrorCode>) -> Void) {
        guard let content, page != nil, self.page === page else { return }

        inappService.showableInappIds(among: ids, askedBy: content.inAppId) { [weak self, weak page] answer in
            guard let self, page != nil, self.page === page else { return }

            completion(answer)
        }
    }

    private func applyContentRendered(_ renderedCount: Int) {
        guard !didReportShownContent else {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': the page reported itself again with nothing asked of it — ignoring",
                          category: .embeddedBlocks)
            return
        }

        guard renderedCount > 0 else {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': page rendered nothing", category: .embeddedBlocks)
            settle(.empty)
            return
        }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': page rendered \(renderedCount) item(s)", category: .embeddedBlocks)
        didReportShownContent = true
        pageShow?.pageRendered()
        settle(.ready)
        catchUpShownPage()
    }

    private func handleUnreadableContentReport() {
        guard !didReportShownContent else {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': the page repeated contentRendered without a readable count — ignoring, the block is already shown",
                          category: .embeddedBlocks)
            return
        }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': contentRendered without a readable count, treating as broken",
                      level: .error, category: .embeddedBlocks)
        fail(.presentationFailed, "The block's page reported contentRendered without a readable count")
    }

    /// The user sees the page: the block is on screen, the user sees the app in a known session, and its
    /// place still shows it.
    private func accountForShow() {
        guard isStarted, isReady, !deferred.isHolding, appPresence.isPresent, let content,
              let due = pageShow?.takeDueShow() else { return }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': in-app \(content.inAppId) is shown in session \(due.sessionEpoch), timeToDisplay=\(due.timeToDisplay.toTimeSpan())",
                      category: .embeddedBlocks)
        accounting.recordBlockShow(InappShow(inAppId: content.inAppId,
                                             frequency: content.frequency,
                                             tags: content.tags,
                                             timeToDisplay: due.timeToDisplay),
                                   at: placeSystemName,
                                   sessionEpoch: due.sessionEpoch)
    }
}

// MARK: - The app's presence

extension EmbeddedBlockWebViewProvider: EmbeddedBlockAppPresenceSubscribing {

    func userDidBecomePresent() {
        if deferred.isStartAwaitingSessionCheck {
            start()
        }

        guard isStarted else { return }

        dataPushWait.resumeIfSuspended()
        catchUpShownPage()
    }
}

// MARK: - The registry's view of the block

extension EmbeddedBlockWebViewProvider: EmbeddedBlockPlaceHandling {

    var isActive: Bool { isStarted }

    var holdsAnAttempt: Bool { (isStarted || isPaused) && (isAttemptAlive || deferred.parksContent) }
}
