//
//  EmbeddedBlockPlaceRegistryTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 14.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit
import Testing
import Foundation
@_spi(Internal) @testable import Mindbox

@Suite("Embedded block place registry", .tags(.embeddedBlocks))
@MainActor
struct EmbeddedBlockPlaceRegistryTests {

    private final class BlockFake: EmbeddedBlockPlaceHandling {
        var isActive = true
        var holdsAnAttempt = true
        private(set) var answers: [EmbeddedBlockPlaceAnswer] = []
        private(set) var delayedCount = 0

        var applied: [EmbeddedBlockResolution] { answers.map(\.resolution) }
        var processingDurations: [TimeInterval] { answers.map(\.processingDuration) }

        func apply(_ answer: EmbeddedBlockPlaceAnswer) {
            answers.append(answer)
        }

        func contentIsDelayed() {
            delayedCount += 1
        }

        func contentIsKept() {}

        func keptContentIsReleased() {}
    }

    private final class Rig: EmbeddedBlockSessionRig {
        let resolver: EmbeddedBlockResolverMock
        let center: NotificationCenter
        let embeddedPlaces: EmbeddedPlacesStub
        let delayScheduler: TestScheduler
        let budget = InappShowBudgetMock()
        let presence: AppPresenceBed
        let registry: EmbeddedBlockPlaceRegistry

        init() {
            // Served delays and shown slots live on the shared session singleton — reset, or rigs would see each other's.
            SessionTemporaryStorage.shared.$ledger.mutate {
                $0.servedPlaceDelays = []
                $0.placeShownInappId = [:]
            }

            let resolver = EmbeddedBlockResolverMock()
            let center = NotificationCenter()
            let embeddedPlaces = EmbeddedPlacesStub()
            let delayScheduler = TestScheduler()
            let presence = AppPresenceBed(center: center)
            self.resolver = resolver
            self.center = center
            self.embeddedPlaces = embeddedPlaces
            self.delayScheduler = delayScheduler
            self.presence = presence
            registry = EmbeddedBlockPlaceRegistry(resolver: resolver,
                                                  budget: budget,
                                                  notificationCenter: center,
                                                  fetchEmbeddedPlaces: { embeddedPlaces.fetch($0) },
                                                  presence: presence.presence,
                                                  delayedDelivery: EmbeddedBlockDelayedDelivery(presence: presence.presence,
                                                                                                schedule: { delayScheduler.schedule($0, $1) }),
                                                  now: { presence.clock.now })
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

    @Test("A queued pass that also re-checks a new config is a config pass, whatever operation it carries, in either order")
    func queuedPassWithANewConfigIsNotAnOperationPass() {
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
            rig.resolver.flush()

            let carried = rig.resolver.triggers.last ?? nil
            #expect(carried === event)
            #expect(block.answers.map(\.isOperationTriggered) == [false, false])
        }
    }

