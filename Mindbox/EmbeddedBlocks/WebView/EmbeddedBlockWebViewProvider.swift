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
/// The provider does not draw content and decides nothing about it: it registers with the place
/// registry, turns the answers the registry delivers into container states, and reports a drawn page
/// as a show. It never asks the selection itself — one resolve per place serves every block standing
/// on it.
///
/// An instance belongs to one container, so `start()` and `stop()` simply mirror its visibility
/// and can be called in cycles. After `stop()` the provider must stay silent until the next
/// `start()` — the container relies on this when it collapses an expired block.
final class EmbeddedBlockWebViewProvider {

    /// Reports every state change on the main thread. Set by the container.
    var onStateChange: ((EmbeddedBlockState) -> Void)?

    /// The place answered and a page is being built for it. The container needs the moment, not the
    /// content.
    var onContentArrived: (() -> Void)?

    var contentView: UIView? { isReady ? page?.view : nil }

    /// Whether the block is still waiting to learn what it shows at all — no page means no answer yet.
    /// The container reads this to know which of its two waits is running.
    var isAwaitingAnswer: Bool { page == nil }

    private let placeSystemName: String
    private let registry: EmbeddedBlockPlaceRegistering
    private let feed: EmbeddedBlockFeedServing
    private let makePage: (EmbeddedBlockWebContent) -> EmbeddedBlockPageHosting

    /// Handed in rather than resolved here: the block knows a page was drawn, not where a show is
    /// written down.
    private let recordShow: (String) -> Void

    /// Handed in for the same reason: the block knows a page was drawn, not what the backend is told
    /// about it.
    private let reportShow: (EmbeddedBlockWebContent, String) -> Void

    /// Handed in for the same reason: the block knows what went wrong, not where that goes.
    private let reportFailure: (EmbeddedBlockWebContent, InAppShowFailureReason, String) -> Void

    /// A page that has rendered survives restarts: the container starts and stops the block by
    /// visibility, and there is no reason to recreate the web view on every return to the window.
    /// A page that was stopped before it rendered does not survive — its web layer is closed for good,
    /// so `start()` drops it and the next answer builds a new one.
    private var page: EmbeddedBlockPageHosting?

    /// What the live page was built from. Kept so a delivered answer can be compared against it.
    private var content: EmbeddedBlockWebContent?

    private var isStarted = false

    /// How the current attempt is going, `.loading` until it ends.
    ///
    /// Survives `stop()`: it is a property of the page, not of being in the window. A failure and
    /// `empty` do not kill the page — it is alive and can keep talking.
    private var outcome: EmbeddedBlockState = .loading

    private var isReady: Bool { outcome == .ready }

    /// The number of the current load attempt. A feed's answer may arrive after `stop()` or after
    /// the page was replaced — the number shows that the answer belongs to a past attempt and must
    /// be thrown away.
    private var loadGeneration = 0

    /// Whether the show of the page standing right now has been accounted for. One page is one show:
    /// a page re-reporting itself after new data is the same show, and a page shown again on the way
    /// back into the window was counted when it was drawn.
    private var didAccountForShow = false

    /// How long the user has been waiting for the current attempt. Armed when the block starts
    /// waiting, read when the page reports what it drew. Foreground-only, like the overlay's.
    private var attemptStopwatch = ForegroundStopwatch()

    /// Runs the work when the wait for a data push's confirmation expires. Injected so tests do not
    /// wait it out in real time.
    private let scheduleAckTimeout: EmbeddedBlockWaitScheduling

    /// The wait for the page to confirm the `initDataUpdated` it was just sent. `nil` — nothing is
    /// pending.
    private var dataPushAck: DispatchWorkItem?

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
        // Above the early return below: the block is back in the window, whatever it takes to show
        // it. Restored only on the reloading path, a page shown again from cache would stay marked
        // invisible for the rest of its life — silently refusing every link the user taps on it.
        page?.isUserPresent = true

