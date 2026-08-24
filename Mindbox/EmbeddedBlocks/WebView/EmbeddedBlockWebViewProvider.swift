//
//  EmbeddedBlockWebViewProvider.swift
//  Mindbox
//
//  Created by vailence on 03.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit
import MindboxLogger

/// Embedded block content — a web page found by the block id.
///
/// An instance belongs to one container, so `start()` and `stop()` simply mirror its visibility
/// and can be called in cycles. After `stop()` the provider must stay silent until the next
/// `start()` — the container relies on this when it collapses an expired block.
final class EmbeddedBlockWebViewProvider {

    /// Reports every state change on the main thread. Set by the container.
    var onStateChange: ((EmbeddedBlockState) -> Void)?

    var onContentArrived: (() -> Void)?

    var contentView: UIView? { isReady ? page?.view : nil }

    var isAwaitingAnswer: Bool { page == nil }

    private let placeSystemName: String
    private let registry: EmbeddedBlockPlaceRegistering
    private let feed: EmbeddedBlockFeedServing
    private let makePage: (EmbeddedBlockWebContent) -> EmbeddedBlockPageHosting

    private let recordShow: (String) -> Void

    private let reportShow: (EmbeddedBlockWebContent, String) -> Void

    private let reportFailure: (EmbeddedBlockWebContent, InAppShowFailureReason, String) -> Void

    private var page: EmbeddedBlockPageHosting?

    private var content: EmbeddedBlockWebContent?

    private var isStarted = false

    private var outcome: EmbeddedBlockState = .loading

    private var isReady: Bool { outcome == .ready }

    private var loadGeneration = 0

    private var didAccountForShow = false

    private var attemptStopwatch = ForegroundStopwatch()

    private let scheduleAckTimeout: EmbeddedBlockWaitScheduling

    private var dataPushAck: DispatchWorkItem?

    /// Whether the page still owes a confirmation for the data it was sent. Outlives the timer: the
    /// wait pauses with the block and is armed again by the return.
    private var isAwaitingDataPushAck = false

    /// A failure that happened behind another screen, held until somebody looks at the block.
    ///
    /// The backend hears about blocks the user was shown, and a page that failed off screen was not
    /// one — the same rule the show already follows. The content travels with the report: the attempt
    /// it belonged to may be dropped by the time the block comes back.
    private var pendingFailureReport: (content: EmbeddedBlockWebContent,
                                       reason: InAppShowFailureReason,
                                       details: String)?

    /// How long the page took to render, frozen where the render was reported.
    ///
    /// The show can be counted much later — a page that finished behind another screen is counted by
    /// the `start()` that brings it back — and `timeToDisplay` measures the wait for the page, not
    /// the user's absence from the screen.
    private var renderedElapsed: TimeInterval?

    /// The registry's answer that arrived while nobody was looking.
    ///
    /// Dropping it was harmless while every return re-resolved; now that a return resumes instead,
    /// this is the only way a block hears that its place changed behind another screen. Applying it
    /// right away is not: swapping the page under a container that is not showing it is work for
    /// nothing, and the newest answer is the only one worth keeping.
    private var pendingResolution: EmbeddedBlockResolution?

    init(placeSystemName: String,
         registry: EmbeddedBlockPlaceRegistering,
         feed: EmbeddedBlockFeedServing,
         makePage: @escaping (EmbeddedBlockWebContent) -> EmbeddedBlockPageHosting,
         recordShow: @escaping (String) -> Void,
         reportShow: @escaping (EmbeddedBlockWebContent, String) -> Void,
         reportFailure: @escaping (EmbeddedBlockWebContent, InAppShowFailureReason, String) -> Void,
         scheduleAckTimeout: @escaping EmbeddedBlockWaitScheduling = { delay, work in
             DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
         }) {
        self.placeSystemName = placeSystemName
        self.registry = registry
        self.feed = feed
        self.makePage = makePage
        self.recordShow = recordShow
        self.reportShow = reportShow
        self.reportFailure = reportFailure
        self.scheduleAckTimeout = scheduleAckTimeout

        registry.register(self, place: placeSystemName)
    }

