//
//  EmbeddedBlockPlaceRegistry.swift
//  Mindbox
//
//  Created by vailence on 14.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

/// What the registry needs from a block: whether there is anywhere to draw, and the one thing it
/// ever does to a block — hand it the place's fresh answer.
protocol EmbeddedBlockPlaceHandling: AnyObject {

    /// Whether the block is on screen right now. A place where every block is off screen is not
    /// resolved: there is nowhere to draw, and the next `start()` asks again anyway.
    var isActive: Bool { get }

    /// The place's fresh answer, on the main thread.
    func apply(_ resolution: EmbeddedBlockResolution)
}

/// What a block needs from the registry.
///
/// Called on the main thread: the place map, the resolve slot and the invalidation queue are
/// confined to it.
///
/// There is no `unregister`: blocks are held weakly and drop out of the map on their own. An
/// explicit unregister would have to be called from `deinit`, and hopping to the main thread from
/// there would capture an object that is already being torn down.
protocol EmbeddedBlockPlaceRegistering: AnyObject {

    func register(_ block: EmbeddedBlockPlaceHandling, place: String)

    /// Pull: the block came on screen and wants the place's current answer.
    func blockAppeared(_ place: String)
}

/// The place map and the router between blocks and the selection — in sync with Android, where the
/// same component carries the same name and rules.
///
/// One place resolves at most once at a time, whoever asked: several blocks of one place share one
/// answer. There is no selection in here: pull and push converge on the same resolver call.
final class EmbeddedBlockPlaceRegistry: EmbeddedBlockPlaceRegistering {

    /// How the registry learns which places the config addresses at all, and which operations each
    /// place's in-apps listen to — `nil` means "no config yet".
    typealias EmbeddedPlacesFetching = (@escaping ([String: Set<String>]?) -> Void) -> Void

    private struct WeakBlock {
        weak var block: EmbeddedBlockPlaceHandling?
    }

    /// A queued re-resolve for a place whose slot is busy. The key's presence is what means "queued";
    /// the trigger is kept so the deferred pass can still match operation targetings.
    private struct QueuedInvalidation {
        var trigger: ApplicationEvent?
    }

    /// Why a place is being resolved.
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

        /// A pull is dropped rather than queued when a resolve is already in flight: the block is in
        /// the map, so the flying answer reaches it too, and unlike an invalidation a pull carries
        /// nothing that pass could be missing.
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

    /// The places the current config addresses with an embedded variant, each with the operations
    /// its in-apps' targetings listen to. `nil` until a config has been seen: gating on an empty map
    /// before the config arrives would silently drop operations whose resolve would simply have
    /// waited for the config.
    private var embeddedPlacesInConfig: [String: Set<String>]?

    private let resolver: EmbeddedBlockResolving
    private let fetchEmbeddedPlaces: EmbeddedPlacesFetching
    private let notificationCenter: NotificationCenter
    private var observers: [NSObjectProtocol] = []

    init(resolver: EmbeddedBlockResolving,
         notificationCenter: NotificationCenter = .default,
         fetchEmbeddedPlaces: @escaping EmbeddedPlacesFetching = EmbeddedBlockPlaceRegistry.fetchPlacesFromConfig) {
        self.resolver = resolver
        self.notificationCenter = notificationCenter
        self.fetchEmbeddedPlaces = fetchEmbeddedPlaces

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

    /// Two blocks with one place are a legitimate case — both show the same content, resolved once —
    /// but more often it is a copied name or a reused cell that got a block container from another row.
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

    /// The push side: an operation the pipeline handles may carry an in-app targeted at a place, and
    /// only a resolve run in the operation's context can find it.
    ///
    /// Gated twice, in sync with Android: the place must be in the config, and some in-app of the
    /// place must actually listen to this operation — re-resolving on every operation re-ran
    /// targetings nothing asked about. Before the config (`nil`) both gates stay open.
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

    /// One live resolve per place. An invalidation landing while the slot is busy is queued — the
    /// in-flight pass may be reading the config that invalidation is about — and runs immediately
    /// after, carrying the strongest trigger seen while waiting.
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

            // An operation beats an empty trigger, never the other way round: dropping the operation
            // would drop the only context the deferred pass exists for.
            queuedInvalidations[place] = QueuedInvalidation(trigger: cause.trigger ?? queuedInvalidations[place]?.trigger)

            Logger.common(message: "[EmbeddedBlock] Place '\(place)': \(cause.logDescription) landed mid-resolve — queued for the pass after",
                          category: .embeddedBlocks)
            return
        }

        resolvingPlaces.insert(place)

        resolver.resolve(place, trigger: cause.trigger) { [weak self] resolution in
            guard let self else { return }

            // The slot is always released, whatever the answer was — a stuck slot would lock the
            // place in "already resolving" for the life of the process.
            self.resolvingPlaces.remove(place)
            self.deliver(place: place, resolution: resolution)

            if let queued = self.queuedInvalidations.removeValue(forKey: place) {
                self.requestResolve(place: place, cause: .queued(queued.trigger))
            }
        }
    }

    /// One answer for everyone at the place. Every block decides for itself what the answer means —
    /// including the blocks that stopped while the resolve was in flight, which simply ignore it.
    private func deliver(place: String, resolution: EmbeddedBlockResolution) {
        for weakBlock in blocksByPlace[place] ?? [] {
            weakBlock.block?.apply(resolution)
        }
    }

    // MARK: - Housekeeping

    private func refreshEmbeddedPlaces() {
        // Unknown while the answer is on its way, and unknown means the gate is open. The fetch hops to
        // the config manager's queue, and a new config starts its resolves without waiting for it — so an
        // operation landing in that window would otherwise be gated by the places of the previous config
        // and skip a place only the new one addresses.
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
