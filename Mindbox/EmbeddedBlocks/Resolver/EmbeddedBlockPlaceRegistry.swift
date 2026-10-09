//
//  EmbeddedBlockPlaceRegistry.swift
//  Mindbox
//
//  Created by Sergei Semko on 14.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import QuartzCore
import MindboxLogger

/// The place map and the router between blocks and the selection — in sync with Android, where the
/// same component carries the same name and rules.
final class EmbeddedBlockPlaceRegistry: EmbeddedBlockPlaceRegistering {

    typealias EmbeddedPlacesFetching = (@escaping ([String: Set<String>]?) -> Void) -> Void

    private struct WeakBlock {
        weak var block: EmbeddedBlockPlaceHandling?
    }

    private var blocksByPlace: [String: [WeakBlock]] = [:]
    private var resolvingPlaces: Set<String> = []
    private var queuedInvalidations: [String: QueuedInvalidation] = [:]

    /// A block came back while its place's pass flew: that pass answers the appearance too.
    private var placesAppearedMidResolve: Set<String> = []

    /// When a block last came on screen at the place: a pass asked while nobody looked times its show from there.
    private var appearedAt: [String: TimeInterval] = [:]

    /// `nil` until a config has been seen: gating on an empty map before that would silently drop
    /// operations whose resolve would simply have waited for the config.
    private var embeddedPlacesInConfig: [String: Set<String>]?

    /// The session of the newest concluded download: a download a later one superseded is not announced.
    private var concludedSessionEpoch: Int?

    /// Content answered between a return and the end of its session check, the newest per place: it may be of
    /// the session the check is ending, so it is handled once the user is present again.
    private var contentAwaitingTheSessionCheck: [String: EmbeddedBlockPlaceAnswer] = [:]

    private let resolver: EmbeddedBlockResolving
    private let budget: InappShowBudgeting
    private let fetchEmbeddedPlaces: EmbeddedPlacesFetching
    private let notificationCenter: NotificationCenter
    private let delayedDelivery: EmbeddedBlockDelayedDelivery<EmbeddedBlockPlaceAnswer>
    private let presence: EmbeddedBlockAppPresence
    private let now: () -> TimeInterval

    private var observers: [NSObjectProtocol] = []

    init(resolver: EmbeddedBlockResolving,
         budget: InappShowBudgeting,
         notificationCenter: NotificationCenter = .default,
         fetchEmbeddedPlaces: @escaping EmbeddedPlacesFetching = EmbeddedBlockPlaceRegistry.fetchPlacesFromConfig,
         presence: EmbeddedBlockAppPresence = .shared,
         delayedDelivery: EmbeddedBlockDelayedDelivery<EmbeddedBlockPlaceAnswer> = EmbeddedBlockDelayedDelivery(),
         now: @escaping () -> TimeInterval = { CACurrentMediaTime() }) {
        self.resolver = resolver
        self.budget = budget
        self.notificationCenter = notificationCenter
        self.fetchEmbeddedPlaces = fetchEmbeddedPlaces
        self.presence = presence
        self.delayedDelivery = delayedDelivery
        self.now = now

        presence.subscribe(self)

        // The registry is created lazily, with the first block — a config may already be in memory,
        // and its notification is not coming again.
        refreshEmbeddedPlaces()

        // Every download's end, a failed one included: a new session re-checks its live blocks even
        // offline, against the cached config. Heard on the config queue and hopped, so it never waits for main.
        observers.append(notificationCenter.addObserver(forName: .mobileConfigDownloadConcluded,
                                                        object: nil,
                                                        queue: nil) { [weak self] notification in
            let sessionEpoch = notification.userInfo?[Constants.Notification.sessionEpoch] as? Int
            self?.onMain { $0.configConcluded(sessionEpoch: sessionEpoch) }
        })

        observers.append(notificationCenter.addObserver(forName: .inappSessionChecked,
                                                        object: nil,
                                                        queue: .main) { [weak self] notification in
            guard notification.userInfo?[Constants.Notification.startsNewSession] as? Bool == true else { return }

            self?.sessionStarted()
        })

        observers.append(notificationCenter.addObserver(forName: .inAppOperationOccurred,
                                                        object: nil,
                                                        queue: .main) { [weak self] notification in
            guard let event = notification.object as? ApplicationEvent else { return }

            self?.operationOccurred(event)
        })
    }

