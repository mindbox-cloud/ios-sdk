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

        init(onClockRead: @escaping () -> Void = {}) {
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
                                                  now: {
                                                      onClockRead()
                                                      return presence.clock.now
                                                  })
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

    @Test("A newer config announced mid-resolve asks the place again once the pass that read the older one lands")
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
        let version = rig.resolver.publishConfig()
        let posted = DispatchSemaphore(value: 0)

        DispatchQueue.global().async {
            center.post(name: .mobileConfigDownloadConcluded, object: nil, userInfo: [Constants.Notification.configVersion: version])
            posted.signal()
        }

        #expect(posted.wait(timeout: .now() + 2) == .success)
    }

    @Test("A new session asks every place a block shows at once, before its config arrives, and the config that pass waits for asks the place nothing more")
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

        rig.announceNewConfig()
        #expect(rig.resolver.resolveCount == 1)

        rig.resolver.sessionEpoch = rig.currentSessionEpoch
        rig.resolver.flush(readingConfig: rig.resolver.configVersion)

        #expect(shown.answers.map(\.sessionEpoch) == [rig.currentSessionEpoch])
        #expect(shown.answers.map(\.isOperationTriggered) == [false])
        #expect(rig.resolver.resolveCount == 1)
    }

    @Test("A place waiting for its config, at a cold start or in a new session, is selected once, whichever of the config's announcement and the pass's answer reaches main first",
          arguments: [false, true], [true, false])
    func placeWaitingForItsConfigIsSelectedOnce(isNewSession: Bool, isAnnouncedFirst: Bool) {
        let rig = Rig()
        rig.resolver.isDeferred = true
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        if isNewSession {
            rig.expireSession()
            rig.presence.finishSessionCheck(startsNewSession: true)
            rig.resolver.sessionEpoch = rig.currentSessionEpoch
        } else {
            rig.registry.blockAppeared("stories")
        }

        let config = rig.resolver.publishConfig()
        if isAnnouncedFirst {
            rig.announceConfig(config)
            rig.resolver.flush(readingConfig: config)
        } else {
            rig.resolver.flush(readingConfig: config)
            rig.announceConfig(config)
        }

        #expect(rig.resolver.resolveCount == 1)
        #expect(block.answers.map(\.sessionEpoch) == [rig.currentSessionEpoch])
    }

    @Test("An operation carried into a new session's ask is the session's one selection, whichever of the session's config announcement and the pass's answer reaches main first",
          arguments: [true, false])
    func operationCarriedIntoTheNewSessionsAskIsItsOneSelection(isAnnouncedFirst: Bool) {
        let rig = Rig()
        rig.resolver.isDeferred = true
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.presence.enterBackground()
        rig.presence.returnToApp()
        let operation = rig.announceOperation()

        rig.expireSession()
        rig.presence.finishSessionCheck(startsNewSession: true)
        rig.resolver.sessionEpoch = rig.currentSessionEpoch
        let config = rig.resolver.publishConfig()
        if isAnnouncedFirst {
            rig.announceConfig(config)
            rig.resolver.flush(readingConfig: config)
        } else {
            rig.resolver.flush(readingConfig: config)
            rig.announceConfig(config)
        }

        #expect(rig.resolver.triggers == [operation])
        #expect(block.answers.map(\.sessionEpoch) == [rig.currentSessionEpoch])
    }

    @Test("An operation that reaches a place whose pass waits for its config, at a cold start or in a new session, before or after the config is announced, is answered by its own operation pass",
          arguments: [false, true], [true, false])
    func operationBehindAPassWaitingForItsConfigIsAnOperationPass(isNewSession: Bool, isOperationFirst: Bool) {
        let rig = Rig()
        rig.resolver.isDeferred = true
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        if isNewSession {
            rig.expireSession()
            rig.presence.finishSessionCheck(startsNewSession: true)
            rig.resolver.sessionEpoch = rig.currentSessionEpoch
        } else {
            rig.registry.blockAppeared("stories")
        }

        let config = rig.resolver.publishConfig()
        let operation: ApplicationEvent
        if isOperationFirst {
            operation = rig.announceOperation()
            rig.announceConfig(config)
        } else {
            rig.announceConfig(config)
            operation = rig.announceOperation()
        }
        rig.resolver.flush(readingConfig: config)
        rig.resolver.flush()

        #expect(rig.resolver.triggers == [nil, operation])
        #expect(block.answers.map(\.isOperationTriggered) == [false, true])
    }

    @Test("A new session does not ask again a place whose pass was asked in it with no operation before the new session was announced, whether that pass is still in flight or has answered",
          arguments: [false, true])
    func newSessionDoesNotAskAPlaceAskedInItBeforeItsAnnouncement(hasAnswered: Bool) {
        let rig = Rig()
        rig.resolver.isDeferred = !hasAnswered
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.expireSession()
        rig.resolver.sessionEpoch = rig.currentSessionEpoch
        rig.registry.blockAppeared("stories")

        rig.presence.finishSessionCheck(startsNewSession: true)
        rig.resolver.flush()

        #expect(rig.resolver.resolveCount == 1)
        #expect(block.answers.map(\.sessionEpoch) == [rig.currentSessionEpoch])
    }

    @Test("A new session asks a place whose last answer was asked in it with no operation but read no config")
    func newSessionAsksAPlaceWhoseAnswerInItReadNoConfig() {
        let rig = Rig()
        rig.resolver.readsNoConfig = true
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.expireSession()
        rig.resolver.sessionEpoch = rig.currentSessionEpoch
        rig.registry.blockAppeared("stories")

        rig.presence.finishSessionCheck(startsNewSession: true)

        #expect(rig.resolver.resolveCount == 2)
        #expect(block.answers.map(\.sessionEpoch) == [rig.currentSessionEpoch, rig.currentSessionEpoch])
    }

    @Test("A pass asked in the new session with no operation that stood for the session's ask and then read no config asks its place once more when it lands")
    func standInThatReadNoConfigAsksItsPlaceOnceMore() {
        let rig = Rig()
        rig.resolver.isDeferred = true
        rig.resolver.readsNoConfig = true
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.expireSession()
        rig.resolver.sessionEpoch = rig.currentSessionEpoch
        rig.registry.blockAppeared("stories")
        rig.presence.finishSessionCheck(startsNewSession: true)
        #expect(rig.resolver.resolveCount == 1)

        rig.resolver.flush()
        rig.resolver.flush()

        #expect(rig.resolver.resolveCount == 2)
        #expect(block.answers.map(\.sessionEpoch) == [rig.currentSessionEpoch, rig.currentSessionEpoch])
    }

    @Test("A pass that stood for the new session's ask and then read no config asks its place once more when it lands for a block that has left the screen holding its attempt, as that ask would have, and not for one holding none",
          arguments: [true, false])
    func standInThatReadNoConfigAsksAgainOnlyForABlockThatMayTakeTheAnswer(holdsAnAttempt: Bool) {
        let rig = Rig()
        rig.resolver.isDeferred = true
        rig.resolver.readsNoConfig = true
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.expireSession()
        rig.resolver.sessionEpoch = rig.currentSessionEpoch
        rig.registry.blockAppeared("stories")
        rig.presence.finishSessionCheck(startsNewSession: true)
        block.isActive = false
        block.holdsAnAttempt = holdsAnAttempt

        rig.resolver.flush()

        #expect(rig.resolver.resolveCount == (holdsAnAttempt ? 2 : 1))
    }

    @Test("An operation queued behind a pass that stood for the new session's ask and then read no config is answered as the new session's pass")
    func operationBehindAStandInThatReadNoConfigIsTheNewSessionsPass() {
        let rig = Rig()
        rig.resolver.isDeferred = true
        rig.resolver.readsNoConfig = true
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.expireSession()
        rig.resolver.sessionEpoch = rig.currentSessionEpoch
        rig.registry.blockAppeared("stories")
        rig.presence.finishSessionCheck(startsNewSession: true)
        let operation = rig.announceOperation()

        rig.resolver.flush()
        rig.resolver.flush()

        #expect(rig.resolver.triggers == [nil, operation])
        #expect(block.answers.map(\.isOperationTriggered) == [false, false])
    }

    @Test("A place answered from a config is not asked again when that config is announced again, and is when a newer one is")
    func answeredPlaceIsAskedAgainOnlyByANewerConfig() {
        let rig = Rig()
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.registry.blockAppeared("stories")

        rig.announceConfig(rig.resolver.configVersion)
        #expect(rig.resolver.resolveCount == 1)

        rig.announceNewConfig()
        #expect(rig.resolver.resolveCount == 2)
    }

    @Test("A pass asked after a config was published, before its announcement reached main, is not asked again by that announcement")
    func passThatReadTheAnnouncedConfigIsNotAskedAgain() {
        let rig = Rig()
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.registry.blockAppeared("stories")
        rig.resolver.isDeferred = true

        let config = rig.resolver.publishConfig()
        rig.registry.blockAppeared("stories")
        rig.announceConfig(config)
        rig.resolver.flush()

        #expect(rig.resolver.resolveCount == 2)
        #expect(block.answers.count == 2)
    }

    @Test("A pass that read no config is asked again once when a newer config is announced while it flies, and not at all when none is",
          arguments: [true, false])
    func passThatReadNoConfigIsAskedAgainOnlyForAConfigAnnouncedWhileItFlies(isConfigAnnounced: Bool) {
        let rig = Rig()
        rig.announceNewConfig()
        rig.resolver.isDeferred = true
        rig.resolver.readsNoConfig = true
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.registry.blockAppeared("stories")
        if isConfigAnnounced {
            rig.announceNewConfig()
        }

        rig.resolver.flush()
        rig.resolver.flush()

        #expect(rig.resolver.resolveCount == (isConfigAnnounced ? 2 : 1))
    }

    @Test("A config announced off the main thread asks its places on the main thread")
    func conclusionOffMainAsksOnMain() async {
        let rig = Rig()
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        let center = rig.center
        let version = rig.resolver.publishConfig()

        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                center.post(name: .mobileConfigDownloadConcluded, object: nil, userInfo: [Constants.Notification.configVersion: version])
                continuation.resume()
            }
        }
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }

        #expect(rig.resolver.resolvedOnMainThread == [true])
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
        rig.announceNewConfig()
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

    @Test("A pass asked before a reset that the new session's config answers is the new session's ask, so the place is not asked again: its selection counts from the reset, not from the time away, and it takes no slot while the place's blocks are off screen",
          arguments: [false, true])
    func passFromBeforeTheResetAnsweredByTheNewSessionCountsFromTheReset(isOffScreen: Bool) {
        let rig = Rig()
        rig.resolver.isDeferred = true
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.registry.blockAppeared("stories")
        block.isActive = !isOffScreen
        rig.presence.clock.advance(100)

        rig.expireSession()
        rig.presence.finishSessionCheck(startsNewSession: true)
        rig.presence.clock.advance(0.5)
        rig.resolver.sessionEpoch = rig.currentSessionEpoch
        rig.resolver.processingDuration = 100.5
        rig.resolver.flush()

        #expect(block.processingDurations == [0.5])
        #expect(rig.budget.reservations.isEmpty == isOffScreen)
        #expect(rig.resolver.resolveCount == 1)
    }

    @Test("An operation's pass asked before a reset that the new session's config answers does not stand for that session's own ask, which follows it with no trigger")
    func operationPassFromBeforeTheResetLeavesTheNewSessionsAsk() {
        let rig = Rig()
        rig.resolver.isDeferred = true
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        let operation = rig.announceOperation()

        rig.expireSession()
        rig.presence.finishSessionCheck(startsNewSession: true)
        rig.resolver.sessionEpoch = rig.currentSessionEpoch
        rig.resolver.flush()

        #expect(rig.resolver.triggers == [operation, nil])
    }

    @Test("A new session's ask carrying an operation held for the return's session check still runs after a pass asked before the reset that the new session's config answers")
    func newSessionsAskWithAHeldOperationFollowsAPassFromBeforeTheReset() {
        let rig = Rig()
        rig.resolver.isDeferred = true
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.registry.blockAppeared("stories")
        rig.presence.enterBackground()
        rig.presence.returnToApp()
        let operation = rig.announceOperation()

        rig.expireSession()
        rig.presence.finishSessionCheck(startsNewSession: true)
        rig.resolver.sessionEpoch = rig.currentSessionEpoch
        rig.resolver.flush()

        #expect(rig.resolver.triggers == [nil, operation])
    }

    @Test("A pass asked before two resets that the first new session's config answers does not stand for the latest session's ask, which follows it")
    func passFromBeforeTwoResetsLeavesTheLatestSessionsAsk() {
        let rig = Rig()
        rig.resolver.isDeferred = true
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.registry.blockAppeared("stories")
        rig.expireSession()
        rig.presence.finishSessionCheck(startsNewSession: true)
        rig.expireSession()
        rig.presence.finishSessionCheck(startsNewSession: true)

        rig.resolver.sessionEpoch = rig.currentSessionEpoch - 1
        rig.resolver.flush()
        rig.resolver.sessionEpoch = rig.currentSessionEpoch
        rig.resolver.flush()

        #expect(rig.resolver.resolveCount == 2)
        #expect(block.answers.map(\.sessionEpoch) == [rig.currentSessionEpoch])
    }

    @Test("A pass asked before a reset whose answer lands as the new session starts ending is dropped and leaves that session's ask to run")
    func passFromBeforeTheResetLandingAsTheSessionEndsLeavesTheNewSessionsAsk() {
        var endsTheSessionOnTheNextClockRead = false
        let rig = Rig(onClockRead: {
            guard endsTheSessionOnTheNextClockRead else { return }

            endsTheSessionOnTheNextClockRead = false
            SessionTemporaryStorage.shared.$ledger.mutate { $0.isSessionEnding = true }
        })
        defer { SessionTemporaryStorage.shared.$ledger.mutate { $0.isSessionEnding = false } }
        rig.resolver.isDeferred = true
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.registry.blockAppeared("stories")

        rig.expireSession()
        rig.presence.finishSessionCheck(startsNewSession: true)
        rig.resolver.sessionEpoch = rig.currentSessionEpoch
        endsTheSessionOnTheNextClockRead = true
        rig.resolver.flush()

        #expect(block.answers.isEmpty)
        #expect(rig.resolver.resolveCount == 2)
    }

    @Test("A new session also asks a place whose blocks are all off screen while one still holds an attempt, and hands it the content without taking a slot; a block bringing it on screen takes the slot, keeping its selection time")
    func newSessionAsksAnOffScreenPlaceWithAnAttempt() throws {
        let rig = Rig()
        let away = BlockFake()
        away.isActive = false
        let idle = BlockFake()
        idle.isActive = false
        idle.holdsAnAttempt = false
        rig.registry.register(away, place: "stories")
        rig.registry.register(idle, place: "promo")
        rig.resolver.processingDuration = 4

        rig.expireSession()
        rig.resolver.sessionEpoch = rig.currentSessionEpoch
        rig.presence.finishSessionCheck(startsNewSession: true)

        #expect(rig.resolver.resolvedPlaces == ["stories"])
        #expect(away.applied == [.content(.stub)])
        #expect(rig.budget.reservations.isEmpty)

        let parked = try #require(away.answers.last)
        let brought = rig.registry.bringOnScreen(parked, at: "stories")

        #expect(brought?.resolution == .content(.stub))
        #expect(brought?.processingDuration == 4)
        #expect(rig.budget.reservedOwners == [.place("stories")])
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

        #expect(block.answers.count == 1)
        #expect(rig.budget.reservations.isEmpty)
    }

    @Test("Content asked while a block showed the place takes no slot when it lands after the block left, its delay included, in the same session or a new one's ask, and takes it when a block brings it on screen, keeping its selection time",
          arguments: [false, true], [false, true])
    func contentLandingAfterTheBlockLeftTakesNoSlot(isDelayed: Bool, isNewSessionAsk: Bool) throws {
        let rig = Rig()
        let content: EmbeddedBlockWebContent = isDelayed ? .delayed() : .stub
        rig.resolver.resolution = .content(content)
        rig.resolver.isDeferred = true
        rig.resolver.processingDuration = 4
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        if isNewSessionAsk {
            rig.expireSession()
            rig.resolver.sessionEpoch = rig.currentSessionEpoch
            rig.presence.finishSessionCheck(startsNewSession: true)
        } else {
            rig.registry.blockAppeared("stories")
        }
        if isDelayed {
            rig.resolver.flush()
        }

        block.isActive = false
        rig.resolver.flush()
        rig.delayScheduler.fireAll()

        let parked = try #require(block.answers.last)
        #expect(block.applied == [.content(content)])
        #expect(rig.budget.reservations.isEmpty)

        let brought = rig.registry.bringOnScreen(parked, at: "stories")

        #expect(brought?.processingDuration == 4)
        #expect(rig.budget.reservedOwners == [.place("stories")])
    }

    @Test("A new session's delayed winner that another ask of the session re-selects mid-delay keeps the new session's ask: the delay running out after its block left takes no slot")
    func newSessionWinnerReselectedMidDelayTakesNoSlotOffScreen() throws {
        let rig = Rig()
        rig.resolver.resolution = .content(.delayed())
        rig.resolver.processingDuration = 4
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.expireSession()
        rig.resolver.sessionEpoch = rig.currentSessionEpoch
        rig.presence.finishSessionCheck(startsNewSession: true)
        rig.resolver.processingDuration = 1
        rig.registry.blockAppeared("stories")

        block.isActive = false
        rig.delayScheduler.fireAll()

        let parked = try #require(block.answers.last)
        #expect(block.applied == [.content(.delayed())])
        #expect(parked.processingDuration == 4)
        #expect(rig.budget.reservations.isEmpty)
    }

    @Test("A new session's ask queued behind a pass while its block was off screen counts its selection from the reset, the wait behind that pass included, when the block comes back before the ask runs, even with a config announced after the return",
          arguments: [false, true])
    func newSessionQueuedOffScreenCountsItsSelectionFromTheReset(configAnnouncedAfterTheReturn: Bool) {
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
        if configAnnouncedAfterTheReturn {
            rig.announceNewConfig()
        }
        rig.resolver.flush()
        rig.resolver.sessionEpoch = rig.currentSessionEpoch
        rig.presence.clock.advance(0.5)
        rig.resolver.processingDuration = 0.5
        rig.resolver.flush()

        #expect(block.processingDurations == [30.5])
    }

    @Test("A newer config announced while a pass flies does not ask again a place its block has left by the time the pass lands")
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

    @Test("A new session's ask that a block comes back to before it lands takes its slot on screen")
    func offScreenAskLandingAfterTheReturnTakesItsSlotOnScreen() {
        let rig = Rig()
        rig.resolver.isDeferred = true
        let block = BlockFake()
        block.isActive = false
        rig.registry.register(block, place: "stories")
        rig.expireSession()
        rig.resolver.sessionEpoch = rig.currentSessionEpoch
        rig.presence.finishSessionCheck(startsNewSession: true)

        block.isActive = true
        rig.registry.blockAppeared("stories")
        rig.resolver.flush()

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

    @Test("An answer asked while a block showed the place asks for the place's slot again when it is brought on screen, keeping its selection time")
    func answerAskedOnScreenAsksForItsSlotAgainWhenBroughtOnScreen() {
        let rig = Rig()
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.resolver.processingDuration = 2
        rig.registry.blockAppeared("stories")
        #expect(rig.budget.reservedOwners == [.place("stories")])

        let brought = rig.registry.bringOnScreen(block.answers[0], at: "stories")

        #expect(brought?.resolution == .content(.stub))
        #expect(brought?.processingDuration == 2)
        #expect(rig.budget.reservedOwners == [.place("stories"), .place("stories")])
    }

    @Test("A second block of the place, back on screen with an answer asked off screen, takes no new slot for the in-app the first one already shows")
    func offScreenAnswerOfAnInappThePlaceShowsTakesNoNewSlot() throws {
        let rig = Rig()
        let first = BlockFake()
        first.isActive = false
        let second = BlockFake()
        second.isActive = false
        rig.registry.register(first, place: "stories")
        rig.registry.register(second, place: "stories")
        rig.expireSession()
        rig.resolver.sessionEpoch = rig.currentSessionEpoch
        rig.presence.finishSessionCheck(startsNewSession: true)
        let parkedForFirst = try #require(first.answers.last)
        let parkedForSecond = try #require(second.answers.last)

        _ = rig.registry.bringOnScreen(parkedForFirst, at: "stories")
        SessionTemporaryStorage.shared.$ledger.mutate { $0.placeShownInappId["stories"] = EmbeddedBlockWebContent.stub.inAppId }
        let brought = rig.registry.bringOnScreen(parkedForSecond, at: "stories")

        #expect(brought?.resolution == .content(.stub))
        #expect(rig.budget.reservedOwners == [.place("stories")])
    }

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

    @Test("Content kept for the return's session check at several places takes their slots once the check ends in the order it was kept, and by place name when kept at the same time",
          arguments: [1.0, 0.0])
    func keptContentTakesTheSlotsInTheOrderItWasKept(timeBetweenKeeps: TimeInterval) {
        let rig = Rig()
        let places = ["stories", "promo", "hero", "footer", "feed", "banner"]
        let blocks = places.map { place in
            let block = BlockFake()
            rig.registry.register(block, place: place)
            return block
        }
        rig.presence.enterBackground()
        rig.presence.returnToApp()
        for place in places {
            rig.registry.blockAppeared(place)
            rig.presence.clock.advance(timeBetweenKeeps)
        }
        #expect(rig.budget.reservations.isEmpty)

        rig.presence.finishSessionCheck()

        let expectedOrder = timeBetweenKeeps > 0 ? places : places.sorted()
        #expect(rig.budget.reservedOwners == expectedOrder.map(InappShowBudgetOwner.place))
        #expect(blocks.allSatisfy { $0.applied == [.content(.stub)] })
    }

    @Test("Content kept for a check that ends while the app is not active stays kept until it is: a newer answer in between takes its place, and only that one arrives")
    func newerContentBeforeTheAppIsActiveReplacesTheKeptContent() {
        let rig = Rig()
        rig.resolver.isDeferred = true
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.registry.blockAppeared("stories")
        rig.presence.enterBackground()
        rig.presence.returnToApp()
        rig.resolver.flush()
        rig.presence.applicationState = .inactive
        rig.presence.finishSessionCheck()

        rig.resolver.resolution = .content(.other)
        rig.registry.blockAppeared("stories")
        rig.resolver.flush()
        #expect(block.applied.isEmpty)

        rig.presence.becomeActive()

        #expect(block.applied == [.content(.other)])
    }

    @Test("A new session's content kept for the return's session check and answered again before the check ends reaches the block with the session's first selection time")
    func keptContentAnsweredAgainKeepsTheFirstSelectionTime() {
        let rig = Rig()
        rig.resolver.isDeferred = true
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.presence.enterBackground()
        rig.presence.returnToApp()
        rig.expireSession()
        rig.resolver.sessionEpoch = rig.currentSessionEpoch
        rig.resolver.processingDuration = 4
        rig.presence.finishSessionCheck(startedAt: rig.presence.clock.now - 1, startsNewSession: true)
        rig.resolver.flush()

        rig.presence.clock.advance(1)
        rig.resolver.processingDuration = 0.5
        rig.registry.blockAppeared("stories")
        rig.resolver.flush()
        rig.presence.clock.advance(0.5)
        rig.presence.finishSessionCheck()

        #expect(block.applied == [.content(.stub)])
        #expect(block.processingDurations == [5.5])
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

    @Test("An operation between a return and the end of its session check is asked in the new session the check starts, with that session's own ask")
    func operationInsideTheReturnRidesTheNewSessionsAsk() {
        let rig = Rig()
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.presence.enterBackground()
        rig.presence.returnToApp()

        let operation = rig.announceOperation()
        #expect(rig.resolver.resolveCount == 0)

        rig.expireSession()
        rig.resolver.sessionEpoch = rig.currentSessionEpoch
        rig.presence.finishSessionCheck(startsNewSession: true)

        #expect(rig.resolver.triggers == [operation])
        #expect(block.answers.map(\.sessionEpoch) == [rig.currentSessionEpoch])
        #expect(block.answers.map(\.isOperationTriggered) == [false])
    }

    @Test("An operation that arrives after the return's session check has reset the session, before the check is announced, still rides the new session's ask")
    func operationAfterTheResetInsideTheReturnRidesTheNewSessionsAsk() {
        let rig = Rig()
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.presence.enterBackground()
        rig.presence.returnToApp()
        rig.expireSession()
        rig.resolver.sessionEpoch = rig.currentSessionEpoch

        let operation = rig.announceOperation()
        #expect(rig.resolver.resolveCount == 0)

        rig.presence.finishSessionCheck(startsNewSession: true)

        #expect(rig.resolver.triggers == [operation])
        #expect(block.answers.map(\.sessionEpoch) == [rig.currentSessionEpoch])
        #expect(block.answers.map(\.isOperationTriggered) == [false])
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

    @Test("A check that began before the return and starts a new session asks the places in that session, carrying the operation held since the return")
    func newSessionCheckFromBeforeTheReturnCarriesTheHeldOperation() {
        let rig = Rig()
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.presence.enterBackground()
        rig.presence.returnToApp()
        let operation = rig.announceOperation()

        rig.expireSession()
        rig.resolver.sessionEpoch = rig.currentSessionEpoch
        rig.presence.finishSessionCheck(startedAt: rig.presence.clock.now - 1, startsNewSession: true)
        #expect(rig.resolver.resolveCount == 1)
        #expect(rig.resolver.triggers == [operation])
        #expect(block.answers.isEmpty)

        rig.presence.finishSessionCheck()

        #expect(rig.resolver.resolveCount == 1)
        #expect(block.answers.map(\.sessionEpoch) == [rig.currentSessionEpoch])
        #expect(block.answers.map(\.isOperationTriggered) == [false])
    }

    @Test("Two operations between a return and the end of a session check that kept the session are both asked once the check ends, in the order they arrived")
    func twoOperationsInsideTheReturnOfAKeptSessionAreAskedInOrder() {
        let rig = Rig()
        rig.resolver.isDeferred = true
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.presence.enterBackground()
        rig.presence.returnToApp()
        let first = rig.announceOperation("first.operation")
        let second = rig.announceOperation("second.operation")

        rig.presence.finishSessionCheck()
        rig.resolver.flush()
        rig.resolver.flush()

        #expect(rig.resolver.triggers == [first, second])
        #expect(block.answers.map(\.isOperationTriggered) == [true, true])
    }

    @Test("Of two operations between a return and the end of a session check that starts a new session, the first rides the new session's ask and the second follows it as an operation")
    func ofTwoOperationsInsideTheReturnTheFirstRidesTheNewSessionsAsk() {
        let rig = Rig()
        rig.resolver.isDeferred = true
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.presence.enterBackground()
        rig.presence.returnToApp()
        let first = rig.announceOperation("first.operation")
        let second = rig.announceOperation("second.operation")

        rig.expireSession()
        rig.resolver.sessionEpoch = rig.currentSessionEpoch
        rig.presence.finishSessionCheck(startsNewSession: true)
        rig.resolver.flush()
        rig.resolver.flush()

        #expect(rig.resolver.triggers == [first, second])
        #expect(block.answers.map(\.sessionEpoch) == [rig.currentSessionEpoch, rig.currentSessionEpoch])
        #expect(block.answers.map(\.isOperationTriggered) == [false, true])
    }

    @Test("Of three operations between a return and the end of its session check, the first and the last are asked, whether the check keeps the session or starts a new one",
          arguments: [false, true])
    func ofThreeOperationsInsideTheReturnTheFirstAndTheLastAreAsked(startsNewSession: Bool) {
        let rig = Rig()
        rig.resolver.isDeferred = true
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.presence.enterBackground()
        rig.presence.returnToApp()
        let first = rig.announceOperation("first.operation")
        rig.announceOperation("second.operation")
        let third = rig.announceOperation("third.operation")

        if startsNewSession {
            rig.expireSession()
            rig.resolver.sessionEpoch = rig.currentSessionEpoch
        }
        rig.presence.finishSessionCheck(startsNewSession: startsNewSession)
        rig.resolver.flush()
        rig.resolver.flush()

        #expect(rig.resolver.triggers == [first, third])
        #expect(block.answers.map(\.isOperationTriggered) == [!startsNewSession, true])
    }

    @Test("A block appearing or a new config between a return and the end of its session check joins the first of two operations held for the place: both are asked in order, the second as an operation and the first as the operation it is when the check keeps the session, or as the new session's ask when it starts a new one",
          arguments: [false, true], [false, true])
    func appearanceOrConfigInsideTheReturnJoinsTheFirstHeldOperation(isNewConfig: Bool, startsNewSession: Bool) {
        let rig = Rig()
        rig.resolver.isDeferred = true
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.presence.enterBackground()
        rig.presence.returnToApp()
        let first = rig.announceOperation("first.operation")
        let second = rig.announceOperation("second.operation")
        if isNewConfig {
            rig.announceNewConfig()
        } else {
            rig.registry.blockAppeared("stories")
        }
        #expect(rig.resolver.resolveCount == 0)

        if startsNewSession {
            rig.expireSession()
            rig.resolver.sessionEpoch = rig.currentSessionEpoch
        }
        rig.presence.finishSessionCheck(startsNewSession: startsNewSession)
        rig.resolver.flush()
        rig.resolver.flush()

        #expect(rig.resolver.triggers == [first, second])
        #expect(block.answers.map(\.isOperationTriggered) == [!startsNewSession, true])
    }

    @Test("A block appearing or a new config between a return and the end of its session check joins the one operation held for the place: the place is asked once, as the operation it is when the check keeps the session, or as the new session's ask when it starts a new one",
          arguments: [false, true], [false, true])
    func appearanceOrConfigInsideTheReturnJoinsTheOneHeldOperation(isNewConfig: Bool, startsNewSession: Bool) {
        let rig = Rig()
        rig.resolver.isDeferred = true
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.presence.enterBackground()
        rig.presence.returnToApp()
        let operation = rig.announceOperation()
        if isNewConfig {
            rig.announceNewConfig()
        } else {
            rig.registry.blockAppeared("stories")
        }
        #expect(rig.resolver.resolveCount == 0)

        if startsNewSession {
            rig.expireSession()
            rig.resolver.sessionEpoch = rig.currentSessionEpoch
        }
        rig.presence.finishSessionCheck(startsNewSession: startsNewSession)
        rig.resolver.flush()

        #expect(rig.resolver.triggers == [operation])
        #expect(block.answers.map(\.isOperationTriggered) == [!startsNewSession])
    }

    @Test("A block appearing between a return and the end of its session check asks its place at once when the operations held are for another place")
    func appearanceInsideTheReturnAsksAtOnceWhenTheHeldOperationsAreForAnotherPlace() {
        let rig = Rig()
        let promo = BlockFake()
        rig.registry.register(promo, place: "promo")
        rig.presence.enterBackground()
        rig.presence.returnToApp()
        let operation = rig.announceOperation()
        let stories = BlockFake()
        rig.registry.register(stories, place: "stories")

        rig.registry.blockAppeared("stories")
        #expect(rig.resolver.resolvedPlaces == ["stories"])

        rig.presence.finishSessionCheck()

        #expect(rig.resolver.resolvedPlaces == ["stories", "promo"])
        #expect(rig.resolver.triggers == [nil, operation])
        #expect(stories.answers.map(\.isOperationTriggered) == [false])
        #expect(promo.answers.map(\.isOperationTriggered) == [true])
    }

    @Test("Of two operations between a return and the end of a session check that kept the session, only the second is asked when a pass of their place is in flight as the check ends")
    func ofTwoOperationsInsideTheReturnOfAKeptSessionOnlyTheSecondIsAskedBehindAPass() {
        let rig = Rig()
        rig.resolver.isDeferred = true
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.presence.enterBackground()
        rig.presence.returnToApp()
        rig.registry.blockAppeared("stories")
        rig.announceOperation("first.operation")
        let second = rig.announceOperation("second.operation")

        rig.presence.finishSessionCheck()
        rig.resolver.flush()
        rig.resolver.flush()

        #expect(rig.resolver.triggers == [nil, second])
        #expect(block.answers.map(\.isOperationTriggered) == [false, true])
    }

    @Test("Of two operations between a return and the end of a session check that starts a new session, only the second rides the new session's ask when a pass of their place is in flight as the check ends")
    func ofTwoOperationsInsideTheReturnOnlyTheSecondRidesTheNewSessionsAskBehindAPass() {
        let rig = Rig()
        rig.resolver.isDeferred = true
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.presence.enterBackground()
        rig.presence.returnToApp()
        rig.registry.blockAppeared("stories")
        rig.announceOperation("first.operation")
        let second = rig.announceOperation("second.operation")

        rig.expireSession()
        rig.presence.finishSessionCheck(startsNewSession: true)
        rig.resolver.flush()
        rig.resolver.sessionEpoch = rig.currentSessionEpoch
        rig.resolver.flush()

        #expect(rig.resolver.triggers == [nil, second])
        #expect(block.answers.map(\.sessionEpoch) == [rig.currentSessionEpoch])
        #expect(block.answers.map(\.isOperationTriggered) == [false])
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
        rig.resolver.isDeferred = true
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.registry.blockAppeared("stories")
        rig.expireSession()
        let answersSession = rig.currentSessionEpoch
        rig.resolver.sessionEpoch = answersSession

        rig.resolver.flush()

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

    @Test("Another winner answered between a return and the end of its session check cancels the delayed winner, whether its delay ran out while the app was away or runs out during the check: only the newer winner reaches the block and takes the slot, and no delay is marked served",
          arguments: [true, false])
    func newerWinnerInsideTheReturnCancelsTheDelayedWinner(didDelayRunOutAway: Bool) {
        let rig = Rig()
        rig.resolver.resolution = .content(.delayed())
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.registry.blockAppeared("stories")
        rig.resolver.isDeferred = true
        rig.announceOperation()
        rig.presence.enterBackground()
        if didDelayRunOutAway {
            rig.delayScheduler.fireAll()
        }

        rig.presence.returnToApp()
        rig.resolver.resolution = .content(.other)
        rig.resolver.flush()
        rig.delayScheduler.fireAll()
        rig.presence.finishSessionCheck()

        #expect(block.applied == [.content(.other)])
        #expect(rig.budget.reservations.map(\.inAppId) == [EmbeddedBlockWebContent.other.inAppId])
        #expect(SessionTemporaryStorage.shared.ledger.servedPlaceDelays.isEmpty)
    }

    @Test("The same delayed winner answered again between a return and the end of its session check keeps its running delay and the selection time of the answer that started it")
    func sameWinnerInsideTheReturnKeepsItsRunningDelay() {
        let rig = Rig()
        rig.resolver.resolution = .content(.delayed())
        rig.resolver.processingDuration = 0.3
        let block = BlockFake()
        rig.registry.register(block, place: "stories")
        rig.registry.blockAppeared("stories")
        rig.resolver.isDeferred = true
        rig.announceOperation()
        rig.presence.enterBackground()

        rig.presence.returnToApp()
        rig.resolver.resolution = .content(.delayed(params: ["fresh": .bool(true)]))
        rig.resolver.processingDuration = 2.5
        rig.resolver.flush()
        rig.presence.finishSessionCheck()

        #expect(rig.delayScheduler.armCount == 1)
        #expect(block.applied.isEmpty)

        rig.delayScheduler.fireAll()

        #expect(block.applied == [.content(.delayed(params: ["fresh": .bool(true)]))])
        #expect(block.processingDurations == [0.3])
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

    enum UnseenContent: CaseIterable {
        case alone
        case withAnotherBlockOnScreen
        case withAnotherBlockAwaitingTheCheck
        case shownInItsSession
        case ofAnEndedSession

        var givesTheSlotBack: Bool { self == .alone }
    }

    @Test("A block leaving with content the place answered while the app was away gives the place's slot back only when no other block of the place is on screen and the place has not shown that in-app in its session",
          arguments: UnseenContent.allCases)
    func unseenContentGivesTheSlotBack(_ unseen: UnseenContent) {
        let rig = Rig()
        let leaving = BlockFake()
        leaving.isActive = false
        let other = BlockFake()
        other.isActive = unseen == .withAnotherBlockOnScreen
        other.isStartPending = unseen == .withAnotherBlockAwaitingTheCheck
        rig.registry.register(leaving, place: "stories")
        rig.registry.register(other, place: "stories")
        let answer = EmbeddedBlockPlaceAnswer(resolution: .content(.stub),
                                              processingDuration: 0,
                                              sessionEpoch: rig.currentSessionEpoch,
                                              isOperationTriggered: false)
        if unseen == .shownInItsSession {
            SessionTemporaryStorage.shared.$ledger.mutate { $0.placeShownInappId["stories"] = EmbeddedBlockWebContent.stub.inAppId }
        }
        if unseen == .ofAnEndedSession {
            rig.expireSession()
        }

        rig.registry.giveSlotBack(answer, at: "stories")

        #expect(rig.budget.releases == (unseen.givesTheSlotBack ? [.place("stories")] : []))
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