    @Test("A block that comes back while an operation's pass flies is answered as on its own return, not as by the operation")
    func appearanceAbsorbedByAnOperationPassIsNotAnOperationAnswer() {
        let rig = Rig()
        rig.resolver.isDeferred = true
        rig.resolver.resolution = .empty
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.announceOperation()

        rig.registry.blockAppeared("stories")
        rig.resolver.flush()

        #expect(rig.resolver.resolveCount == 1)
        #expect(block.answers.map(\.isOperationTriggered) == [false])
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

    @Test("A download's end announced off the main thread is heard without making that thread wait for main")
    func conclusionOffMainDoesNotWaitForMain() {
        let rig = Rig()
        let center = rig.center
        let sessionEpoch = rig.currentSessionEpoch
        let posted = DispatchSemaphore(value: 0)

        DispatchQueue.global().async {
            center.post(name: .mobileConfigDownloadConcluded, object: nil, userInfo: [Constants.Notification.sessionEpoch: sessionEpoch])
            posted.signal()
        }

        #expect(posted.wait(timeout: .now() + 2) == .success)
    }

    @Test("A new session asks every place a block shows at once, before its config arrives, and the config's pass queues behind")
    func newSessionAsksTheShownPlacesAtOnce() {
        let rig = Rig()
        rig.resolver.isDeferred = true
        let shown = BlockFake()
        let away = BlockFake()
        away.isActive = false
        away.holdsAnAttempt = false
        rig.registry.register(shown, place: "stories")
        rig.registry.register(away, place: "promo")

        rig.expireSession()
        rig.presence.finishSessionCheck(startsNewSession: true)
        #expect(rig.resolver.resolvedPlaces == ["stories"])
        #expect(rig.resolver.triggers.compactMap { $0 }.isEmpty)

        rig.announceNewConfig(sessionEpoch: rig.currentSessionEpoch)
        #expect(rig.resolver.resolveCount == 1)

        rig.resolver.sessionEpoch = rig.currentSessionEpoch
        rig.resolver.flush()

        #expect(shown.answers.map(\.sessionEpoch) == [rig.currentSessionEpoch])
        #expect(shown.answers.map(\.isOperationTriggered) == [false])
        #expect(rig.resolver.resolveCount == 2)
    }

    @Test("A session check that started no new session asks no place")
    func sessionCheckWithinTheSessionAsksNothing() {
        let rig = Rig()
        rig.registry.register(BlockFake(), place: "stories")

        rig.presence.finishSessionCheck(startsNewSession: false)

        #expect(rig.resolver.resolveCount == 0)
    }

    @Test("A new session landing while a pass flies asks again once that pass lands, instead of letting it answer")
    func newSessionDuringAPassAsksAfterIt() {
        let rig = Rig()
        rig.resolver.isDeferred = true
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.registry.blockAppeared("stories")

        rig.expireSession()
        rig.presence.finishSessionCheck(startsNewSession: true)
        rig.resolver.flush()

        #expect(rig.resolver.resolveCount == 2)
        #expect(block.answers.isEmpty)
    }

    @Test("A block that came back while an earlier session's pass flew is asked for again once that pass is dropped")
    func answerOlderThanTheConcludedDownloadIsAskedAgain() {
        let rig = Rig()
        rig.resolver.isDeferred = true
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.registry.blockAppeared("stories")

        block.isActive = false
        rig.expireSession()
        rig.announceNewConfig(sessionEpoch: rig.currentSessionEpoch)
        block.isActive = true
        rig.registry.blockAppeared("stories")
        rig.resolver.flush()
        #expect(rig.resolver.resolveCount == 2)
        #expect(block.answers.isEmpty)

        rig.resolver.sessionEpoch = rig.currentSessionEpoch
        rig.resolver.flush()

        #expect(rig.resolver.resolveCount == 2)
        #expect(block.answers.map(\.sessionEpoch) == [rig.currentSessionEpoch])
    }

    @Test("A new session landing while a pass flies times the place's show from the reset, not from the pass that waited behind it")
    func newSessionBehindAPassIsTimedFromTheReset() {
        let rig = Rig()
        rig.resolver.isDeferred = true
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.registry.blockAppeared("stories")

        rig.expireSession()
        rig.presence.finishSessionCheck(startsNewSession: true)
        rig.presence.clock.advance(3)
        rig.resolver.flush()

        rig.resolver.sessionEpoch = rig.currentSessionEpoch
        rig.resolver.processingDuration = 0.5
        rig.resolver.flush()

        #expect(block.processingDurations == [3.5])
    }

    // MARK: - A new session off screen

    @Test("A new session also asks a place whose blocks are all off screen while one still holds an attempt, and hands it the content without taking a slot")
    func newSessionAsksAnOffScreenPlaceWithAnAttempt() {
        let rig = Rig()
        let away = BlockFake()
        away.isActive = false
        let idle = BlockFake()
        idle.isActive = false
        idle.holdsAnAttempt = false
        rig.registry.register(away, place: "stories")
        rig.registry.register(idle, place: "promo")

        rig.expireSession()
        rig.resolver.sessionEpoch = rig.currentSessionEpoch
        rig.presence.finishSessionCheck(startsNewSession: true)

        #expect(rig.resolver.resolvedPlaces == ["stories"])
        #expect(away.applied == [.content(.stub)])
        #expect(away.answers.map(\.isAskedOffScreen) == [true])
        #expect(rig.budget.reservations.isEmpty)
    }

    @Test("A new session's winner with delayTime that runs out while no block shows the place reaches its blocks without taking a slot")
    func delayedWinnerAskedOffScreenTakesNoSlot() {
        let rig = Rig()
        rig.resolver.resolution = .content(.delayed("00:00:05"))
        let away = BlockFake()
        away.isActive = false
        rig.registry.register(away, place: "stories")
        rig.expireSession()
        rig.resolver.sessionEpoch = rig.currentSessionEpoch
        rig.presence.finishSessionCheck(startsNewSession: true)
        #expect(away.answers.isEmpty)

        rig.delayScheduler.fireAll()

        #expect(away.applied == [.content(.delayed("00:00:05"))])
        #expect(rig.budget.reservations.isEmpty)
    }

    @Test("A new session landing while a pass flies for a place its block has left asks that place once the pass lands, off screen")
    func newSessionBehindAPassReachesAPlaceItsBlockLeft() {
        let rig = Rig()
        rig.resolver.isDeferred = true
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.registry.blockAppeared("stories")
        block.isActive = false

        rig.expireSession()
        rig.presence.finishSessionCheck(startsNewSession: true)
        rig.resolver.flush()
        #expect(rig.resolver.resolveCount == 2)

        rig.resolver.sessionEpoch = rig.currentSessionEpoch
        rig.resolver.flush()

        #expect(block.answers.map(\.isAskedOffScreen) == [true])
        #expect(rig.budget.reservations.isEmpty)
    }

    @Test("A new session's ask queued behind a pass while its block was off screen is timed from the block's return when it comes back before the ask runs, even with a config's pass queued after the return",
          arguments: [false, true])
    func newSessionQueuedOffScreenIsTimedFromTheReturn(configQueuedAfterTheReturn: Bool) {
        let rig = Rig()
        rig.resolver.isDeferred = true
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.registry.blockAppeared("stories")
        block.isActive = false
        rig.expireSession()
        rig.presence.finishSessionCheck(startsNewSession: true)
        rig.presence.clock.advance(30)

        block.isActive = true
        rig.registry.blockAppeared("stories")
        if configQueuedAfterTheReturn {
            rig.announceNewConfig(sessionEpoch: rig.currentSessionEpoch)
        }
        rig.resolver.flush()
        rig.resolver.sessionEpoch = rig.currentSessionEpoch
        rig.presence.clock.advance(0.5)
        rig.resolver.processingDuration = 0.5
        rig.resolver.flush()

        #expect(block.processingDurations == [0.5])
    }

    @Test("A config's pass queued behind one in flight does not ask a place its block has left by the time it runs")
    func queuedConfigPassStaysOnScreen() {
        let rig = Rig()
        rig.resolver.isDeferred = true
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.registry.blockAppeared("stories")
        rig.announceNewConfig()

        block.isActive = false
        rig.resolver.flush()

        #expect(rig.resolver.resolveCount == 1)
    }

    @Test("A new session's ask that a block comes back to before it lands is timed from that return and takes its slot on screen")
    func offScreenAskLandingAfterTheReturnIsTimedFromIt() {
        let rig = Rig()
        rig.resolver.isDeferred = true
        let block = BlockFake()
        block.isActive = false
        rig.registry.register(block, place: "stories")
        rig.expireSession()
        rig.resolver.sessionEpoch = rig.currentSessionEpoch
        rig.presence.finishSessionCheck(startsNewSession: true)
        rig.presence.clock.advance(30)

        block.isActive = true
        rig.registry.blockAppeared("stories")
        rig.presence.clock.advance(0.5)
        rig.resolver.processingDuration = 30.5
        rig.resolver.flush()

        #expect(block.processingDurations == [0.5])
        #expect(rig.budget.reservedOwners == [.place("stories")])
    }

    @Test("Content asked off screen takes the place's slot when a block brings it on screen, and its show is timed from then")
    func contentAskedOffScreenTakesItsSlotOnScreen() throws {
        let rig = Rig()
        let away = BlockFake()
        away.isActive = false
        rig.registry.register(away, place: "stories")
        rig.resolver.processingDuration = 4
        rig.expireSession()
        rig.resolver.sessionEpoch = rig.currentSessionEpoch
        rig.presence.finishSessionCheck(startsNewSession: true)
        let parked = try #require(away.answers.last)

        let brought = rig.registry.bringOnScreen(parked, at: "stories")

        #expect(brought?.resolution == .content(.stub))
        #expect(brought?.processingDuration == 0)
        #expect(rig.budget.reservedOwners == [.place("stories")])
    }

    @Test("Content asked off screen is brought on screen as empty when the show budgets are spent by then, and not at all once its session has ended",
          arguments: [false, true])
    func contentAskedOffScreenThatCannotBeShown(isSessionOver: Bool) throws {
        let rig = Rig()
        let away = BlockFake()
        away.isActive = false
        rig.registry.register(away, place: "stories")
        rig.expireSession()
        rig.resolver.sessionEpoch = rig.currentSessionEpoch
        rig.presence.finishSessionCheck(startsNewSession: true)
        let parked = try #require(away.answers.last)

        if isSessionOver {
            rig.expireSession()
        } else {
            rig.budget.refusedInAppIds = [EmbeddedBlockWebContent.stub.inAppId]
        }
        let brought = rig.registry.bringOnScreen(parked, at: "stories")

        let expected: EmbeddedBlockResolution? = isSessionOver ? nil : .empty
        #expect(brought?.resolution == expected)
    }

    @Test("An answer asked while a block showed the place is brought on screen as it is, touching no slot")
    func answerAskedOnScreenIsBroughtBackAsItIs() {
        let rig = Rig()
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.resolver.processingDuration = 2
        rig.registry.blockAppeared("stories")
        let reservations = rig.budget.reservations.count

        let brought = rig.registry.bringOnScreen(block.answers[0], at: "stories")

        #expect(brought?.processingDuration == 2)
        #expect(rig.budget.reservations.count == reservations)
    }

    // MARK: - The return's session check

    @Test("Content answered between a return and the end of its session check reaches no block and takes no slot; once the check has ended the session, it is dropped and the session is asked anew")
    func contentInsideTheReturnOfAnEndedSessionIsDropped() {
        let rig = Rig()
        rig.resolver.isDeferred = true
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.registry.blockAppeared("stories")
        rig.presence.enterBackground()
        rig.presence.returnToApp()

        rig.resolver.flush()
        #expect(block.answers.isEmpty)
        #expect(rig.budget.reservations.isEmpty)

        rig.expireSession()
        rig.presence.finishSessionCheck(startsNewSession: true)

        #expect(block.answers.isEmpty)
        #expect(rig.budget.reservations.isEmpty)
        #expect(rig.resolver.resolveCount == 2)
    }

    @Test("Content answered between a return and the end of a session check that kept the session is handed over once the check ends")
    func contentInsideTheReturnOfAKeptSessionArrivesAfterTheCheck() {
        let rig = Rig()
        rig.resolver.isDeferred = true
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.registry.blockAppeared("stories")
        rig.presence.enterBackground()
        rig.presence.returnToApp()
        rig.resolver.flush()

        rig.presence.finishSessionCheck()

        #expect(block.applied == [.content(.stub)])
        #expect(rig.budget.reservedOwners == [.place("stories")])
    }

    @Test("Of the content answered between a return and the end of its session check, only the newest reaches the block")
    func onlyTheNewestContentInsideTheReturnArrives() {
        let rig = Rig()
        rig.resolver.isDeferred = true
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.registry.blockAppeared("stories")
        rig.presence.enterBackground()
        rig.presence.returnToApp()
        rig.resolver.flush()

        rig.resolver.resolution = .content(.other)
        rig.registry.blockAppeared("stories")
        rig.resolver.flush()
        rig.presence.finishSessionCheck()

        #expect(block.applied == [.content(.other)])
    }

    @Test("An answer of nothing between a return and the end of its session check goes out at once, and the content kept before it never follows")
    func nothingInsideTheReturnOvertakesTheKeptContent() {
        let rig = Rig()
        rig.resolver.isDeferred = true
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.registry.blockAppeared("stories")
        rig.presence.enterBackground()
        rig.presence.returnToApp()
        rig.resolver.flush()

        rig.resolver.resolution = .empty
        rig.registry.blockAppeared("stories")
        rig.resolver.flush()
        #expect(block.applied == [.empty])

        rig.presence.finishSessionCheck()

        #expect(block.applied == [.empty])
    }

    @Test("An answer of nothing from a session that has ended does not undo the content kept for the end of the return's session check")
    func staleNothingInsideTheReturnKeepsTheKeptContent() {
        let rig = Rig()
        rig.resolver.isDeferred = true
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.registry.blockAppeared("stories")
        rig.presence.enterBackground()
        rig.presence.returnToApp()
        rig.resolver.flush()

        rig.resolver.resolution = .empty
        rig.resolver.sessionEpoch = rig.currentSessionEpoch - 1
        rig.registry.blockAppeared("stories")
        rig.resolver.flush()
        rig.presence.finishSessionCheck()

        #expect(block.applied == [.content(.stub)])
    }

    @Test("Content for a place no block shows is handed over at once between a return and the end of its session check, for the block to park")
    func contentForAPlaceOffScreenInsideTheReturnIsHandedOver() {
        let rig = Rig()
        rig.resolver.isDeferred = true
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.registry.blockAppeared("stories")
        rig.presence.enterBackground()
        rig.presence.returnToApp()
        block.isActive = false

        rig.resolver.flush()

        #expect(block.applied == [.content(.stub)])
    }

    @Test("An answer of the session a check is ending reaches no block and touches no slot", arguments: SlotAnswer.allCases)
    func answerOfAnEndingSessionIsDropped(_ answer: SlotAnswer) {
        let rig = Rig()
        rig.resolver.isDeferred = true
        rig.resolver.resolution = answer.resolution
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.registry.blockAppeared("stories")
        SessionTemporaryStorage.shared.$ledger.mutate { $0.isSessionEnding = true }
        defer { SessionTemporaryStorage.shared.$ledger.mutate { $0.isSessionEnding = false } }

        rig.resolver.flush()

        #expect(block.answers.isEmpty)
        #expect(rig.budget.callSessions.isEmpty)
    }

    enum SlotAnswer: CaseIterable {
        case empty
        case content

        var resolution: EmbeddedBlockResolution { self == .empty ? .empty : .content(.stub) }
    }

    @Test("An answer of an earlier session reaches no block and touches no slot", arguments: SlotAnswer.allCases)
    func answerOfAnEarlierSessionIsDropped(_ answer: SlotAnswer) {
        let rig = Rig()
        rig.resolver.isDeferred = true
        rig.resolver.resolution = answer.resolution
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.registry.blockAppeared("stories")

        rig.expireSession()
        rig.resolver.flush()

        #expect(block.answers.isEmpty)
        #expect(rig.budget.reservations.isEmpty)
        #expect(rig.budget.releases.isEmpty)
    }

    @Test("An answer takes or gives back its place's slot in the session it was computed in", arguments: SlotAnswer.allCases)
    func slotIsTakenInTheAnswersSession(_ answer: SlotAnswer) {
        let rig = Rig()
        rig.resolver.resolution = answer.resolution
        let block = BlockFake()
        rig.registry.register(block, place: "stories")

        rig.registry.blockAppeared("stories")

        #expect(rig.budget.callSessions == [rig.currentSessionEpoch])
        #expect(block.answers.count == 1)
    }

    @Test("Content whose session ends before its slot is taken reaches no block, rather than emptying the place")
    func contentOfASessionEndedBeforeItsSlotIsDropped() {
        let rig = Rig()
        rig.budget.isOfAnEndedSession = true
        let block = BlockFake()
        rig.registry.register(block, place: "stories")

        rig.registry.blockAppeared("stories")

        #expect(block.answers.isEmpty)
    }

    @Test("An answer from the config the last download left is not asked for again")
    func answerOfTheConcludedDownloadIsFinal() {
        let rig = Rig()
        rig.resolver.isDeferred = true
        let block = BlockFake()
        rig.registry.register(block, place: "stories")

        rig.announceNewConfig()
        rig.resolver.flush()

        #expect(rig.resolver.resolveCount == 1)
        #expect(block.applied == [.content(.stub)])
    }

    @Test("An answer tells its blocks whether an operation asked for it")
    func answerCarriesItsCause() {
        let rig = Rig()
        let block = BlockFake()
        rig.registry.register(block, place: "stories")

        rig.announceNewConfig()
        rig.announceOperation()
        rig.registry.blockAppeared("stories")

        #expect(block.answers.map(\.isOperationTriggered) == [false, true, false])
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

    // MARK: - delayTime

    @Test("A winner with delayTime is delivered when the delay runs out")
    func delayedWinnerIsDeliveredAfterTheDelay() {
        let rig = Rig()
        rig.resolver.resolution = .content(.delayed("00:00:05"))
        let block = BlockFake()
        rig.registry.register(block, place: "stories")

        rig.registry.blockAppeared("stories")

        #expect(block.applied.isEmpty)
        #expect(block.delayedCount == 1)
        #expect(rig.delayScheduler.lastDelay == 5)

        rig.delayScheduler.fireAll()

        #expect(block.applied == [.content(.delayed("00:00:05"))])
    }

    @Test("The delay a winner waited out is not added to the selection's time")
    func delayIsNotAddedToTheProcessingTime() {
        let rig = Rig()
        rig.resolver.resolution = .content(.delayed("00:00:05"))
        rig.resolver.processingDuration = 2
        let block = BlockFake()
        rig.registry.register(block, place: "stories")

        rig.registry.blockAppeared("stories")
        rig.delayScheduler.fireAll()

        #expect(block.processingDurations == [2])
    }

    @Test("A different answer during the delay replaces the waiting one")
    func newAnswerDuringTheDelayReplacesIt() {
        let rig = Rig()
        rig.resolver.resolution = .content(.delayed())
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.registry.blockAppeared("stories")

        rig.resolver.resolution = .content(.stub)
        rig.announceNewConfig()
        rig.delayScheduler.fireAll()

        #expect(block.applied == [.content(.stub)])
    }

    @Test("The same winner resolved again keeps its delay running and arrives with the newest content")
    func sameWinnerKeepsItsDelay() {
        let rig = Rig()
        rig.resolver.resolution = .content(.delayed())
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.registry.blockAppeared("stories")

        rig.resolver.resolution = .content(.delayed(params: ["fresh": .bool(true)]))
        rig.announceNewConfig()

        #expect(rig.delayScheduler.armCount == 1)
        #expect(block.applied.isEmpty)

        rig.delayScheduler.fireAll()

        #expect(block.applied == [.content(.delayed(params: ["fresh": .bool(true)]))])
    }

    @Test("A winner a new session picks again waits its whole delay again, as at cold start")
    func delayedWinnerArrivesWithItsNewestSession() {
        let rig = Rig()
        rig.resolver.resolution = .content(.delayed("00:00:05"))
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.registry.blockAppeared("stories")

        rig.expireSession()
        rig.resolver.sessionEpoch = rig.currentSessionEpoch
        rig.announceNewConfig()

        #expect(rig.delayScheduler.armCount == 2)
        #expect(rig.delayScheduler.lastDelay == 5)

        rig.delayScheduler.fireAll()

        #expect(block.answers.map(\.sessionEpoch) == [rig.currentSessionEpoch])
    }

    @Test("A delay of an earlier session that runs out delivers nothing and marks nothing")
    func delayOfAnEarlierSessionDeliversNothing() {
        let rig = Rig()
        rig.resolver.resolution = .content(.delayed())
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.registry.blockAppeared("stories")

        rig.expireSession()
        rig.delayScheduler.fireAll()

        #expect(block.applied.isEmpty)
        #expect(rig.budget.reservations.isEmpty)
        #expect(SessionTemporaryStorage.shared.ledger.servedPlaceDelays.isEmpty)
    }

    @Test("The same winner resolved again after its delay ran out in the background is delivered once the user is back and the return's session check is over, not delayed again")
    func sameWinnerAfterBackgroundExpiryIsNotDelayedAgain() {
        let rig = Rig()
        rig.resolver.resolution = .content(.delayed())
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.registry.blockAppeared("stories")
        rig.presence.enterBackground()
        rig.delayScheduler.fireAll()

        rig.announceNewConfig()

        #expect(rig.delayScheduler.armCount == 1)
        #expect(block.applied.isEmpty)

        rig.presence.returnToApp()
        #expect(block.applied.isEmpty)

        rig.presence.finishSessionCheck()

        #expect(block.applied == [.content(.delayed())])
    }

    @Test("A delay that ran out in the background of a session that ended meanwhile delivers nothing on return, and the new session waits the whole delay")
    func delayDueFromAnExpiredSessionIsNotDeliveredOnReturn() {
        let rig = Rig()
        rig.resolver.resolution = .content(.delayed("00:00:05"))
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.registry.blockAppeared("stories")
        rig.presence.enterBackground()
        rig.delayScheduler.fireAll()

        rig.presence.returnToApp()
        rig.expireSession()
        rig.presence.finishSessionCheck(startsNewSession: true)

        #expect(block.applied.isEmpty)
        #expect(rig.budget.reservations.isEmpty)
        #expect(SessionTemporaryStorage.shared.ledger.servedPlaceDelays.isEmpty)

        rig.resolver.sessionEpoch = rig.currentSessionEpoch
        rig.announceNewConfig()

        #expect(rig.delayScheduler.armCount == 2)
        #expect(rig.delayScheduler.lastDelay == 5)
        #expect(block.applied.isEmpty)
    }

    @Test("A block appearing while the place waits out its delay is told content is coming")
    func blockAppearingMidDelayHearsOfTheDelay() {
        let rig = Rig()
        rig.resolver.resolution = .content(.delayed("00:00:05"))
        let first = BlockFake()
        rig.registry.register(first, place: "stories")
        rig.registry.blockAppeared("stories")

        let newcomer = BlockFake()
        rig.registry.register(newcomer, place: "stories")
        rig.registry.blockAppeared("stories")

        #expect(newcomer.delayedCount == 1)
        #expect(newcomer.applied.isEmpty)

        rig.delayScheduler.fireAll()

        #expect(newcomer.applied == [.content(.delayed("00:00:05"))])
    }

    @Test("A block that comes back after its delay ran out gets the content at once")
    func returningBlockAfterTheDelayIsAnsweredAtOnce() {
        let rig = Rig()
        rig.resolver.resolution = .content(.delayed())
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.registry.blockAppeared("stories")
        block.isActive = false
        rig.delayScheduler.fireAll()

        block.isActive = true
        rig.registry.blockAppeared("stories")

        #expect(block.applied.count == 2)
        #expect(block.delayedCount == 1)
    }

    // MARK: - The show budget

    @Test("A winner takes the place's slot before it is delivered")
    func winnerTakesThePlaceSlot() {
        let rig = Rig()
        let block = BlockFake()
        rig.registry.register(block, place: "stories")

        rig.registry.blockAppeared("stories")

        #expect(rig.budget.reservations == [.init(owner: .place("stories"),
                                                  inAppId: EmbeddedBlockWebContent.stub.inAppId,
                                                  isPriority: false,
                                                  frequency: .unlimited)])
        #expect(block.applied == [.content(.stub)])
    }

