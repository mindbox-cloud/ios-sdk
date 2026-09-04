//
//  EmbeddedBlockPlaceRegistry.swift
//  Mindbox
//
//  Created by Sergei Semko on 14.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

protocol EmbeddedBlockPlaceHandling: AnyObject {

    var isActive: Bool { get }

    /// The place's fresh answer, on the main thread, with how long the selection worked on it.
    func apply(_ resolution: EmbeddedBlockResolution, processingDuration: TimeInterval)

    /// The place's answer is known and held back by its `delayTime`: content is coming, the SDK is not silent.
    func contentIsDelayed()

    /// Loading or showing, on screen or paused off it: the block still owes the place a show or a give-up.
    var holdsAnAttempt: Bool { get }
}

/// Called on the main thread: the registry's state is confined to it.
///
/// There is no `unregister`: blocks are held weakly and drop out on their own — an explicit one
/// would have to hop to the main thread from `deinit`, capturing an object already being torn down.
protocol EmbeddedBlockPlaceRegistering: AnyObject {

    func register(_ block: EmbeddedBlockPlaceHandling, place: String)

    func blockAppeared(_ place: String)

    /// A block's attempt ended without a show; once no block of the place holds one, the place's slot
    /// in the show budget is given back.
    func blockAttemptEnded(_ place: String)
}

/// The place map and the router between blocks and the selection — in sync with Android, where the
/// same component carries the same name and rules.
final class EmbeddedBlockPlaceRegistry: EmbeddedBlockPlaceRegistering {

    struct PlaceAnswer {
        let content: EmbeddedBlockWebContent
        let processingDuration: TimeInterval
    }

    typealias EmbeddedPlacesFetching = (@escaping ([String: Set<String>]?) -> Void) -> Void

    private struct WeakBlock {
        weak var block: EmbeddedBlockPlaceHandling?
    }

    private struct QueuedInvalidation {
        var trigger: ApplicationEvent?
    }

    private enum ResolveCause {
        case blockAppeared
        case newConfig
        case operation(ApplicationEvent)
        case queued(ApplicationEvent?)

        var trigger: ApplicationEvent? {
            switch self {
                case .blockAppeared, .newConfig: return nil
                case .operation(let event): return event
                case .queued(let trigger): return trigger
            }
        }

        var queuesWhenBusy: Bool {
            if case .blockAppeared = self {
                return false
            }

            return true
        }

        var logDescription: String {
            switch self {
                case .blockAppeared: return "the block appeared"
                case .newConfig: return "a new config"
                case .operation(let event): return "operation '\(event.name)'"
                case .queued: return "a queued invalidation"
            }
        }
    }

    private var blocksByPlace: [String: [WeakBlock]] = [:]
    private var resolvingPlaces: Set<String> = []
    private var queuedInvalidations: [String: QueuedInvalidation] = [:]

    /// `nil` until a config has been seen: gating on an empty map before that would silently drop
    /// operations whose resolve would simply have waited for the config.
    private var embeddedPlacesInConfig: [String: Set<String>]?

    private let resolver: EmbeddedBlockResolving
    private let budget: InappShowBudgeting
    private let fetchEmbeddedPlaces: EmbeddedPlacesFetching
    private let notificationCenter: NotificationCenter
    private let delayedDelivery: EmbeddedBlockDelayedDelivery<PlaceAnswer>

    private var observers: [NSObjectProtocol] = []