        // A rendered page is shown as is, with no network and no shimmer, but the pull below still
        // runs: the world may have changed while the block was off screen, and an unchanged answer is
        // deduplicated in `apply`.
        if isReady, page != nil {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': showing the page rendered earlier",
                          category: .embeddedBlocks)
            onStateChange?(.ready)
            registry.blockAppeared(placeSystemName)
            return
        }

        beginAttempt()
    }

    func stop() {
        guard isStarted else { return }

        isStarted = false
        // The outcome is deliberately not reset: otherwise every pass of the block across the screen
        // would cost a full reload.
        loadGeneration += 1
        // A stopped provider stays silent, so a push it was waiting on stops being its business:
        // the next start() pulls the place from scratch anyway.
        cancelDataPushAck()
        // The page stays alive off screen, so it has to be told that nobody is looking.
        page?.isUserPresent = false

        // `cancel()` closes the web layer for good, so a rendered page is left alone: cancelling it
        // would leave the block showing a page that can no longer hear `initDataUpdated`.
        if !isReady {
            page?.cancel()
        }
    }

    /// Starts the load from scratch: a moved or disabled block must not keep showing its previous
    /// content. A reload always leaves the block running, whether or not it was.
    func reload() {
        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)' is reloading", category: .embeddedBlocks)

        dropPage()
        loadGeneration += 1
        isStarted = true

        beginAttempt()
    }

    /// A fresh attempt: the shimmer, no outcome yet, and a pull of the place.
    ///
    /// A page left over from the previous attempt is dropped rather than resumed: `stop()` closed its
    /// web layer for good, so asking it to load again would fetch the markup and quietly discard it —
    /// the page would stay silent until the container's waiting budget collapsed the block.
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

    /// What the place resolves to now — the one entry point for pull, a new config and an operation
    /// alike. Who asked and why is the registry's business.
    func apply(_ resolution: EmbeddedBlockResolution) {
        // A stopped block ignores deliveries addressed to its still-active neighbors: outside the
        // window it pulls from scratch when it comes back.
        guard isStarted else { return }

        switch resolution {
        case .empty:
            // Repeated "nothing" is one state, not two.
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

        // A different in-app, or the same one pointing somewhere else: its start payload would be
        // built around the wrong in-app id, so the page is replaced rather than told. The same path
        // builds the very first page and revives a failed one, which is why the log tells them apart.
        let reason = page == nil ? "building its page" : "the place points at another page — rebuilding it"
        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': \(reason)", category: .embeddedBlocks)
        buildPage(with: fresh)
    }

    private func buildPage(with fresh: EmbeddedBlockWebContent) {
        dropPage()

        // The first content of an attempt lands into the `loading` the attempt already reported;
        // a revival or a replacement is a new attempt and says so — the shimmer comes back, so the
        // wait the show is measured against starts over too.
        if outcome != .loading {
            onStateChange?(.loading)
            attemptStopwatch = ForegroundStopwatch()
        }
        outcome = .loading
        loadGeneration += 1
        didAccountForShow = false

        let page = makePage(fresh)
        page.isUserPresent = true
        page.onContentRendered = { [weak self] count in
            self?.applyContentRendered(count)
        }
        page.onUnreadableContentReport = { [weak self] in
            self?.handleUnreadableContentReport()
        }
        page.onFeedQuestion = { [weak self] ids, completion in
            self?.answerTargeting(ids, completion: completion)
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

        // Announced only once the page exists: this is what flips `isAwaitingAnswer`, and with it the
        // wait the container is counting.
        onContentArrived?()

        page.load()
    }

    /// The previous page is no longer relevant — detach it from us first so that its late
    /// messages do not end up in the new attempt.
    private func dropPage() {
        cancelDataPushAck()
        page?.onContentRendered = nil
        page?.onUnreadableContentReport = nil
        page?.onFeedQuestion = nil
        page?.onShowInAppRequest = nil
        page?.onDataPushConfirmed = nil
        page?.onLoadFailure = nil
        page?.cancel()
        page = nil
        content = nil
    }

    // MARK: - The data push's confirmation

    /// A pushed `initDataUpdated` is a promise the page has to keep: it answers the push and
    /// re-reports what it drew. A page that answers nothing within the page budget is treated the way
    /// Android treats it — rebuilt from scratch, because a feed silently showing yesterday's stories
    /// is the failure nobody files a report about.
    ///
    /// An error answer counts as silence: the web layer drops error envelopes before they reach the
    /// page, so the rebuild is the remedy either way.
    private func armDataPushAck() {
        cancelDataPushAck()

        let generation = loadGeneration
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.isStarted, self.loadGeneration == generation else { return }

            self.dataPushAck = nil

            guard let content = self.content else { return }

            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': the page never confirmed the data push — rebuilding it",
                          level: .error, category: .embeddedBlocks)
            self.buildPage(with: content)
        }

        dataPushAck = work
        scheduleAckTimeout(TimeInterval(Constants.EmbeddedBlock.readyTimeoutSeconds), work)
    }

    private func cancelDataPushAck() {
        dataPushAck?.cancel()
        dataPushAck = nil
    }

    /// The page confirmed our push, through the same door its own requests come in.
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

    func handleLoadFailure() {
        guard isStarted else { return }

        outcome = .failed
        onStateChange?(.failed)
        report(.webviewLoadFailed, "The block's page failed to load")
    }

    /// The container gave up on a page that was built and never reported itself. Called from there
    /// because the patience belongs to the container; what the failure is about belongs here.
    func reportPageTimedOut() {
        report(.presentationFailed, "The block's page did not report itself in time")
    }

    /// A failure belongs to the in-app the block was given: before the place answers, there is nothing
    /// to blame.
    private func report(_ reason: InAppShowFailureReason, _ details: String) {
        guard let content = content else { return }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': reporting \(reason.rawValue) for in-app \(content.inAppId)",
                      level: .error, category: .embeddedBlocks)
        reportFailure(content, reason, details)
    }

    /// Whether the current attempt is still the one on screen: loading, or drawn and shown.
    private var isAttemptAlive: Bool {
        outcome == .loading || outcome == .ready
    }

    /// The params the page hands over travel into the shown in-app's start payload untouched: for the
    /// SDK they are an opaque dictionary, so a page that later carries more context needs no change
    /// here.
    ///
    /// A page whose block has collapsed or failed is still alive and keeps working — delivering
    /// what its `setTimeout` scheduled, for one. Showing an in-app on its behalf must not work: no
    /// user touch stands behind it, and the in-app would appear over the app out of nowhere.
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
    private func answerTargeting(_ ids: [String], completion: @escaping ([String]) -> Void) {
        guard isStarted else { return }

        let generation = loadGeneration
        feed.renderableInappIds(among: ids) { [weak self] answer in
            // The answer may arrive after the block was stopped or reloaded, and an answer nobody
            // receives has offered nothing — so the vouching waits for this guard instead of happening
            // inside the selection.
            guard let self, self.isStarted, self.loadGeneration == generation else { return }

            completion(answer.inappIds)
            answer.vouch()
        }
    }

    /// `contentRendered` is the page's only statement about itself, and it carries how many items it
    /// drew. Zero — or below — is a valid outcome, not a failure.
    private func applyContentRendered(_ count: Int) {
        guard isStarted else { return }

        guard count > 0 else {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': page rendered nothing", category: .embeddedBlocks)
            outcome = .empty
            onStateChange?(.empty)
            return
        }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': page rendered \(count) item(s)", category: .embeddedBlocks)
        outcome = .ready
        onStateChange?(.ready)
        accountForShow()
    }

    /// An unreadable report is the other way round — nobody can say what is on screen, so the block
    /// collapses and is reported as broken.
    private func handleUnreadableContentReport() {
        guard isStarted else { return }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': contentRendered without a readable count, treating as broken",
                      level: .error, category: .embeddedBlocks)
        outcome = .failed
        onStateChange?(.failed)
        report(.presentationFailed, "The block's page reported contentRendered without a readable count")
    }

    /// A block that drew something has shown its in-app, and that means two separate things.
    ///
    /// The backend is told unconditionally: `Inapp.Show` says what the user saw, and how often this
    /// in-app is allowed to appear has no bearing on whether it just did. The local history is the
    /// other way round — it exists for the frequency to read next time, so it is written only when the
    /// frequency counts shows at all (`InappFrequency.countsShows`). The overlay path splits the two
    /// the same way; a block that only wrote the history would be invisible in the funnel, because
    /// blocks arrive `unlimited` by contract and that half writes nothing.
    ///
    /// The moment is the page's own report rather than the resolve: an in-app the block never managed
    /// to draw was never shown, and a page that failed must not spend its only `once`.
    ///
    /// The cooldown between overlay shows is deliberately left alone: it measures how often the SDK
    /// interrupts on its own, and a block interrupts nothing — it is drawn where the app put it.
    private func accountForShow() {
        guard let content = content, !didAccountForShow else { return }

        didAccountForShow = true

        // Everything the user waited through, which is what the overlay's number covers too: the place
        // had to answer, then the page had to load, boot and run its own pipeline before it could draw.
        let timeToDisplay = attemptStopwatch.elapsed.toTimeSpan()
        attemptStopwatch.stop()

        // The event is deduplicated per session by the in-app, in sync with Android: a page rebuilt
        // within a session re-draws what the user already saw. A different in-app winning the place
        // has its own id and reports itself.
        if SessionTemporaryStorage.shared.blockShowsReportedInSession.contains(content.inAppId) {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': in-app \(content.inAppId) is shown again this session — the event was already reported",
                          category: .embeddedBlocks)
        } else {
            SessionTemporaryStorage.shared.blockShowsReportedInSession.insert(content.inAppId)
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
