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

final class EmbeddedBlockWebViewProvider {

    var onStateChange: ((EmbeddedBlockState) -> Void)?

    var onContentArrived: (() -> Void)?

    var onContentDelayed: (() -> Void)?

    var onKeptContentChanged: (() -> Void)?

    var onStarted: (() -> Void)?

    var isOnScreen: () -> Bool = { false }

    var contentView: UIView? { isReady ? page?.view : nil }

    private(set) var delayedInSession: Int?

    var isAwaitingKeptContent: Bool { page == nil && registry.keepsContent(for: placeSystemName) }

    var heldCollapse: EmbeddedBlockState? { deferred.heldOutcome?.state }

    let placeSystemName: String
    private let registry: EmbeddedBlockPlaceRegistering
    let inappService: InappRequestServing
    private let makePage: (EmbeddedBlockWebContent) -> EmbeddedBlockPageHosting

    private let accounting: InappShowAccounting

    private let failures: EmbeddedBlockFailureReporter

    private(set) var page: EmbeddedBlockPageHosting?

    private(set) var content: EmbeddedBlockWebContent?

    private(set) var isStarted = false

    private(set) var isPaused = false

    private var hasStartedSinceTheBackground = false

    private var outcome: EmbeddedBlockState = .loading

    var isReady: Bool { outcome == .ready }

    private var loadGeneration = 0

    private var didReportShownContent = false

    private(set) var pageShow: EmbeddedBlockPageShow?

    private let makeStopwatch: () -> ForegroundStopwatch

    private let appPresence: EmbeddedBlockAppPresence

    private let dataPushWait: EmbeddedBlockDataPushWait

    var isAwaitingDataPushConfirmation: Bool { dataPushWait.isAwaitingConfirmation }

    private(set) var deferred = EmbeddedBlockDeferredAnswers()

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

        pageShow?.resume()

        guard !appPresence.isAwaitingSessionCheck else {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': on screen before the return's session check ended — its start waits for the check", category: .embeddedBlocks)
            deferred.isStartAwaitingSessionCheck = true
            if let collapse = deferred.parkedCollapse {
                take(collapse, isParked: true)
            } else if page != nil, outcome == .empty {
                onStateChange?(outcome)
            }
            return
        }

        deferred.isStartAwaitingSessionCheck = false
        isStarted = true
        hasStartedSinceTheBackground = true
        isPaused = false
        page?.isUserPresent = true
        defer { onStarted?() }

        failures.flushHeld()