    init(resolver: EmbeddedBlockResolving,
         budget: InappShowBudgeting,
         notificationCenter: NotificationCenter = .default,
         fetchEmbeddedPlaces: @escaping EmbeddedPlacesFetching = EmbeddedBlockPlaceRegistry.fetchPlacesFromConfig,
         delayedDelivery: EmbeddedBlockDelayedDelivery<PlaceAnswer> = EmbeddedBlockDelayedDelivery()) {
        self.resolver = resolver
        self.budget = budget
        self.notificationCenter = notificationCenter
        self.fetchEmbeddedPlaces = fetchEmbeddedPlaces
        self.delayedDelivery = delayedDelivery

        // The registry is created lazily, with the first block — a config may already be in memory,
        // and its notification is not coming again.
        refreshEmbeddedPlaces()

        observers.append(notificationCenter.addObserver(forName: .mobileConfigDownloaded,
                                                        object: nil,
                                                        queue: .main) { [weak self] _ in
            self?.configApplied()
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
        prune(place)
        blocksByPlace[place, default: []].append(WeakBlock(block: block))

        warnIfPlaceIsShared(place)
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
        requestResolve(place: place, cause: .blockAppeared)
    }

    func blockAttemptEnded(_ place: String) {
        prune(place)

        guard !(blocksByPlace[place] ?? []).contains(where: { $0.block?.holdsAnAttempt == true }) else { return }

        budget.release(.place(place))
    }

    // MARK: - Channels

    private func configApplied() {
        refreshEmbeddedPlaces()

        for place in placesWithActiveBlocks() {
            requestResolve(place: place, cause: .newConfig)
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

        guard hasActiveBlocks(place) else {
            Logger.common(message: "[EmbeddedBlock] Place '\(place)': \(cause.logDescription), but no block is on screen — nowhere to draw, the next start() re-asks",
                          category: .embeddedBlocks)
            return
        }

        guard !resolvingPlaces.contains(place) else {
            guard cause.queuesWhenBusy else {
                Logger.common(message: "[EmbeddedBlock] Place '\(place)': \(cause.logDescription) while a resolve is in flight — its answer covers this too",
                              category: .embeddedBlocks)
                return
            }

            queuedInvalidations[place] = QueuedInvalidation(trigger: cause.trigger ?? queuedInvalidations[place]?.trigger)

            Logger.common(message: "[EmbeddedBlock] Place '\(place)': \(cause.logDescription) landed mid-resolve — queued for the pass after",
                          category: .embeddedBlocks)
            return
        }

        resolvingPlaces.insert(place)

        resolver.resolve(place, trigger: cause.trigger) { [weak self] resolution, processingDuration in
            guard let self else { return }

            self.resolvingPlaces.remove(place)
            self.handle(resolution, at: place, processingDuration: processingDuration)

            if let queued = self.queuedInvalidations.removeValue(forKey: place) {
                self.requestResolve(place: place, cause: .queued(queued.trigger))
            }
        }
    }

    /// A winner with `delayTime` waits like an overlay in the schedule queue and the blocks stand their wait
    /// budget down. A delay served once in the session is not waited again: a block coming back gets the content at once.
    private func handle(_ resolution: EmbeddedBlockResolution, at place: String, processingDuration: TimeInterval) {
        guard case .content(let content) = resolution else {
            delayedDelivery.cancel(place: place)
            budget.release(.place(place))
            deliver(place: place, resolution: resolution, processingDuration: processingDuration)
            return
        }

        let answer = PlaceAnswer(content: content, processingDuration: processingDuration)

        if delayedDelivery.isWaiting(place: place, for: content.inAppId) {
            Logger.common(message: "[EmbeddedBlock] Place '\(place)': in-app \(content.inAppId) is still waiting out its delay",
                          category: .embeddedBlocks)
            delayedDelivery.refresh(place: place, answer: answer)
            announceDelay(at: place)
            return
        }

        delayedDelivery.cancel(place: place)

        let delay = TimeInterval.delay(fromTimeSpan: content.delayTime)
        let served = ServedPlaceDelay(place: place, inappId: content.inAppId)
        // Checked here, inserted when the delay fires — both on the main thread; the ledger's
        // lock protects other readers, not this sequence.
        guard delay > 0, !SessionTemporaryStorage.shared.ledger.servedPlaceDelays.contains(served) else {
            deliverContent(content, at: place, processingDuration: processingDuration)
            return
        }

        Logger.common(message: "[EmbeddedBlock] Place '\(place)': in-app \(content.inAppId) waits \(delay)s before it is shown",
                      category: .embeddedBlocks)
        announceDelay(at: place)

        delayedDelivery.schedule(place: place, inappId: content.inAppId, answer: answer, after: delay) { [weak self] answer in
            SessionTemporaryStorage.shared.$ledger.mutate { $0.servedPlaceDelays.insert(served) }
            self?.deliverContent(answer.content, at: place, processingDuration: answer.processingDuration)
        }
    }

    /// The slot is taken here, at the last point before a page is built: a `delayTime` waited out or a
    /// budget spent by another show since the resolve leaves the place empty, with no page loaded for nothing.
    private func deliverContent(_ content: EmbeddedBlockWebContent, at place: String, processingDuration: TimeInterval) {
        guard holdsSlot(for: content, at: place) else {
            Logger.common(message: "[EmbeddedBlock] Place '\(place)': in-app \(content.inAppId) won it, but the show budgets are spent — the place stays empty",
                          category: .embeddedBlocks)
            deliver(place: place, resolution: .empty, processingDuration: processingDuration)
            return
        }

        deliver(place: place, resolution: .content(content), processingDuration: processingDuration)
    }

    private func holdsSlot(for content: EmbeddedBlockWebContent, at place: String) -> Bool {
        if SessionTemporaryStorage.shared.ledger.placeShownInappId[place] == content.inAppId {
            return true
        }

        return budget.reserve(.place(place), inAppId: content.inAppId, isPriority: content.isPriority, frequency: content.frequency) != .refused
    }

    private func announceDelay(at place: String) {
        for weakBlock in blocksByPlace[place] ?? [] {
            weakBlock.block?.contentIsDelayed()
        }
    }

    private func deliver(place: String, resolution: EmbeddedBlockResolution, processingDuration: TimeInterval) {
        for weakBlock in blocksByPlace[place] ?? [] {
            weakBlock.block?.apply(resolution, processingDuration: processingDuration)
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

    private func placesWithActiveBlocks() -> [String] {
        blocksByPlace.keys.filter { hasActiveBlocks($0) }
    }

    private func prune(_ place: String) {
        let alive = (blocksByPlace[place] ?? []).filter { $0.block != nil }
        if alive.isEmpty {
            blocksByPlace.removeValue(forKey: place)
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
