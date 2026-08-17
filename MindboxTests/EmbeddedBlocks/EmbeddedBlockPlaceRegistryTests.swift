//
//  EmbeddedBlockPlaceRegistryTests.swift
//  MindboxTests
//
//  Created by vailence on 14.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
@_spi(Internal) @testable import Mindbox

/// The registry's own promises, checked against bare blocks: one resolve per place however many
/// blocks stand on it, a queue that keeps the strongest trigger, and gates that make a no-op cost a
/// log line instead of a selection pass. What a block does with the answer is the provider's suite.
@Suite("Embedded block place registry", .tags(.embeddedBlocks))
@MainActor
struct EmbeddedBlockPlaceRegistryTests {

    /// A block reduced to what the registry sees: somewhere to draw, and a record of what arrived.
    private final class BlockFake: EmbeddedBlockPlaceHandling {
        var isActive = true
        private(set) var applied: [EmbeddedBlockResolution] = []

        func apply(_ resolution: EmbeddedBlockResolution) {
            applied.append(resolution)
        }
    }

    private final class Rig {
        let resolver: EmbeddedBlockResolverMock
        let center: NotificationCenter
        let embeddedPlaces: EmbeddedPlacesStub
        let registry: EmbeddedBlockPlaceRegistry

        init() {
            let resolver = EmbeddedBlockResolverMock()
            let center = NotificationCenter()
            let embeddedPlaces = EmbeddedPlacesStub()
            self.resolver = resolver
            self.center = center
            self.embeddedPlaces = embeddedPlaces
            registry = EmbeddedBlockPlaceRegistry(resolver: resolver,
                                                  notificationCenter: center,
                                                  fetchEmbeddedPlaces: { embeddedPlaces.fetch($0) })
        }

        func announceNewConfig() {
            center.post(name: .mobileConfigDownloaded, object: nil)
        }

        @discardableResult
        func announceOperation(_ name: String = "custom.operation") -> ApplicationEvent {
            let event = ApplicationEvent(name: name, model: nil)
            center.post(name: .inAppOperationOccurred, object: event)
            return event
        }
    }

    // MARK: - One resolve per place

    @Test("Blocks appearing while a resolve is in flight share its answer")
    func blocksShareTheInFlightResolve() {
        let rig = Rig()
        rig.resolver.isDeferred = true
        let first = BlockFake()
        let second = BlockFake()
        rig.registry.register(first, place: "stories")
        rig.registry.register(second, place: "stories")

        rig.registry.blockAppeared("stories")
        rig.registry.blockAppeared("stories")
        #expect(rig.resolver.resolveCount == 1)

        rig.resolver.flush()

        #expect(rig.resolver.resolveCount == 1)
        #expect(first.applied == [.content(.stub)])
        #expect(second.applied == [.content(.stub)])
    }

    @Test("Different places resolve independently")
    func differentPlacesResolveApart() {
        let rig = Rig()
        let stories = BlockFake()
        let promo = BlockFake()
        rig.registry.register(stories, place: "stories")
        rig.registry.register(promo, place: "promo")

        rig.registry.blockAppeared("stories")
        rig.registry.blockAppeared("promo")

        #expect(rig.resolver.resolvedPlaces == ["stories", "promo"])
    }

    @Test("A delivered answer frees the slot for the next ask")
    func slotIsFreedAfterDelivery() {
        let rig = Rig()
        let block = BlockFake()
        rig.registry.register(block, place: "stories")

        rig.registry.blockAppeared("stories")
        rig.registry.blockAppeared("stories")

        #expect(rig.resolver.resolveCount == 2)
    }

    /// A block joining a place that has already been answered gets an answer of its own: the place's
    /// previous resolve happened before this block existed, and nothing would ever repeat it —
    /// without a pass of its own the newcomer would sit in its placeholder forever. The neighbour
    /// hears the answer again and deduplicates it itself.
    @Test("A block appearing at a place that already resolved is answered too")
    func newcomerAtAResolvedPlaceIsAnswered() {
        let rig = Rig()
        let first = BlockFake()
        rig.registry.register(first, place: "stories")
        rig.registry.blockAppeared("stories")

        let newcomer = BlockFake()
        rig.registry.register(newcomer, place: "stories")
        rig.registry.blockAppeared("stories")

        #expect(rig.resolver.resolveCount == 2)
        #expect(newcomer.applied == [.content(.stub)])
        #expect(first.applied.count == 2)
    }

    // MARK: - The queue and its trigger