    func start() {
        guard !isStarted else { return }

        isStarted = true
        page?.isUserPresent = true

        let pending = pendingResolution
        pendingResolution = nil

        flushPendingFailureReport()

        // Coming back to the screen resumes the attempt that was already running: the page it built
        // stands and whatever it reported while nobody was looking is announced now. Only a block
        // with nothing to resume — no page at all, or one whose attempt failed — starts a new cycle.
        if page != nil, outcome != .failed {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': back on screen, resuming its attempt at \(outcome)",
                          category: .embeddedBlocks)
            onStateChange?(outcome)
            // A page that rendered off screen is only shown now, so this is where the show is counted.
            if outcome == .ready {
                accountForShow()
            }

            // And only then what changed while nobody was looking, so the block is seen where it was
            // left before it moves on.
            if let pending = pending {
                apply(pending)
            }

            // The page's own wait for a confirmation paused with the block; it did not end.
            rearmDataPushAckIfAwaited()
            askThePlaceAgain()
            return
        }

        // The answer already in hand is applied first, so the block is seen where it was left, and
        // the place is asked right after: that answer may itself have gone stale off screen.
        if let pending = pending {
            apply(pending)
            askThePlaceAgain()
            return
        }

        beginAttempt()
    }

    /// Every return asks the place again, in sync with Android, where `start()` always does.
    ///
    /// An invalidation landing on a place with no block on screen is dropped where it happens — the
    /// registry has nowhere to draw it — so a return is the only chance to hear that the place has
    /// moved on. Asking costs nothing when it has not: the same answer is deduplicated against the
    /// page that already stands.
    private func askThePlaceAgain() {
        registry.blockAppeared(placeSystemName)
    }

    func stop() {
        guard isStarted else { return }

        isStarted = false
        // A pause, not an end: the outcome stands and the page keeps living — leaving the screen must
        // not cost the attempt, and `cancel()` closes a page for good, so a cancelled one could never
        // be resumed. What ends an attempt is `abandonAttempt()`; what ends the block is `teardown()`.
        //
        // The page's wait for a confirmation pauses with it: a timer that fired off screen would
        // rebuild a page nobody is looking at, and one dropped for good would leave the block holding
        // data the page never acknowledged.
        suspendDataPushAck()
        // The page stays alive off screen, so it has to be told that nobody is looking.
        page?.isUserPresent = false
    }

    /// The container gave up on this attempt — it ran out of patience. The page is closed so it
    /// cannot report its way back into a block that has already collapsed, and the next time the
    /// block is looked at it starts a cycle anew rather than resuming this one.
    func abandonAttempt() {
        isStarted = false
        outcome = .failed
        pendingResolution = nil
        dropPage()
    }

    /// The block is gone for good. Unlike `stop()`, this closes the page: nothing is coming back.
    func teardown() {
        isStarted = false
        pendingResolution = nil
        pendingFailureReport = nil
        dropPage()
    }

    func reload() {
        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)' is reloading", category: .embeddedBlocks)

        dropPage()
        // The attempt that answer belonged to is over: applying it later would put the older page
        // back over the one the reload is about to build.
        pendingResolution = nil
        loadGeneration += 1
        isStarted = true

        beginAttempt()
    }

    private func beginAttempt() {
        onStateChange?(.loading)
        outcome = .loading
        attemptStopwatch = ForegroundStopwatch()

        if page != nil {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': the page from the previous attempt cannot be resumed, dropping it",
                          category: .embeddedBlocks)
            dropPage()
        }

        registry.blockAppeared(placeSystemName)
    }

    // MARK: - The registry's answer

    func apply(_ resolution: EmbeddedBlockResolution) {
        guard isStarted else {
            pendingResolution = resolution
            return
        }

        switch resolution {
        case .empty:
            guard outcome != .empty else { return }

            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': nothing at this place — collapsing",
                          category: .embeddedBlocks)
            outcome = .empty
            onStateChange?(.empty)

        case .content(let fresh):
            applyContent(fresh)
        }
    }

    private func applyContent(_ fresh: EmbeddedBlockWebContent) {
        if let current = content, let page = page, outcome != .failed {
            // A collapsed page is deliberately not deduplicated: for it the same answer is news —
            // re-sent data is what makes the page re-report itself and revive.
            if fresh == current, outcome == .ready || outcome == .loading {
                Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': the place resolved to the same content — nothing to change",
                              category: .embeddedBlocks)
                return
            }

            if fresh.isSamePage(as: current) {
                Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': same page, new data — telling the page",
                              category: .embeddedBlocks)
                content = fresh
                page.sendInitData(params: fresh.params)
                armDataPushAck()
                return
            }
        }

        let reason = page == nil ? "building its page" : "the place points at another page — rebuilding it"
        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': \(reason)", category: .embeddedBlocks)
        buildPage(with: fresh)
    }

    private func buildPage(with fresh: EmbeddedBlockWebContent) {
        dropPage()

        if outcome != .loading {
            onStateChange?(.loading)
            attemptStopwatch = ForegroundStopwatch()
        }
        outcome = .loading
        loadGeneration += 1
        didAccountForShow = false
        renderedElapsed = nil

        let page = makePage(fresh)
        page.isUserPresent = true
        page.onContentRendered = { [weak self] count in
            self?.applyContentRendered(count)
        }
        page.onUnreadableContentReport = { [weak self] in
            self?.handleUnreadableContentReport()
        }
        page.onShowableQuestion = { [weak self] ids, completion in
            self?.answerShowableQuestion(ids, completion: completion)
        }
        page.onShowInAppRequest = { [weak self] inappId, params in
            self?.showInapp(id: inappId, params: params)
        }
        page.onDataPushConfirmed = { [weak self] in
            self?.acknowledgeDataPush()
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
        cancelDataPushAck()
        page?.onContentRendered = nil
        page?.onUnreadableContentReport = nil
        page?.onShowableQuestion = nil
        page?.onShowInAppRequest = nil
        page?.onDataPushConfirmed = nil
        page?.onLoadFailure = nil
        page?.cancel()
        page = nil
        content = nil
    }

    // MARK: - The data push's confirmation

    /// A page that misses the ack is rebuilt from scratch, in sync with Android. An error answer
    /// counts as silence — the web layer drops error envelopes before they arrive.
    private func armDataPushAck() {
        cancelDataPushAck()

        let generation = loadGeneration
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.isStarted, self.loadGeneration == generation else { return }

            self.dataPushAck = nil
            self.isAwaitingDataPushAck = false

            guard let content = self.content else { return }

            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': the page never confirmed the data push — rebuilding it",
                          level: .error, category: .embeddedBlocks)
            self.buildPage(with: content)
        }

        dataPushAck = work
        isAwaitingDataPushAck = true
        scheduleAckTimeout(TimeInterval(Constants.EmbeddedBlock.readyTimeoutSeconds), work)
    }

    /// The timer only: the wait itself stands, and the block arms it again when it comes back.
    private func suspendDataPushAck() {
        dataPushAck?.cancel()
        dataPushAck = nil
    }

    private func cancelDataPushAck() {
        suspendDataPushAck()
        isAwaitingDataPushAck = false
    }

    private func rearmDataPushAckIfAwaited() {
        guard isAwaitingDataPushAck else { return }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': back on screen with a data push still unconfirmed — waiting on it again",
                      category: .embeddedBlocks)
        armDataPushAck()
    }

    private func acknowledgeDataPush() {
        guard isStarted else { return }
        guard dataPushAck != nil else {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': the page confirmed a data push nobody was waiting on",
                          level: .debug, category: .embeddedBlocks)
            return
        }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': the page confirmed the data push",
                      category: .embeddedBlocks)
        cancelDataPushAck()
    }

    // MARK: - The page's reports

    /// Where the attempt got to, recorded whether or not anybody is looking.
    ///
    /// A page that finishes behind another screen is not a page that has to load again: the outcome
    /// is kept and announced by the next `start()`. Announcing it right away would push a state into
    /// a container that has already paused.
    private func settle(_ newOutcome: EmbeddedBlockState) {
        outcome = newOutcome

        guard isStarted else { return }

        onStateChange?(newOutcome)
    }

    func handleLoadFailure() {
        settle(.failed)
        report(.webviewLoadFailed, "The block's page failed to load")
    }

    func reportPageTimedOut() {
        report(.presentationFailed, "The block's page did not report itself in time")
    }

    private func report(_ reason: InAppShowFailureReason, _ details: String) {
        guard let content = content else { return }

        guard isStarted else {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': \(reason.rawValue) for in-app \(content.inAppId) happened off screen — held until the block is looked at",
                          category: .embeddedBlocks)
            pendingFailureReport = (content, reason, details)
            return
        }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': reporting \(reason.rawValue) for in-app \(content.inAppId)",
                      level: .error, category: .embeddedBlocks)
        reportFailure(content, reason, details)
    }

    private func flushPendingFailureReport() {
        guard let held = pendingFailureReport else { return }

        pendingFailureReport = nil

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': reporting the held \(held.reason.rawValue) for in-app \(held.content.inAppId)",
                      level: .error, category: .embeddedBlocks)
        reportFailure(held.content, held.reason, held.details)
    }

    private var isAttemptAlive: Bool {
        outcome == .loading || outcome == .ready
    }

    /// A page whose block has collapsed or failed is still alive and can still ask — but no user
    /// touch stands behind it, and the in-app would appear over the app out of nowhere.
    private func showInapp(id inappId: String, params: [String: JSONValue]) {
        guard isStarted, isAttemptAlive else {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': ignored a show request from a block that is not shown",
                          category: .embeddedBlocks)
            return
        }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': showing in-app \(inappId) with \(params.count) param(s)",
                      category: .embeddedBlocks)

        feed.showInapp(id: inappId, params: params)
    }

    /// A question shows nothing, so it is answered for as long as the block is running — including
    /// while it is still loading, which is exactly when a feed asks.
    private func answerShowableQuestion(_ ids: [String], completion: @escaping ([String]) -> Void) {
        guard isStarted else { return }

        let generation = loadGeneration
        feed.showableInappIds(among: ids) { [weak self] answer in
            guard let self, self.isStarted, self.loadGeneration == generation else { return }

            completion(answer.inappIds)
            answer.vouch()
        }
    }

    private func applyContentRendered(_ count: Int) {
        // The page reports a number, not a collection, so `isEmpty` has nothing to be asked of here.
        // swiftlint:disable:next empty_count
        guard count > 0 else {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': page rendered nothing", category: .embeddedBlocks)
            settle(.empty)
            return
        }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': page rendered \(count) item(s)", category: .embeddedBlocks)
        renderedElapsed = attemptStopwatch.elapsed
        settle(.ready)

        // Only what somebody is looking at counts as shown; a page that rendered off screen is
        // counted by the `start()` that brings it back.
        guard isStarted else { return }

        accountForShow()
    }

    private func handleUnreadableContentReport() {
        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': contentRendered without a readable count, treating as broken",
                      level: .error, category: .embeddedBlocks)
        settle(.failed)
        report(.presentationFailed, "The block's page reported contentRendered without a readable count")
    }

    /// Blocks arrive `unlimited` by contract, so the backend is told even when the frequency writes
    /// no history. The cooldown between overlay shows is deliberately left alone — a block interrupts nothing.
    private func accountForShow() {
        guard let content = content, !didAccountForShow else { return }

        didAccountForShow = true

        let timeToDisplay = (renderedElapsed ?? attemptStopwatch.elapsed).toTimeSpan()
        attemptStopwatch.stop()

        // Deduplicated per session by the in-app, in sync with Android: a page rebuilt within a
        // session re-draws what the user already saw.
        if SessionTemporaryStorage.shared.blockShowsReportedInSession.contains(content.inAppId) {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': in-app \(content.inAppId) is shown again this session — the event was already reported",
                          category: .embeddedBlocks)
        } else {
            SessionTemporaryStorage.shared.$blockShowsReportedInSession.mutate { $0.insert(content.inAppId) }
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': in-app \(content.inAppId) is shown, timeToDisplay=\(timeToDisplay)",
                          category: .embeddedBlocks)
            reportShow(content, timeToDisplay)
        }

        guard InappFrequency.countsShows(content.frequency) else {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': in-app \(content.inAppId) is shown without a limit — nothing to count",
                          category: .embeddedBlocks)
            return
        }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': counting a show of in-app \(content.inAppId)",
                      category: .embeddedBlocks)
        recordShow(content.inAppId)
    }
}

// MARK: - The registry's view of the block

extension EmbeddedBlockWebViewProvider: EmbeddedBlockPlaceHandling {

    var isActive: Bool { isStarted }
}