    @Test("A winner the budget refuses is delivered as empty")
    func refusedWinnerIsDeliveredAsEmpty() {
        let rig = Rig()
        rig.budget.refusedInAppIds = [EmbeddedBlockWebContent.stub.inAppId]
        let block = BlockFake()
        rig.registry.register(block, place: "stories")

        rig.registry.blockAppeared("stories")

        #expect(block.applied == [.empty])
    }

    @Test("A broken winner gives the slot back and is delivered as the failure it is")
    func brokenWinnerIsDeliveredAsFailure() {
        let rig = Rig()
        rig.resolver.resolution = .failure(.broken)
        let block = BlockFake()
        rig.registry.register(block, place: "stories")

        rig.registry.blockAppeared("stories")

        #expect(block.applied == [.failure(.broken)])
        #expect(rig.budget.reservations.isEmpty)
        #expect(rig.budget.releases == [.place("stories")])
        #expect(block.delayedCount == 0)
    }

    @Test("An unavailable config is delivered untouched and takes no slot")
    func unavailableConfigIsDeliveredUntouched() {
        let rig = Rig()
        rig.resolver.resolution = .configUnavailable
        let block = BlockFake()
        rig.registry.register(block, place: "stories")

        rig.registry.blockAppeared("stories")

        #expect(block.applied == [.configUnavailable])
        #expect(rig.budget.reservations.isEmpty)
        #expect(block.delayedCount == 0)
    }

