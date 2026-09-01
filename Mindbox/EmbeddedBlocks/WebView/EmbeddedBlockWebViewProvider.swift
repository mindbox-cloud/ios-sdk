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
/// An instance belongs to one container, so `start()` and `stop()` simply mirror its visibility
/// and can be called in cycles. After `stop()` the provider must stay silent until the next
/// `start()` — the container relies on this when it collapses an expired block.
final class EmbeddedBlockWebViewProvider {

    /// Reports every state change on the main thread. Set by the container.
    var onStateChange: ((EmbeddedBlockState) -> Void)?

    var onContentArrived: (() -> Void)?

    var onContentDelayed: (() -> Void)?

    var contentView: UIView? { isReady ? page?.view : nil }

    var isAwaitingAnswer: Bool { page == nil }

    /// While set, the block keeps loading on purpose: content is coming, the SDK is not silent.
    private(set) var isAwaitingDelayedContent = false

    private let placeSystemName: String
    private let registry: EmbeddedBlockPlaceRegistering
    private let inappService: EmbeddedBlockInappServing
    private let makePage: (EmbeddedBlockWebContent) -> EmbeddedBlockPageHosting

    private let accounting: InappShowAccounting

    private let reportFailure: (EmbeddedBlockWebContent, InAppShowFailureReason, String) -> Void

    private let reportUnansweredWait: (_ waited: TimeInterval) -> Void

    private var page: EmbeddedBlockPageHosting?

    private var content: EmbeddedBlockWebContent?

    private var isStarted = false

    private var isPaused = false

    private var outcome: EmbeddedBlockState = .loading

    private var isReady: Bool { outcome == .ready }

    private var loadGeneration = 0

    private var didAccountForShow = false

    /// The page has drawn something and nothing has been asked of it since. A stray repeat must not
    /// un-show a shown block; a rebuild and a data push both invite a fresh report.
    private var didReportShownContent = false

    /// The selection's part of `timeToDisplay`; the page's part runs on `presentationStopwatch`.
    private var processingDuration: TimeInterval = 0

    /// `timeToDisplay` frozen at the moment the page drew: a Show sent on a later return reports
    /// the render, not the time nobody was looking.
    private var renderedElapsed: TimeInterval?

    private var presentationStopwatch: ForegroundStopwatch

    private let makeStopwatch: () -> ForegroundStopwatch

    private let scheduleAckTimeout: EmbeddedBlockWaitScheduling

    private var dataPushAck: DispatchWorkItem?

    private var isAwaitingDataPushAck = false

    private var ackBudget: EmbeddedBlockAckBudget

    private var pendingFailureReport: (content: EmbeddedBlockWebContent,
                                       reason: InAppShowFailureReason,
                                       details: String)?

    private var pendingResolution: (resolution: EmbeddedBlockResolution, processingDuration: TimeInterval)?

    init(placeSystemName: String,
         registry: EmbeddedBlockPlaceRegistering,
         inappService: EmbeddedBlockInappServing,
         makePage: @escaping (EmbeddedBlockWebContent) -> EmbeddedBlockPageHosting,
         accounting: InappShowAccounting,
         reportFailure: @escaping (EmbeddedBlockWebContent, InAppShowFailureReason, String) -> Void,
         reportUnansweredWait: @escaping (_ waited: TimeInterval) -> Void,
         scheduleAckTimeout: @escaping EmbeddedBlockWaitScheduling = { delay, work in
             DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
         },
         makeStopwatch: @escaping () -> ForegroundStopwatch = { ForegroundStopwatch() },
         now: @escaping () -> TimeInterval = { CACurrentMediaTime() }) {
        self.placeSystemName = placeSystemName
        self.registry = registry
        self.inappService = inappService
        self.makePage = makePage
        self.accounting = accounting
        self.reportFailure = reportFailure
        self.reportUnansweredWait = reportUnansweredWait
        self.scheduleAckTimeout = scheduleAckTimeout
        self.makeStopwatch = makeStopwatch
        self.presentationStopwatch = makeStopwatch()
        self.ackBudget = EmbeddedBlockAckBudget(now: now)

        registry.register(self, place: placeSystemName)
    }

    func start() {
        guard !isStarted else { return }

        isStarted = true
        isPaused = false
        page?.isUserPresent = true

        let pending = pendingResolution
        pendingResolution = nil

        flushPendingFailureReport()

        if page != nil, outcome != .failed {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': back on screen, resuming its attempt at \(outcome)",
                          category: .embeddedBlocks)
            onStateChange?(outcome)
            if outcome == .ready {
                accountForShow()
            }

            if let pending = pending {
                apply(pending.resolution, processingDuration: pending.processingDuration)
            }

            rearmDataPushAckIfAwaited()
            askThePlaceAgain()
            return
        }

