//
//  EmbeddedBlockPlaceRegistryTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 14.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
@_spi(Internal) @testable import Mindbox

@Suite("Embedded block place registry", .tags(.embeddedBlocks))
@MainActor
struct EmbeddedBlockPlaceRegistryTests {

    private final class BlockFake: EmbeddedBlockPlaceHandling {
        var isActive = true
        private(set) var applied: [EmbeddedBlockResolution] = []

        func apply(_ resolution: EmbeddedBlockResolution, processingDuration: TimeInterval) {
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

    /// In sync with Android: the intersection with the config happens before the resolve, so a no-op costs nothing.
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

    @Test("An operation during a places refresh is not gated by the previous config")
    func operationDuringRefreshIsNotGated() {
        let rig = Rig()
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.embeddedPlaces.places = ["some-other-place": []]
        rig.announceNewConfig()

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

    /// In sync with Android: an operation wakes a place only when some in-app of the place actually listens to it.
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

    @Test("Before any config the operation gate is open")
    func gateIsOpenBeforeAnyConfig() {
        let rig = Rig()
        let block = BlockFake()
        rig.registry.register(block, place: "stories")

        rig.announceOperation()

        #expect(rig.resolver.resolveCount == 1)
    }

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

    /// A limitation, not an oversight: neither platform remembers past operations — pinned so the day it changes is a decision.
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

    @Test("A place whose only block has died resolves nothing")
    func deadBlockLeavesNothingToResolve() {
        let rig = Rig()
        var block: BlockFake? = BlockFake()
        rig.registry.register(block!, place: "stories")

        block = nil
        rig.announceOperation()

        #expect(rig.resolver.resolveCount == 0)
    }

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
