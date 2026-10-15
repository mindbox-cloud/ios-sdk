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
    private var resolvingPlaces: [String: PassInFlight] = [:]
    private var answeredPasses: [String: AnsweredPass] = [:]
    private var queuedInvalidations: [String: QueuedInvalidation] = [:]

    /// `nil` until a config has been seen: gating on an empty map before that would silently drop
    /// operations whose resolve would simply have waited for the config.
    private var embeddedPlacesInConfig: [String: Set<String>]?

    private var newestConfigVersion: ConfigVersion?

    private var awaitingTheSessionCheck = AwaitingTheSessionCheck()

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

        observers.append(notificationCenter.addObserver(forName: .mobileConfigDownloadConcluded,
                                                        object: nil,
                                                        queue: nil) { [weak self] notification in
            guard let version = notification.userInfo?[Constants.Notification.configVersion] as? ConfigVersion else { return }

            self?.onMain { $0.configConcluded(version) }
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
        onMain { $0.requestResolve(place: place, cause: .blockAppeared) }
    }

    func blockAttemptEnded(_ place: String) {
        onMain { $0.releaseSlotIfUnclaimed(place) }
    }

    func giveSlotBack(_ unseen: EmbeddedBlockPlaceAnswer, at place: String) {
        onMain { $0.releaseSlotOfUnseen(unseen, at: place) }
    }

    func keepsContent(for place: String) -> Bool {
        awaitingTheSessionCheck.content[place] != nil
    }

    func bringOnScreen(_ answer: EmbeddedBlockPlaceAnswer, at place: String) -> EmbeddedBlockPlaceAnswer? {
        guard let content = answer.resolution.content else { return answer }

        switch SessionTemporaryStorage.shared.$ledger.withinLiveSession(answer.sessionEpoch, { $0.placeShownInappId[place] == content.inAppId }) {
        case nil: return nil
        case true?: return answer
        case false?: return slotted(content, of: answer, at: place)
        }
    }

    // MARK: - Channels

    private func configConcluded(_ version: ConfigVersion) {
        newestConfigVersion = max(newestConfigVersion ?? version, version)
        refreshEmbeddedPlaces()
        resolvingPlaces.values.forEach { $0.isConfigAnnouncedMidResolve = true }

        for place in placesWithActiveBlocks() {
            if resolvingPlaces[place] != nil {
                Logger.common(message: "[EmbeddedBlock] Place '\(place)': config \(version) arrived while its pass is in flight — that pass answers from it or is asked again when it lands",
                              category: .embeddedBlocks)
            } else if let answeredFrom = answeredPasses[place]?.configVersion, answeredFrom >= version {
                Logger.common(message: "[EmbeddedBlock] Place '\(place)': already answered from config \(version) — not asking again",
                              category: .embeddedBlocks)
            } else {
                requestResolve(place: place, cause: .newConfig)
            }
        }
    }

    private func sessionStarted(carrying operations: [String: [ApplicationEvent]]) {
        let sessionEpoch = SessionTemporaryStorage.shared.ledger.sessionEpoch
        for place in Array(blocksByPlace.keys) where hasActiveBlocks(place) || holdsAnAttempt(at: place) {
            guard operations[place] != nil || !isAnsweredInNewSession(place, sessionEpoch) else {
                Logger.common(message: "[EmbeddedBlock] Place '\(place)': a new session, and its pass in flight or its last answer was asked in it with no operation — its answer is the new session's",
                              category: .embeddedBlocks)
                continue
            }

            requestResolve(place: place, cause: .newSession(operations[place]?.first))
            operations[place]?.dropFirst().forEach { requestResolve(place: place, cause: .operation($0)) }
        }
    }

    private func isAnsweredInNewSession(_ place: String, _ sessionEpoch: Int) -> Bool {
        resolvingPlaces[place]?.standsInForTheAsk(of: sessionEpoch) ?? answeredPasses[place]?.standsForTheAsk(of: sessionEpoch) ?? false
    }

    /// Gated twice, in sync with Android: the place must be in the config, and some in-app of the
    /// place must listen to this operation.
    private func operationOccurred(_ event: ApplicationEvent) {
        let operationName = event.name.lowercased()

        for place in placesWithBlocksOnScreen() {
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

            guard !presence.isAwaitingSessionCheck else {
                Logger.common(message: "[EmbeddedBlock] Operation '\(event.name)' arrived during the return's session check — held for place '\(place)' and asked with it once the check ends, if a block is still there",
                              category: .embeddedBlocks)
                awaitingTheSessionCheck.hold(event, at: place)
                continue
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

        guard !isOffScreen || cause.isNewSessionAsk && holdsAnAttempt(at: place) else {
            Logger.common(message: "[EmbeddedBlock] Place '\(place)': \(cause.logDescription), but no block of the place is started — nowhere to draw, the next start() re-asks",
                          category: .embeddedBlocks)
            return
        }

        if let passInFlight = resolvingPlaces[place] {
            guard cause.queuesWhenBusy else {
                passInFlight.isAskedAgainMidResolve = true
                Logger.common(message: "[EmbeddedBlock] Place '\(place)': \(cause.logDescription) while a resolve is in flight — its answer covers this too",
                              category: .embeddedBlocks)
                return
            }

            queuedInvalidations[place] = QueuedInvalidation(merging: cause, into: queuedInvalidations[place], now: now)

            Logger.common(message: "[EmbeddedBlock] Place '\(place)': \(cause.logDescription) landed mid-resolve — queued for the pass after",
                          category: .embeddedBlocks)
            return
        }

        let pass = PassInFlight(askedInSession: SessionTemporaryStorage.shared.ledger.sessionEpoch, isTriggered: cause.trigger != nil)
        resolvingPlaces[place] = pass
        let waitedForThePassInFlight = cause.newSessionAskedAt.map { now() - $0 } ?? 0

        resolver.resolve(place, trigger: cause.trigger) { [weak self] resolution, processingDuration, sessionEpoch, configVersion in
            guard let self else { return }

            self.resolvingPlaces[place] = nil
            let answer = EmbeddedBlockPlaceAnswer(resolution: resolution,
                                                  processingDuration: waitedForThePassInFlight + processingDuration,
                                                  sessionEpoch: sessionEpoch,
                                                  isOperationTriggered: !cause.includesNonOperation && !pass.isAskedAgainMidResolve)
            let renamed = self.asTheQueuedNewSessionAsk(answer, of: pass, at: place)
            self.handle(renamed?.answer ?? answer, at: place, answeringTheQueuedAsk: renamed?.answersTheQueuedAsk == true, recording: pass.answered(from: configVersion))
            let isAnsweredFromAnOlderConfig = pass.isAnsweredFromConfig(configVersion, olderThan: self.newestConfigVersion)
            let isNewSessionLeftUnanswered = pass.leavesNewSessionUnanswered(answeredFrom: configVersion)
            let isAskedAgain = isAnsweredFromAnOlderConfig || isNewSessionLeftUnanswered

            if let queued = self.queuedInvalidations.removeValue(forKey: place) {
                self.requestResolve(place: place, cause: .queued(isAskedAgain ? QueuedInvalidation(merging: .newConfig, into: queued, now: self.now) : queued))
            } else if isAskedAgain {
                let reason = isNewSessionLeftUnanswered ? "its pass stood for the new session's ask and read no config"
                    : "answered from config \(configVersion?.description ?? "no config"), older than \(self.newestConfigVersion?.description ?? "none")"
                Logger.common(message: "[EmbeddedBlock] Place '\(place)': \(reason) — asking again", category: .embeddedBlocks)
                self.requestResolve(place: place, cause: .queued(QueuedInvalidation(trigger: nil, includesNonOperation: true)))
            }
        }
    }

    private func asTheQueuedNewSessionAsk(_ answer: EmbeddedBlockPlaceAnswer, of pass: PassInFlight, at place: String) -> (answer: EmbeddedBlockPlaceAnswer, answersTheQueuedAsk: Bool)? {
        guard answer.sessionEpoch > pass.askedInSession, let queued = queuedInvalidations[place], let newSessionAskedAt = queued.newSessionAskedAt else {
            return nil
        }

        return (EmbeddedBlockPlaceAnswer(resolution: answer.resolution,
                                         processingDuration: now() - newSessionAskedAt,
                                         sessionEpoch: answer.sessionEpoch,
                                         isOperationTriggered: false),
                !pass.isTriggered && queued.trigger == nil)
    }

    /// A winner with `delayTime` waits like an overlay in the schedule queue and the blocks stand their wait
    /// budget down. A delay served once in the session is not waited again: a block coming back gets the content at once.
    private func handle(_ answer: EmbeddedBlockPlaceAnswer, at place: String, answeringTheQueuedAsk: Bool = false, recording answered: AnsweredPass? = nil) {
        guard !SessionTemporaryStorage.shared.ledger.hasEnded(answer.sessionEpoch) else {
            dropStale(answer, at: place)
            return
        }

        if answeringTheQueuedAsk { queuedInvalidations[place] = nil }
        if let answered { answeredPasses[place] = answered }

        guard let content = answer.resolution.content else {
            awaitingTheSessionCheck.content[place] = nil
            budget.release(.place(place), inSession: answer.sessionEpoch)
            delayedDelivery.cancel(place: place)
            deliver(answer, at: place)
            return
        }

        let delay = TimeInterval.delay(fromTimeSpan: content.delayTime)
        let isWaitingOutItsDelay = delay > 0 && delayedDelivery.isWaiting(place: place, for: content.inAppId)
            && delayedDelivery.waitingAnswer(at: place)?.sessionEpoch == answer.sessionEpoch
        if !isWaitingOutItsDelay { delayedDelivery.cancel(place: place) }

        guard !keepsForTheSessionCheck(answer, at: place) else { return }

        // A fresh answer without a delay is not held back by the delay it used to have: nothing is
        // left to wait out, and the user waited for this very answer — it goes below, at once, with
        // its own selection time, as on Android.
        if isWaitingOutItsDelay {
            Logger.common(message: "[EmbeddedBlock] Place '\(place)': in-app \(content.inAppId) is still waiting out its delay",
                          category: .embeddedBlocks)
            // The fresh content, with the selection time of the answer that started the delay: this
            // pass ran inside the delay, which is not the user's waiting, so its own duration says
            // nothing about how long the user waited.
            delayedDelivery.refresh(place: place) { waiting in
                answer.replacing(waiting)
            }
            announceDelay(at: place)
            return
        }

        let served = ServedPlaceDelay(place: place, inappId: content.inAppId)
        guard delay > 0, !SessionTemporaryStorage.shared.ledger.servedPlaceDelays.contains(served) else {
            deliverContent(content, of: answer, at: place)
            return
        }

        Logger.common(message: "[EmbeddedBlock] Place '\(place)': in-app \(content.inAppId) waits \(delay)s before it is shown",
                      category: .embeddedBlocks)
        announceDelay(at: place)

        delayedDelivery.schedule(place: place, inappId: content.inAppId, answer: answer, after: delay) { [weak self] answer in
            guard let content = answer.resolution.content else { return }

            self?.deliverContent(content, of: answer, at: place, servingDelay: served)
        }
    }

    /// The slot is taken here, at the last point before a page is built, so a budget spent meanwhile costs no page load.
    private func deliverContent(_ content: EmbeddedBlockWebContent,
                                of answer: EmbeddedBlockPlaceAnswer,
                                at place: String,
                                servingDelay served: ServedPlaceDelay? = nil) {
        let isShownAlready = SessionTemporaryStorage.shared.$ledger.withinLiveSession(answer.sessionEpoch) { ledger -> Bool in
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
        case false? where !hasActiveBlocks(place):
            Logger.common(message: "[EmbeddedBlock] Place '\(place)': in-app \(content.inAppId) answered while no block of the place is started — handed over without a slot, taken when a block brings it on screen",
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

    private func keepsForTheSessionCheck(_ answer: EmbeddedBlockPlaceAnswer, at place: String) -> Bool {
        guard awaitingTheSessionCheck.content[place] != nil || (presence.isAwaitingSessionCheck && hasActiveBlocks(place)) else {
            return false
        }

        Logger.common(message: "[EmbeddedBlock] Place '\(place)': content kept until the return is over — its session check has ended and the app is active",
                      category: .embeddedBlocks)
        awaitingTheSessionCheck.keep(answer, at: place, now: now)
        blocksByPlace[place]?.forEach { $0.block?.contentIsKept() }
        return true
    }

    private func dropStale(_ answer: EmbeddedBlockPlaceAnswer, at place: String) {
        Logger.common(message: "[EmbeddedBlock] Place '\(place)': an answer of a session that has ended or is ending (\(answer.sessionEpoch)) — dropped, the current session answers anew",
                      category: .embeddedBlocks)
    }

    private func releaseSlotOfUnseen(_ unseen: EmbeddedBlockPlaceAnswer, at place: String) {
        prune(place)

        guard let content = unseen.resolution.content, !hasBlocksOnScreen(place),
              SessionTemporaryStorage.shared.$ledger.withinLiveSession(unseen.sessionEpoch, { $0.placeShownInappId[place] != content.inAppId }) == true else { return }

        Logger.common(message: "[EmbeddedBlock] Place '\(place)': in-app \(content.inAppId), answered while the app was away, left the screen unshown — giving its slot back until a block brings it on screen",
                      category: .embeddedBlocks)
        budget.release(.place(place), inSession: unseen.sessionEpoch)
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

    private func placesWithBlocksOnScreen() -> [String] {
        blocksByPlace.keys.filter { hasBlocksOnScreen($0) }
    }

    private func hasBlocksOnScreen(_ place: String) -> Bool {
        (blocksByPlace[place] ?? []).contains { $0.block?.isActive == true || $0.block?.isStartPending == true }
    }

    private func prune(_ place: String) {
        let alive = (blocksByPlace[place] ?? []).filter { $0.block != nil }
        if alive.isEmpty {
            blocksByPlace.removeValue(forKey: place)
            answeredPasses.removeValue(forKey: place)
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

extension EmbeddedBlockPlaceRegistry: EmbeddedBlockAppPresenceSubscribing {

    func sessionChecked(startedAt: TimeInterval?, startsNewSession: Bool) {
        guard startsNewSession || presence.answersTheReturn(checkStartedAt: startedAt) else { return }

        let operations = awaitingTheSessionCheck.takeOperations()

        guard startsNewSession else {
            operations.forEach { place, events in events.forEach { requestResolve(place: place, cause: .operation($0)) } }
            return
        }

        sessionStarted(carrying: operations)
    }

    func userDidBecomePresent() {
        awaitingTheSessionCheck.takeContentInKeptOrder().forEach { place, kept in
            handle(kept.answer.with(processingDuration: kept.answer.processingDuration + now() - kept.keptAt), at: place)
            blocksByPlace[place]?.forEach { $0.block?.keptContentIsReleased() }
        }
    }
}