    @Test("An in-app the place already shows needs no new slot")
    func shownInappNeedsNoSlot() {
        let rig = Rig()
        SessionTemporaryStorage.shared.$ledger.mutate { $0.placeShownInappId["stories"] = EmbeddedBlockWebContent.stub.inAppId }
        let block = BlockFake()
        rig.registry.register(block, place: "stories")

        rig.registry.blockAppeared("stories")

        #expect(rig.budget.reservations.isEmpty)
        #expect(block.applied == [.content(.stub)])
    }

    @Test("A delayed winner takes its slot when the delay runs out, not before")
    func delayedWinnerTakesItsSlotAfterTheDelay() {
        let rig = Rig()
        rig.resolver.resolution = .content(.delayed("00:00:05"))
        let block = BlockFake()
        rig.registry.register(block, place: "stories")

        rig.registry.blockAppeared("stories")
        #expect(rig.budget.reservations.isEmpty)

        rig.delayScheduler.fireAll()

        #expect(rig.budget.reservations.map(\.inAppId) == [EmbeddedBlockWebContent.delayed().inAppId])
        #expect(block.applied == [.content(.delayed("00:00:05"))])
    }

    @Test("An empty answer gives the place's slot back")
    func emptyAnswerGivesTheSlotBack() {
        let rig = Rig()
        rig.resolver.resolution = .empty
        let block = BlockFake()
        rig.registry.register(block, place: "stories")

        rig.registry.blockAppeared("stories")

        #expect(rig.budget.releases == [.place("stories")])
    }

