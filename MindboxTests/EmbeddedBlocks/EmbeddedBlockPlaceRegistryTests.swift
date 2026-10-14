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
        var isStartPending = false
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

    @Test("A download's end announced off the main thread does not make that thread wait for main")
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

    @Test("An operation between a return and the end of a session check that kept the session is asked as the operation it is once that check ends, not when a check from before the return ends")
    func operationInsideTheReturnOfAKeptSessionIsAskedAfterTheCheck() {
        let rig = Rig()
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.presence.enterBackground()
        rig.presence.returnToApp()

        let operation = rig.announceOperation()
        rig.presence.finishSessionCheck(startedAt: rig.presence.clock.now - 1)
        #expect(rig.resolver.resolveCount == 0)

        rig.presence.finishSessionCheck()

        #expect(rig.resolver.triggers == [operation])
        #expect(block.answers.map(\.isOperationTriggered) == [true])
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
        let answersSession = rig.currentSessionEpoch + 1
        rig.resolver.sessionEpoch = answersSession
        let block = BlockFake()
        rig.registry.register(block, place: "stories")

        rig.registry.blockAppeared("stories")

        #expect(rig.budget.callSessions == [answersSession])
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

    @Test("The same winner resolved again during its delay keeps the selection time of the answer that started the delay")
    func sameWinnerKeepsTheFirstSelectionTime() {
        let rig = Rig()
        rig.resolver.resolution = .content(.delayed())
        rig.resolver.processingDuration = 0.3
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.registry.blockAppeared("stories")

        // The second pass runs inside the delay, which is not the user's waiting: its own duration
        // says nothing about how long the user waited for the first answer.
        rig.resolver.resolution = .content(.delayed(params: ["fresh": .bool(true)]))
        rig.resolver.processingDuration = 2.5
        rig.announceNewConfig()
        rig.delayScheduler.fireAll()

        #expect(block.applied == [.content(.delayed(params: ["fresh": .bool(true)]))])
        #expect(block.processingDurations == [0.3])
    }

    @Test("The same winner resolved again without a delay is delivered at once, with its own selection time")
    func sameWinnerWithoutADelayIsDeliveredAtOnce() {
        let rig = Rig()
        rig.resolver.resolution = .content(.delayed())
        rig.resolver.processingDuration = 0.3
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.registry.blockAppeared("stories")

        // The config dropped the delay: there is nothing left to wait out, and the user waited for
        // this very answer.
        rig.resolver.resolution = .content(.delayed("00:00:00", params: ["fresh": .bool(true)]))
        rig.resolver.processingDuration = 2.5
        rig.announceNewConfig()

        #expect(block.applied == [.content(.delayed("00:00:00", params: ["fresh": .bool(true)]))])
        #expect(block.processingDurations == [2.5])

        rig.delayScheduler.fireAll()

        #expect(block.applied.count == 1)
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

    @Test("Content for a place whose blocks have given up takes no slot")
    func contentForAnAbandonedPlaceTakesNoSlot() {
        let rig = Rig()
        rig.resolver.isDeferred = true
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.registry.blockAppeared("stories")

        block.isActive = false
        block.holdsAnAttempt = false
        rig.resolver.flush()

        #expect(rig.budget.reservations.isEmpty)
        #expect(rig.budget.releases.isEmpty)
    }

    @Test("Content for a place whose blocks are gone takes no slot")
    func contentForAPlaceWithNoBlocksTakesNoSlot() {
        let rig = Rig()
        rig.resolver.isDeferred = true
        var block: BlockFake? = BlockFake()
        if let block {
            rig.registry.register(block, place: "stories")
        }
        rig.registry.blockAppeared("stories")

        block = nil
        rig.resolver.flush()

        #expect(rig.budget.reservations.isEmpty)
        #expect(rig.budget.releases.isEmpty)
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