        if let pending = pending {
            apply(pending.resolution, processingDuration: pending.processingDuration)
            askThePlaceAgain()
            return
        }

        beginAttempt()
    }

    private func askThePlaceAgain() {
        registry.blockAppeared(placeSystemName)
    }

    func stop() {
        guard isStarted else { return }

        isStarted = false
        isPaused = true
        // The outcome is deliberately not reset: otherwise every pass of the block across the screen
        // would cost a full reload.
        suspendDataPushAck()
        // The page stays alive off screen, so it has to be told that nobody is looking.
        page?.isUserPresent = false
    }

    func abandonAttempt() {
        isStarted = false
        isPaused = false
        outcome = .failed
        pendingResolution = nil
        dropPage()
    }

    func teardown() {
        isStarted = false
        isPaused = false
        pendingResolution = nil
        pendingFailureReport = nil
        dropPage()
    }

    func reload() {
        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)' is reloading", category: .embeddedBlocks)

        dropPage()
        pendingResolution = nil
        loadGeneration += 1
        isStarted = true
        isPaused = false

        beginAttempt()
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

    func apply(_ resolution: EmbeddedBlockResolution, processingDuration: TimeInterval) {
        guard isStarted else {
            if isPaused {
                pendingResolution = (resolution, processingDuration)
            }
            return
        }

        isAwaitingDelayedContent = false

        switch resolution {
        case .empty:
            guard outcome != .empty else { return }

            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': nothing at this place — collapsing",
                          category: .embeddedBlocks)
            outcome = .empty
            onStateChange?(.empty)

        case .content(let fresh):
            applyContent(fresh, processingDuration: processingDuration)
        }
    }

    func contentIsDelayed() {
        guard isStarted else { return }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': content is coming after its delay — waiting",
                      category: .embeddedBlocks)
        isAwaitingDelayedContent = true
        onContentDelayed?()
    }

    private func applyContent(_ fresh: EmbeddedBlockWebContent, processingDuration: TimeInterval) {
        // Only a block that shows something is talked to; one that shows nothing is rebuilt. A page
        // confirms a data push and stays exactly as it was, so a collapsed block told about its content
        // would sit waiting for a report that never comes. Rebuilding revives it, in sync with Android.
        if let current = content, let page = page, isAttemptAlive {
            if fresh == current {
                Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': the place resolved to the same content — nothing to change",
                              category: .embeddedBlocks)
                return
            }

            if fresh.isSamePage(as: current) {
                content = fresh
                guard fresh.params != current.params else {
                    Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': same page, only its frequency or tags moved — refreshing the snapshot, nothing to tell the page",
                                  category: .embeddedBlocks)
                    return
                }

                Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': same page, new data — telling the page",
                              category: .embeddedBlocks)
                // The stopwatch is deliberately not restarted: a re-render after a data push cannot
                // account a show anyway (didAccountForShow holds), so its time goes nowhere.
                didReportShownContent = false
                page.sendInitData(params: fresh.params)
                armDataPushAck()
                return
            }
        }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': \(rebuildReason)", category: .embeddedBlocks)
        buildPage(with: fresh, processingDuration: processingDuration)
    }

    private var rebuildReason: String {
        guard page != nil else { return "building its page" }

        return isAttemptAlive
            ? "the place points at another page — rebuilding it"
            : "nothing is shown here — rebuilding its page to revive it"
    }

    private func buildPage(with fresh: EmbeddedBlockWebContent, processingDuration: TimeInterval) {
        dropPage()

        if outcome != .loading {
            onStateChange?(.loading)
        }
        outcome = .loading
        loadGeneration += 1
        didAccountForShow = false
        didReportShownContent = false
        self.processingDuration = processingDuration
        presentationStopwatch = makeStopwatch()
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
        page?.detachCallbacks()
        page?.cancel()
        page = nil
        content = nil
    }

    // MARK: - The data push's confirmation

    /// A page that misses the ack is rebuilt from scratch, in sync with Android. An error answer
    /// counts as silence — the web layer drops error envelopes before they arrive.
    private func armDataPushAck() {
        cancelDataPushAck()

        isAwaitingDataPushAck = true
        resumeDataPushAck()
    }

    private func resumeDataPushAck() {
        let generation = loadGeneration
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.isStarted, self.loadGeneration == generation else { return }

            self.dataPushAck = nil
            self.ackBudget.exhaust()
            self.isAwaitingDataPushAck = false

            guard let content = self.content else { return }

            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': the page never confirmed the data push — rebuilding it",
                          level: .error, category: .embeddedBlocks)
            self.buildPage(with: content, processingDuration: self.processingDuration)
        }

        ackBudget.resume()
        dataPushAck = work
        scheduleAckTimeout(ackBudget.remaining, work)
    }

    private func suspendDataPushAck() {
        ackBudget.suspend()
        dataPushAck?.cancel()
        dataPushAck = nil
    }

    private func cancelDataPushAck() {
        suspendDataPushAck()
        ackBudget.reset()
        isAwaitingDataPushAck = false
    }

    private func rearmDataPushAckIfAwaited() {
        guard isAwaitingDataPushAck else { return }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': back on screen with a data push still unconfirmed — waiting out the remaining \(ackBudget.remaining)s",
                      category: .embeddedBlocks)
        resumeDataPushAck()
    }

    private func acknowledgeDataPush() {
        guard isAwaitingDataPushAck else {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': the page confirmed a data push nobody was waiting on",
                          level: .debug, category: .embeddedBlocks)
            return
        }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': the page confirmed the data push",
                      category: .embeddedBlocks)
        cancelDataPushAck()
    }

    // MARK: - The page's reports

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

    /// The SDK never answered within the block's budget — a failure with no in-app to pin it on, once
    /// per place per session. Any answer, "nothing" included, would have disarmed the budget instead.
    func reportAnswerTimedOut(waited: TimeInterval) {
        guard SessionTemporaryStorage.shared.$ledger.mutate({ $0.recordUnanswered(placeSystemName) }) else {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': the SDK stayed silent again this session — already reported",
                          category: .embeddedBlocks)
            return
        }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': the SDK never answered within \(waited.toTimeSpan()) — reporting a failure without an in-app",
                      level: .error, category: .embeddedBlocks)
        reportUnansweredWait(waited)
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

        inappService.showInapp(id: inappId, params: params)
    }

    /// A question shows nothing, so it is answered for as long as the block is running — including
    /// while it is still loading, which is exactly when a page asks.
    private func answerShowableQuestion(_ ids: [String], completion: @escaping ([String]) -> Void) {
        guard isStarted, let content else { return }

        let generation = loadGeneration
        inappService.showableInappIds(among: ids, askedBy: content.inAppId) { [weak self] allowed in
            guard let self, self.isStarted, self.loadGeneration == generation else { return }

            completion(allowed)
        }
    }

    private func applyContentRendered(_ count: Int) {
        guard !didReportShownContent else {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': the page reported itself again with nothing asked of it — ignoring",
                          category: .embeddedBlocks)
            return
        }

        guard count > 0 else {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': page rendered nothing", category: .embeddedBlocks)
            settle(.empty)
            return
        }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': page rendered \(count) item(s)", category: .embeddedBlocks)
        didReportShownContent = true
        renderedElapsed = processingDuration + presentationStopwatch.elapsed
        settle(.ready)

        guard isStarted else { return }

        accountForShow()
    }

    private func handleUnreadableContentReport() {
        guard !didReportShownContent else {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': the page repeated contentRendered without a readable count — ignoring, the block is already shown",
                          category: .embeddedBlocks)
            return
        }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': contentRendered without a readable count, treating as broken",
                      level: .error, category: .embeddedBlocks)
        settle(.failed)
        report(.presentationFailed, "The block's page reported contentRendered without a readable count")
    }

    private func accountForShow() {
        guard let content = content, !didAccountForShow else { return }

        didAccountForShow = true

        let timeToDisplay = renderedElapsed ?? (processingDuration + presentationStopwatch.elapsed)
        presentationStopwatch.stop()

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': in-app \(content.inAppId) is shown, timeToDisplay=\(timeToDisplay.toTimeSpan())",
                      category: .embeddedBlocks)
        accounting.recordBlockShow(InappShow(inAppId: content.inAppId,
                                             frequency: content.frequency,
                                             tags: content.tags,
                                             timeToDisplay: timeToDisplay),
                                   at: placeSystemName)
    }
}

// MARK: - The registry's view of the block

extension EmbeddedBlockWebViewProvider: EmbeddedBlockPlaceHandling {

    var isActive: Bool { isStarted }
}