    @Test("The slot is given back when the last attempt at the place has ended")
    func slotIsGivenBackAfterTheLastAttempt() {
        let rig = Rig()
        let first = BlockFake()
        let second = BlockFake()
        rig.registry.register(first, place: "stories")
        rig.registry.register(second, place: "stories")
        rig.registry.blockAppeared("stories")

        first.holdsAnAttempt = false
        rig.registry.blockAttemptEnded("stories")
        #expect(rig.budget.releases.isEmpty)

        second.holdsAnAttempt = false
        rig.registry.blockAttemptEnded("stories")

        #expect(rig.budget.releases == [.place("stories")])
    }

    @Test("Content for a place whose blocks have given up gives the slot straight back")
    func contentForAnAbandonedPlaceGivesTheSlotBack() {
        let rig = Rig()
        rig.resolver.isDeferred = true
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.registry.blockAppeared("stories")

        block.isActive = false
        block.holdsAnAttempt = false
        rig.resolver.flush()

        #expect(rig.budget.reservedOwners == [.place("stories")])
        #expect(rig.budget.releases == [.place("stories")])
    }

    @Test("Content for a place whose blocks are gone gives the slot straight back")
    func contentForAPlaceWithNoBlocksGivesTheSlotBack() {
        let rig = Rig()
        rig.resolver.isDeferred = true
        var block: BlockFake? = BlockFake()
        if let block {
            rig.registry.register(block, place: "stories")
        }
        rig.registry.blockAppeared("stories")

        block = nil
        rig.resolver.flush()

        #expect(rig.budget.releases == [.place("stories")])
    }

    @Test("A block whose attempt ended off the main queue releases the place's slot on it")
    func attemptEndedOffTheMainQueueReleasesOnIt() async {
        let rig = Rig()
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.registry.blockAppeared("stories")
        block.holdsAnAttempt = false

        nonisolated(unsafe) let registry = rig.registry
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                registry.blockAttemptEnded("stories")
                continuation.resume()
            }
        }
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }

        #expect(rig.budget.releases == [.place("stories")])
        #expect(rig.budget.releasedOnMainThread == [true])
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