        let generation = loadGeneration
        let parked = deferred.takeParked(unlessEndedIn: SessionTemporaryStorage.shared.ledger).flatMap { registry.bringOnScreen($0, at: placeSystemName) }
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
            onStateChange?(isCoveredForTheSession ? .loading : outcome)
            if outcome == .ready { catchUpShownPage() }
            dataPushWait.resumeIfSuspended()
        }

        registry.blockAppeared(placeSystemName)
    }

    func stop() {
        deferred.isStartAwaitingSessionCheck = false
        pageShow?.suspend()
        if let held = deferred.takeHeld() {
            land(held)
        }
        guard isStarted else { return }

        isStarted = false
        isPaused = true
        dataPushWait.suspend()
        page?.isUserPresent = false
        if let unseen = deferred.parkContentAwaitingTheUser(ifAlive: isAttemptAlive, timedBy: makeStopwatch) { registry.giveSlotBack(unseen, at: placeSystemName) }
    }

    private func land(_ held: EmbeddedBlockDeferredAnswers.HeldCollapse) {
        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': the user left, applying the held answer", category: .embeddedBlocks)
        guard case .placeAnswer(let answer) = held else {
            dropPage()
            settle(.empty, isUserLeaving: true)
            return
        }

        collapse(by: answer, isReported: true)
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

    func reload() {
        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)' is reloading", category: .embeddedBlocks)

        dropPage()
        deferred.reset()
        loadGeneration += 1
        isStarted = false
        isPaused = false
        outcome = .loading

        start()
        if isStartPending { onStateChange?(.loading) }
    }

    private func beginAttempt() {
        onStateChange?(.loading)
        outcome = .loading
        delayedInSession = nil

        if page != nil {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': the page from the previous attempt cannot be resumed, dropping it",
                          category: .embeddedBlocks)
            dropPage()
        }

        registry.blockAppeared(placeSystemName)
    }

    // MARK: - The registry's answer

    func apply(_ answer: EmbeddedBlockPlaceAnswer) {
        guard isStarted || isStartPending && isReady && answer.resolution.content == nil else {
            let fate = isPaused ? "arrived off screen, applied when back on screen" : isStartPending ? "arrived before the block started, dropped" : "arrived after the block stopped waiting, dropped"
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': answer \(fate)", category: .embeddedBlocks)
            if isPaused {
                failures.report(failureOf: answer)
                deferred.park(answer, overPageOf: pageShow?.confirmedEpoch, timedBy: makeStopwatch)
            }
            return
        }

        deferred.dropParked()
        take(answer, isParked: false)
    }

    private func take(_ answer: EmbeddedBlockPlaceAnswer, isParked: Bool) {
        delayedInSession = nil

        if answer.resolution.content == nil, !isParked, isReady, !isCoveredForTheSession, !answer.isOperationTriggered {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': the place answered without content — keeping what is shown until the user leaves",
                          category: .embeddedBlocks)
            failures.report(failureOf: answer)
            deferred.hold(answer)
            return
        }

        deferred.liftPlaceAnswer()

        guard case .content(let fresh) = answer.resolution else {
            collapse(by: answer, isReported: isParked)
            return
        }

        applyContent(fresh, of: answer)
    }

    private func collapse(by answer: EmbeddedBlockPlaceAnswer, isReported: Bool) {
        dropPage()
        guard let collapse = answer.resolution.collapse, outcome != collapse.state else { return }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': \(collapse.reason)",
                      level: collapse.state.isFailed ? .error : .debug, category: .embeddedBlocks)
        if !isReported { failures.report(failureOf: answer) }
        outcome = collapse.state
        if outcome.isFailed { registry.blockAttemptEnded(placeSystemName) }
        onStateChange?(outcome)
    }

    func contentIsDelayed() {
        guard isStarted, page == nil || isCoveredForTheSession else { return }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': content is coming after its delay — waiting",
                      category: .embeddedBlocks)
        delayedInSession = SessionTemporaryStorage.shared.ledger.sessionEpoch
        onContentDelayed?()
    }

    private func applyContent(_ fresh: EmbeddedBlockWebContent, of answer: EmbeddedBlockPlaceAnswer) {
        defer { deferred.contentAwaitingTheUser = appPresence.isPresent ? nil : answer }
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
            if isCoveredForTheSession, pageShow?.isRefreshDue == true { onContentDelayed?() }
            catchUpShownPage()
            return
        }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': \(rebuildReason)", category: .embeddedBlocks)
        buildPage(with: fresh, sessionEpoch: answer.sessionEpoch, processingDuration: answer.processingDuration)
    }

    private func catchUpShownPage() {
        guard let page, let content, let owed = pageShow, owed.isRefreshDue else {
            accountForShow()
            return
        }

        guard isStarted, isReady, !deferred.isHoldingPlaceAnswer, appPresence.isPresent, !SessionTemporaryStorage.shared.ledger.hasEnded(owed.confirmedEpoch) else {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': new data waits — the page has not drawn, the user cannot see it or its place no longer shows it; told once it can, within its session",
                          category: .embeddedBlocks)
            return
        }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': same in-app — updating the page in place",
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
        page.onLoadFailure = { [weak self] details in
            self?.handleLoadFailure(details)
        }
        self.page = page
        self.content = fresh

        onContentArrived?()

        page.load()
    }

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

    private func armDataPushAck() {
        if isCoveredForTheSession { onContentArrived?() }
        dataPushWait.arm { [weak self] in
            guard let self, let content = self.content, let pageShow = self.pageShow else { return }

            guard !self.deferred.isShowWithheld else {
                self.pageShow?.requireRefresh()
                return
            }

            guard !SessionTemporaryStorage.shared.ledger.hasEnded(pageShow.confirmedEpoch) else {
                Logger.common(message: "[EmbeddedBlock] Block '\(self.placeSystemName)': the page never confirmed the data push of a session that has ended — keeping it until the current session answers",
                              category: .embeddedBlocks)
                return
            }

            Logger.common(message: "[EmbeddedBlock] Block '\(self.placeSystemName)': the page never confirmed the data push — rebuilding it",
                          level: .error, category: .embeddedBlocks)
            self.buildPage(with: content, sessionEpoch: pageShow.confirmedEpoch, processingDuration: pageShow.processingDurationOfARebuild)
        }
    }

    // MARK: - The page's reports

    private func settle(_ newOutcome: EmbeddedBlockState, isUserLeaving: Bool = false) {
        outcome = newOutcome

        if !isAttemptAlive {
            registry.blockAttemptEnded(placeSystemName)
        }

        guard isStarted || isUserLeaving else { return }

        report(newOutcome)
    }

    func handleLoadFailure(_ details: String) {
        fail(.webviewLoadFailed, details)
    }

    func failSilentPage() {
        fail(.presentationFailed, "Page did not send contentRendered within \(Constants.EmbeddedBlock.readyTimeoutSeconds)s")
        abandonAttempt()
    }

    func failUnanswered(waited: TimeInterval) {
        failures.reportUnansweredWaitOnce(waited)
        settle(.failed(MindboxEmbeddedBlockFailReason(.waitBudgetExceeded)))
        abandonAttempt()
    }

    private func fail(_ reason: InAppShowFailureReason, _ details: String) {
        deferred.lift()
        settle(.failed(MindboxEmbeddedBlockFailReason(reason)))

        guard let content = content else { return }

        failures.report(EmbeddedBlockResolutionFailure(inAppId: content.inAppId, tags: content.tags, reason: reason, details: details),
                        isBlockOnScreen: isStarted)
    }

    var isAttemptAlive: Bool {
        outcome == .loading || outcome == .ready
    }

    private func applyContentRendered(_ renderedCount: Int) {
        guard !didReportShownContent else {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': the page reported itself again with nothing asked of it — ignoring",
                          category: .embeddedBlocks)
            return
        }

        guard renderedCount > 0 else {
            guard isStarted || isStartPending, isReady, !isCoveredForTheSession else {
                Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': page rendered nothing", category: .embeddedBlocks)
                if isCoveredForTheSession { dropPage() }
                settle(.empty)
                return
            }

            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': page rendered nothing while its content is on screen — keeping it until the user leaves", category: .embeddedBlocks)
            deferred.holdEmptyPage()
            return
        }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': page rendered \(renderedCount) item(s)", category: .embeddedBlocks)
        deferred.liftEmptyPage()
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
        fail(.presentationFailed, "Page sent contentRendered with an invalid count")
    }

    private func accountForShow() {
        guard isStarted, isReady, !deferred.isShowWithheld, appPresence.isPresent, let content,
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

extension EmbeddedBlockWebViewProvider: EmbeddedBlockAppPresenceSubscribing {

    func appDidEnterBackground() { hasStartedSinceTheBackground = false }

    func sessionCheckEndedWhileNotActive() { if deferred.isStartAwaitingSessionCheck { start() } }

    func userReturned() {
        guard outcome.isFailed, !hasStartedSinceTheBackground, isOnScreen() else { return }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': back from the background with its attempt failed and nothing started since — starting it again", category: .embeddedBlocks)
        isStarted = false
        start()
    }

    func userDidBecomePresent() {
        if deferred.isStartAwaitingSessionCheck {
            start()
        }

        guard isStarted else { return }

        deferred.contentAwaitingTheUser = nil
        dataPushWait.resumeIfSuspended()
        catchUpShownPage()
    }
}