    deinit {
        observers.forEach { notificationCenter.removeObserver($0) }
    }

    // MARK: - Blocks

    func register(_ block: EmbeddedBlockPlaceHandling, place: String) {
        let weakBlock = WeakBlock(block: block)
        onMain {
            $0.prune(place)
            $0.blocksByPlace[place, default: []].append(weakBlock)
            $0.warnIfPlaceIsShared(place)
        }
    }

    private func onMain(_ work: @escaping (EmbeddedBlockPlaceRegistry) -> Void) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }

                work(self)
            }
            return
        }

        work(self)
    }

    private func warnIfPlaceIsShared(_ place: String) {
        let count = blocksByPlace[place]?.count ?? 0

        guard count > 1 else { return }

        Logger.common(message: """
        [EmbeddedBlock] \(count) live blocks share place '\(place)'. They show the same content, \
        each rendered on its own. If that is unexpected, check that a reusable cell is not carrying \
        a block container from another row: a block is created for one place and cannot be repointed.
        """, category: .embeddedBlocks)
    }

    func blockAppeared(_ place: String) {
        onMain {
            $0.appearedAt[place] = $0.now()
            $0.requestResolve(place: place, cause: .blockAppeared)
        }
    }

    func blockAttemptEnded(_ place: String) {
        onMain { $0.releaseSlotIfUnclaimed(place) }
    }

    func keepsContent(for place: String) -> Bool {
        contentAwaitingTheSessionCheck[place] != nil
    }

    func bringOnScreen(_ answer: EmbeddedBlockPlaceAnswer, at place: String) -> EmbeddedBlockPlaceAnswer? {
        guard answer.isAskedOffScreen, let content = answer.resolution.content else { return answer }

        let shownFromNow = answer.shownFromNow()
        switch inItsSession(answer, { $0.placeShownInappId[place] == content.inAppId }) {
        case nil: return nil
        case true?: return shownFromNow
        case false?: return slotted(content, of: shownFromNow, at: place)
        }
    }

    // MARK: - Channels

    private func configConcluded(sessionEpoch: Int?) {
        concludedSessionEpoch = sessionEpoch
        refreshEmbeddedPlaces()

        for place in placesWithActiveBlocks() {
            requestResolve(place: place, cause: .newConfig)
        }
    }

    /// Asked at the reset, not at the new config: a block on screen times the new session's show from here,
    /// and its selection waits for that session's config.
    private func sessionStarted() {
        for place in Array(blocksByPlace.keys) where hasActiveBlocks(place) || holdsAnAttempt(at: place) {
            requestResolve(place: place, cause: .newSession)
        }
    }

    /// Gated twice, in sync with Android: the place must be in the config, and some in-app of the
    /// place must listen to this operation.
    private func operationOccurred(_ event: ApplicationEvent) {
        let operationName = event.name.lowercased()

        for place in placesWithActiveBlocks() {
            if let known = embeddedPlacesInConfig {
                guard let operations = known[place] else {
                    Logger.common(message: "[EmbeddedBlock] Operation '\(event.name)': the config addresses no embedded in-app to place '\(place)', not resolving",
                                  level: .debug, category: .embeddedBlocks)
                    continue
                }

                guard operations.contains(operationName) else {
                    Logger.common(message: "[EmbeddedBlock] Operation '\(event.name)': no in-app of place '\(place)' listens to it, not resolving",
                                  level: .debug, category: .embeddedBlocks)
                    continue
                }
            }

            requestResolve(place: place, cause: .operation(event))
        }
    }

    // MARK: - The place slot

    /// One live resolve per place: an invalidation landing mid-flight is queued — the in-flight
    /// pass may be reading the config it is about — and runs right after. Only the newest trigger
    /// survives that wait: the place would end up on it anyway, but an in-app targeted at nothing
    /// but a dropped operation never speaks its own `Inapp.Targeting`.
    private func requestResolve(place: String, cause: ResolveCause) {
        prune(place)
        let isOffScreen = !hasActiveBlocks(place)

        guard !isOffScreen || cause.reachesOffScreen && holdsAnAttempt(at: place) else {
            Logger.common(message: "[EmbeddedBlock] Place '\(place)': \(cause.logDescription), but no block is on screen — nowhere to draw, the next start() re-asks",
                          category: .embeddedBlocks)
            return
        }

        guard !resolvingPlaces.contains(place) else {
            guard cause.queuesWhenBusy else {
                placesAppearedMidResolve.insert(place)
                Logger.common(message: "[EmbeddedBlock] Place '\(place)': \(cause.logDescription) while a resolve is in flight — its answer covers this too",
                              category: .embeddedBlocks)
                return
            }

            let queued = queuedInvalidations[place]
            let newSessionAskedAt: TimeInterval?
            if case .newSession = cause {
                newSessionAskedAt = now()
            } else {
                newSessionAskedAt = cause.newSessionAskedAt
            }
            queuedInvalidations[place] = QueuedInvalidation(trigger: cause.trigger ?? queued?.trigger,
                                                            includesNonOperation: cause.includesNonOperation || queued?.includesNonOperation == true,
                                                            newSessionAskedAt: [queued?.newSessionAskedAt, newSessionAskedAt].compactMap { $0 }.min(),
                                                            isAskedOffScreen: isOffScreen || queued?.isAskedOffScreen == true)

            Logger.common(message: "[EmbeddedBlock] Place '\(place)': \(cause.logDescription) landed mid-resolve — queued for the pass after",
                          category: .embeddedBlocks)
            return
        }

        resolvingPlaces.insert(place)
        let waitedForThePassInFlight = cause.newSessionAskedAt.map { now() - $0 } ?? 0
        let isAskedOffScreen = isOffScreen || cause.wasQueuedOffScreen

        resolver.resolve(place, trigger: cause.trigger) { [weak self] resolution, processingDuration, sessionEpoch in
            guard let self else { return }

            self.resolvingPlaces.remove(place)
            let appearedMidResolve = self.placesAppearedMidResolve.remove(place) != nil
            let processed = waitedForThePassInFlight + processingDuration
            self.handle(EmbeddedBlockPlaceAnswer(resolution: resolution,
                                                 processingDuration: isAskedOffScreen ? self.sinceTheReturn(to: place, atMost: processed) : processed,
                                                 sessionEpoch: sessionEpoch,
                                                 isOperationTriggered: !cause.includesNonOperation && !appearedMidResolve,
                                                 isAskedOffScreen: isAskedOffScreen),
                        at: place)

            if let queued = self.queuedInvalidations.removeValue(forKey: place) {
                self.requestResolve(place: place, cause: .queued(queued))
            } else if let concluded = self.concludedSessionEpoch, sessionEpoch < concluded {
                // A stale answer is dropped, and a return it absorbed would go unanswered: asked again, which does
                // nothing while no block shows the place.
                Logger.common(message: "[EmbeddedBlock] Place '\(place)': answered from an earlier session's config — asking again",
                              category: .embeddedBlocks)
                self.requestResolve(place: place, cause: .queued(QueuedInvalidation(trigger: nil, includesNonOperation: true)))
            }
        }
    }

    private func sinceTheReturn(to place: String, atMost processed: TimeInterval) -> TimeInterval {
        appearedAt[place].map { min(processed, now() - $0) } ?? processed
    }

    /// A winner with `delayTime` waits like an overlay in the schedule queue and the blocks stand their wait
    /// budget down. A delay served once in the session is not waited again: a block coming back gets the content at once.
    ///
    /// An answer of a session that has ended touches nothing in the current one — no delivery, slot or delay. The
    /// new session's answer comes from the reset's re-ask, its download's pass or the next `start()`.
    private func handle(_ answer: EmbeddedBlockPlaceAnswer, at place: String) {
        guard let content = answer.resolution.content else {
            guard inItsSession(answer, { _ in }) != nil else {
                dropStale(answer, at: place)
                return
            }

            contentAwaitingTheSessionCheck[place] = nil
            budget.release(.place(place), inSession: answer.sessionEpoch)
            delayedDelivery.cancel(place: place)
            deliver(answer, at: place)
            return
        }

        // Before the delay bookkeeping: a stale answer must not cancel or announce this session's delay.
        guard !SessionTemporaryStorage.shared.ledger.hasEnded(answer.sessionEpoch) else {
            dropStale(answer, at: place)
            return
        }

        guard !keepsForTheSessionCheck(answer, at: place) else { return }

        let winner = EmbeddedBlockDelayedWinner(inappId: content.inAppId, sessionEpoch: answer.sessionEpoch)
        if delayedDelivery.isWaiting(place: place, for: winner) {
            Logger.common(message: "[EmbeddedBlock] Place '\(place)': in-app \(content.inAppId) is still waiting out its delay",
                          category: .embeddedBlocks)
            delayedDelivery.refresh(place: place, answer: answer)
            announceDelay(at: place)
            return
        }

        delayedDelivery.cancel(place: place)

        let delay = TimeInterval.delay(fromTimeSpan: content.delayTime)
        let served = ServedPlaceDelay(place: place, inappId: content.inAppId)
        // Read here, marked in the hold that takes the slot once the delay runs out: a reset in between
        // takes the mark's session with it, and that hold refuses the answer.
        guard delay > 0, !SessionTemporaryStorage.shared.ledger.servedPlaceDelays.contains(served) else {
            deliverContent(content, of: answer, at: place)
            return
        }

        Logger.common(message: "[EmbeddedBlock] Place '\(place)': in-app \(content.inAppId) waits \(delay)s before it is shown",
                      category: .embeddedBlocks)
        announceDelay(at: place)

        delayedDelivery.schedule(place: place, winner: winner, answer: answer, after: delay) { [weak self] answer in
            guard let content = answer.resolution.content else { return }

            self?.deliverContent(content, of: answer, at: place, servingDelay: served)
        }
    }

    /// The slot is taken here, at the last point before a page is built, so a budget spent meanwhile costs no page load.
    private func deliverContent(_ content: EmbeddedBlockWebContent,
                                of answer: EmbeddedBlockPlaceAnswer,
                                at place: String,
                                servingDelay served: ServedPlaceDelay? = nil) {
        let isShownAlready = inItsSession(answer) { ledger -> Bool in
            if let served {
                ledger.servedPlaceDelays.insert(served)
            }

            return ledger.placeShownInappId[place] == content.inAppId
        }

        switch isShownAlready {
        case nil:
            dropStale(answer, at: place)
        case true?:
            deliver(answer, at: place)
            releaseSlotIfUnclaimed(place)
        case false? where answer.isAskedOffScreen && !hasActiveBlocks(place):
            Logger.common(message: "[EmbeddedBlock] Place '\(place)': in-app \(content.inAppId) answered while no block shows the place — its slot waits for a block back on screen",
                          category: .embeddedBlocks)
            deliver(answer, at: place)
        case false?:
            reserveSlot(for: content, of: answer, at: place)
        }
    }

    private func reserveSlot(for content: EmbeddedBlockWebContent, of answer: EmbeddedBlockPlaceAnswer, at place: String) {
        guard let slotted = slotted(content, of: answer, at: place) else {
            dropStale(answer, at: place)
            return
        }

        deliver(slotted, at: place)
        if slotted.resolution.content != nil {
            releaseSlotIfUnclaimed(place)
        }
    }

    /// The answer as it is, or empty when the show budgets are spent; `nil` when its session has ended.
    private func slotted(_ content: EmbeddedBlockWebContent, of answer: EmbeddedBlockPlaceAnswer, at place: String) -> EmbeddedBlockPlaceAnswer? {
        switch budget.reserve(.place(place), inAppId: content.inAppId, isPriority: content.isPriority, frequency: content.frequency, inSession: answer.sessionEpoch) {
        case nil:
            return nil
        case .refused?:
            Logger.common(message: "[EmbeddedBlock] Place '\(place)': in-app \(content.inAppId) won it, but the show budgets are spent — the place stays empty",
                          category: .embeddedBlocks)
            return answer.with(.empty)
        case .granted?, .notNeeded?:
            return answer
        }
    }

    /// The session check and the ledger work it guards are one hold, so a reset on another thread cannot land
    /// between them. `nil` when the answer is of a session that has ended.
    private func inItsSession<Value>(_ answer: EmbeddedBlockPlaceAnswer, _ work: (inout InappSessionLedger) -> Value) -> Value? {
        SessionTemporaryStorage.shared.$ledger.mutate { ledger in
            ledger.hasEnded(answer.sessionEpoch) ? nil : work(&ledger)
        }
    }

    /// A block on screen gets no page built from the session a return's check may be ending; a place already
    /// keeping one keeps the newest, so a later answer is never overtaken by an earlier one.
    private func keepsForTheSessionCheck(_ answer: EmbeddedBlockPlaceAnswer, at place: String) -> Bool {
        guard contentAwaitingTheSessionCheck[place] != nil || (presence.isAwaitingSessionCheck && hasActiveBlocks(place)) else {
            return false
        }

        Logger.common(message: "[EmbeddedBlock] Place '\(place)': content arrived before the return's session check ended — kept until it has",
                      category: .embeddedBlocks)
        contentAwaitingTheSessionCheck[place] = answer
        blocksByPlace[place]?.forEach { $0.block?.contentIsKept() }
        return true
    }

    private func dropStale(_ answer: EmbeddedBlockPlaceAnswer, at place: String) {
        Logger.common(message: "[EmbeddedBlock] Place '\(place)': an answer of a session that has ended or is ending (\(answer.sessionEpoch)) — dropped, the current session answers anew",
                      category: .embeddedBlocks)
    }

    private func releaseSlotIfUnclaimed(_ place: String) {
        prune(place)

        guard !holdsAnAttempt(at: place) else { return }

        budget.release(.place(place))
    }

    private func announceDelay(at place: String) {
        for weakBlock in blocksByPlace[place] ?? [] {
            weakBlock.block?.contentIsDelayed()
        }
    }

    private func deliver(_ answer: EmbeddedBlockPlaceAnswer, at place: String) {
        for weakBlock in blocksByPlace[place] ?? [] {
            weakBlock.block?.apply(answer)
        }
    }

    // MARK: - Housekeeping

    private func refreshEmbeddedPlaces() {
        embeddedPlacesInConfig = nil

        fetchEmbeddedPlaces { [weak self] places in
            guard let self else { return }

            guard Thread.isMainThread else {
                DispatchQueue.main.async { self.embeddedPlacesInConfig = places }
                return
            }

            self.embeddedPlacesInConfig = places
        }
    }

    private func hasActiveBlocks(_ place: String) -> Bool {
        (blocksByPlace[place] ?? []).contains { $0.block?.isActive == true }
    }

    private func holdsAnAttempt(at place: String) -> Bool {
        (blocksByPlace[place] ?? []).contains { $0.block?.holdsAnAttempt == true }
    }

    private func placesWithActiveBlocks() -> [String] {
        blocksByPlace.keys.filter { hasActiveBlocks($0) }
    }

    private func prune(_ place: String) {
        let alive = (blocksByPlace[place] ?? []).filter { $0.block != nil }
        if alive.isEmpty {
            blocksByPlace.removeValue(forKey: place)
            appearedAt.removeValue(forKey: place)
        } else {
            blocksByPlace[place] = alive
        }
    }

    private static func fetchPlacesFromConfig(_ completion: @escaping ([String: Set<String>]?) -> Void) {
        guard let configurationManager = DI.inject(InAppConfigurationManagerProtocol.self) else {
            completion(nil)
            return
        }

        configurationManager.getEmbeddedPlaces(completion)
    }
}

// MARK: - The app's presence

extension EmbeddedBlockPlaceRegistry: EmbeddedBlockAppPresenceSubscribing {

    func userDidBecomePresent() {
        let kept = contentAwaitingTheSessionCheck
        contentAwaitingTheSessionCheck = [:]
        kept.forEach { place, answer in
            handle(answer, at: place)
            blocksByPlace[place]?.forEach { $0.block?.keptContentIsReleased() }
        }
    }
}