    @Test("An invalidation mid-resolve runs one more pass after delivery")
    func invalidationMidResolveRunsAfter() {
        let rig = Rig()
        rig.resolver.isDeferred = true
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.registry.blockAppeared("stories")

        rig.announceNewConfig()
        #expect(rig.resolver.resolveCount == 1)

        rig.resolver.flush()
        #expect(rig.resolver.resolveCount == 2)

        rig.resolver.flush()
        #expect(block.applied.count == 2)
    }

    /// The queued pass exists to carry the operation's targeting context — losing the operation
    /// would make the pass pointless, so an empty trigger never overwrites one.
    @Test("An operation beats an empty trigger in the queue, in either order")
    func operationWinsTheQueuedTrigger() {
        for operationFirst in [true, false] {
            let rig = Rig()
            rig.resolver.isDeferred = true
            let block = BlockFake()
            rig.registry.register(block, place: "stories")
            rig.registry.blockAppeared("stories")

            var event: ApplicationEvent?
            if operationFirst {
                event = rig.announceOperation()
                rig.announceNewConfig()
            } else {
                rig.announceNewConfig()
                event = rig.announceOperation()
            }

            rig.resolver.flush()

            #expect(rig.resolver.resolveCount == 2)
            let carried = rig.resolver.triggers.last ?? nil
            #expect(carried === event)
        }
    }

    @Test("A pull mid-resolve is answered by the flying pass, not queued")
    func pullMidResolveIsNotQueued() {
        let rig = Rig()
        rig.resolver.isDeferred = true
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.registry.blockAppeared("stories")

        rig.registry.blockAppeared("stories")
        rig.resolver.flush()

        #expect(rig.resolver.resolveCount == 1)
        #expect(block.applied.count == 1)
    }

    // MARK: - Gates

    @Test("A place with no active block is not resolved")
    func inactivePlaceIsNotResolved() {
        let rig = Rig()
        let block = BlockFake()
        block.isActive = false
        rig.registry.register(block, place: "stories")

        rig.announceNewConfig()
        rig.announceOperation()

        #expect(rig.resolver.resolveCount == 0)
    }

    /// The intersection with the config happens before the resolve: an operation that cannot concern
    /// a place costs nothing — in sync with Android, where the domain computes the candidates.
    @Test("An operation skips places the config does not address")
    func operationSkipsUnaddressedPlaces() {
        let rig = Rig()
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.embeddedPlaces.places = ["some-other-place": []]
        rig.announceNewConfig()
        let resolvesAfterConfig = rig.resolver.resolveCount

        rig.announceOperation()

        #expect(rig.resolver.resolveCount == resolvesAfterConfig)
    }

    /// The gate must not answer from the previous config. The fresh set of places is fetched from the
    /// config manager's queue, and a new config starts its resolves without waiting for it, so an
    /// operation can land while the set is still the old one. Unknown is treated as open — otherwise a
    /// place that only the new config addresses would be skipped exactly when it matters.
    @Test("An operation during a places refresh is not gated by the previous config")
    func operationDuringRefreshIsNotGated() {
        let rig = Rig()
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.embeddedPlaces.places = ["some-other-place": []]
        rig.announceNewConfig()

        // The new config addresses the place, but its answer is still on the way.
        rig.embeddedPlaces.isDeferred = true
        rig.embeddedPlaces.places = ["stories": ["custom.operation"]]
        rig.announceNewConfig()
        let resolvesAfterConfig = rig.resolver.resolveCount

        rig.announceOperation()

        #expect(rig.resolver.resolveCount == resolvesAfterConfig + 1)
    }

    @Test("An operation resolves places the config does address")
    func operationResolvesAddressedPlaces() {
        let rig = Rig()
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.embeddedPlaces.places = ["stories": ["custom.operation"]]
        rig.announceNewConfig()
        let resolvesAfterConfig = rig.resolver.resolveCount

        let event = rig.announceOperation()

        #expect(rig.resolver.resolveCount == resolvesAfterConfig + 1)
        let carried = rig.resolver.triggers.last ?? nil
        #expect(carried === event)
    }

    /// Every place whose in-apps listen to the operation re-resolves — the map narrows the candidates,
    /// and the selection still decides what the operation means for each place. Worth stating, because
    /// it is also the price of a push when several places are on screen at once.
    @Test("An operation re-resolves every addressed place on screen")
    func operationReresolvesEveryAddressedPlace() {
        let rig = Rig()
        let stories = BlockFake()
        let promo = BlockFake()
        rig.registry.register(stories, place: "stories")
        rig.registry.register(promo, place: "promo")
        rig.embeddedPlaces.places = ["stories": ["custom.operation"], "promo": ["custom.operation"]]
        rig.announceNewConfig()
        let beforeOperation = rig.resolver.resolvedPlaces.count

        rig.announceOperation()

        let resolvedByOperation = Set(rig.resolver.resolvedPlaces.dropFirst(beforeOperation))
        #expect(resolvedByOperation == ["stories", "promo"])
    }

