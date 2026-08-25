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
}

/// Called on the main thread: the registry's state is confined to it.
///
/// There is no `unregister`: blocks are held weakly and drop out on their own — an explicit one
/// would have to hop to the main thread from `deinit`, capturing an object already being torn down.
protocol EmbeddedBlockPlaceRegistering: AnyObject {

    func register(_ block: EmbeddedBlockPlaceHandling, place: String)

    func blockAppeared(_ place: String)
}

/// The place map and the router between blocks and the selection — in sync with Android, where the
/// same component carries the same name and rules.
final class EmbeddedBlockPlaceRegistry: EmbeddedBlockPlaceRegistering {

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
    private let fetchEmbeddedPlaces: EmbeddedPlacesFetching
    private let notificationCenter: NotificationCenter
    private let delayedDelivery: EmbeddedBlockDelayedDelivery

    /// What a place is holding for its `delayTime`; the same winner resolving again refreshes it in
    /// place, so the timer keeps running and delivers the newest content.
    private var waitingAnswers: [String: (resolution: EmbeddedBlockResolution, processingDuration: TimeInterval)] = [:]

    private var observers: [NSObjectProtocol] = []

    init(resolver: EmbeddedBlockResolving,
         notificationCenter: NotificationCenter = .default,
         fetchEmbeddedPlaces: @escaping EmbeddedPlacesFetching = EmbeddedBlockPlaceRegistry.fetchPlacesFromConfig,
         delayedDelivery: EmbeddedBlockDelayedDelivery = EmbeddedBlockDelayedDelivery()) {
        self.resolver = resolver
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

    /// A winner with `delayTime` waits like an overlay in the schedule queue: the blocks hear that
    /// content is coming and stand their wait budget down — a block appearing mid-delay too; a different
    /// answer for the place replaces the waiting one, the same winner keeps its timer. Once a delay ran
    /// out for an in-app at a place, a block coming back to the screen gets that content at once — the
    /// wait was already served.
    private func handle(_ resolution: EmbeddedBlockResolution, at place: String, processingDuration: TimeInterval) {
        guard case .content(let content) = resolution else {
            delayedDelivery.cancel(place: place)
            waitingAnswers[place] = nil
            deliver(place: place, resolution: resolution, processingDuration: processingDuration)
            return
        }

        if delayedDelivery.isWaiting(place: place, for: content.inAppId) {
            Logger.common(message: "[EmbeddedBlock] Place '\(place)': in-app \(content.inAppId) is still waiting out its delay",
                          category: .embeddedBlocks)
            waitingAnswers[place] = (resolution, processingDuration)
            announceDelay(at: place)
            return
        }

        delayedDelivery.cancel(place: place)
        waitingAnswers[place] = nil

        let delay = TimeInterval.delay(fromTimeSpan: content.delayTime)
        let served = ServedPlaceDelay(place: place, inappId: content.inAppId)
        guard delay > 0, !SessionTemporaryStorage.shared.servedPlaceDelays.contains(served) else {
            deliver(place: place, resolution: resolution, processingDuration: processingDuration)
            return
        }

        Logger.common(message: "[EmbeddedBlock] Place '\(place)': in-app \(content.inAppId) waits \(delay)s before it is shown",
                      category: .embeddedBlocks)
        announceDelay(at: place)

        waitingAnswers[place] = (resolution, processingDuration)
        delayedDelivery.schedule(place: place, inappId: content.inAppId, after: delay) { [weak self] in
            guard let self, let answer = self.waitingAnswers.removeValue(forKey: place) else { return }

            SessionTemporaryStorage.shared.$servedPlaceDelays.mutate { $0.insert(served) }
            self.deliver(place: place, resolution: answer.resolution, processingDuration: answer.processingDuration)
        }
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