    /// In sync with Android: an operation wakes a place only when some in-app of the place actually
    /// listens to it — waking on every operation re-ran targetings nothing asked about.
    @Test("An operation no in-app of the place listens to does not resolve it")
    func foreignOperationDoesNotResolveThePlace() {
        let rig = Rig()
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.embeddedPlaces.places = ["stories": ["other.operation"]]
        rig.announceNewConfig()
        let resolvesAfterConfig = rig.resolver.resolveCount

        rig.announceOperation()

        #expect(rig.resolver.resolveCount == resolvesAfterConfig)
    }

    /// Operation names are matched the way the pipeline matches them — case-insensitively.
    @Test("The operation gate matches names case-insensitively")
    func operationGateMatchesCaseInsensitively() {
        let rig = Rig()
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.embeddedPlaces.places = ["stories": ["custom.operation"]]
        rig.announceNewConfig()
        let resolvesAfterConfig = rig.resolver.resolveCount

        rig.announceOperation("Custom.OPERATION")

        #expect(rig.resolver.resolveCount == resolvesAfterConfig + 1)
    }

    /// Before any config the gate stays open: gating on an empty set would silently drop operations
    /// whose resolve would simply have waited for the config — the trigger must survive that wait.
    @Test("Before any config the operation gate is open")
    func gateIsOpenBeforeAnyConfig() {
        let rig = Rig()
        let block = BlockFake()
        rig.registry.register(block, place: "stories")

        rig.announceOperation()

        #expect(rig.resolver.resolveCount == 1)
    }

    /// A new config re-resolves only places someone is looking at; sleeping places re-ask on their
    /// own next start.
    @Test("A new config re-resolves every place with an active block")
    func configReresolvesActivePlaces() {
        let rig = Rig()
        let active = BlockFake()
        let sleeping = BlockFake()
        sleeping.isActive = false
        rig.registry.register(active, place: "stories")
        rig.registry.register(sleeping, place: "promo")

        rig.announceNewConfig()

        #expect(rig.resolver.resolvedPlaces == ["stories"])
    }

    // MARK: - Off screen and back

    /// The sleeping place is not resolved by a config that arrived while it slept, and it is not
    /// remembered either — its own appearance asks with the config that is in memory by then.
    @Test("A place that slept through a new config resolves when it wakes")
    func sleepingPlaceResolvesOnWaking() {
        let rig = Rig()
        let sleeping = BlockFake()
        sleeping.isActive = false
        rig.registry.register(sleeping, place: "promo")

        rig.announceNewConfig()
        #expect(rig.resolver.resolveCount == 0)

        sleeping.isActive = true
        rig.registry.blockAppeared("promo")

        #expect(rig.resolver.resolvedPlaces == ["promo"])
        #expect(sleeping.applied == [.content(.stub)])
    }

    /// An operation that happened while nobody was looking is not replayed: the block that comes back
    /// pulls without it, so an in-app targeted at that operation stays invisible until the next one.
    /// A limitation, not an oversight — neither platform remembers past operations, and this is the
    /// "it happened earlier" case of the shared doc. Pinned so the day it changes is a decision.
    @Test("An operation that happened off screen is not replayed on return")
    func operationOffScreenIsNotReplayed() {
        let rig = Rig()
        let block = BlockFake()
        block.isActive = false
        rig.registry.register(block, place: "stories")

        rig.announceOperation()
        #expect(rig.resolver.resolveCount == 0)

        block.isActive = true
        rig.registry.blockAppeared("stories")

        #expect(rig.resolver.resolveCount == 1)
        let carried = rig.resolver.triggers.last ?? nil
        #expect(carried == nil)
    }

    // MARK: - Lifetime

    @Test("A dead block drops out of the map on its own")
    func deadBlocksArePruned() {
        let rig = Rig()
        var block: BlockFake? = BlockFake()
        rig.registry.register(block!, place: "stories")

        block = nil
        rig.announceOperation()

        #expect(rig.resolver.resolveCount == 0)
    }

    /// A delivery reaches every block of the place, stopped ones included — deciding what to do
    /// with an answer is the block's business, not the map's.
    @Test("A delivery reaches active and inactive blocks alike")
    func deliveryReachesEveryRegisteredBlock() {
        let rig = Rig()
        let active = BlockFake()
        let stopped = BlockFake()
        rig.registry.register(active, place: "stories")
        rig.registry.register(stopped, place: "stories")
        stopped.isActive = false

        rig.registry.blockAppeared("stories")

        #expect(active.applied == [.content(.stub)])
        #expect(stopped.applied == [.content(.stub)])
    }
}
