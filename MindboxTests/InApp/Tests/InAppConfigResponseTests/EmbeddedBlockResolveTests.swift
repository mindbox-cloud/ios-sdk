//
//  EmbeddedBlockResolveTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import Testing
@_spi(Internal) @testable import Mindbox

private enum EmbeddedBlockConfig: String, Configurable {
    typealias DecodeType = ConfigResponse

    case config = "EmbeddedBlockConfig"
}

@Suite("Embedded block resolve", .tags(.embeddedBlocks))
struct EmbeddedBlockResolveTests {

    private enum Constants {
        static let place = "stories-list-container"
        static let blockId = "11111111-1111-1111-1111-111111111111"
        static let unlimitedStoryId = "22222222-2222-2222-2222-222222222222"
        static let modalId = "33333333-3333-3333-3333-333333333333"
        static let onceStoryId = "55555555-5555-5555-5555-555555555555"
        static let operationBlockId = "66666666-6666-6666-6666-666666666666"
        static let operationStoryId = "77777777-7777-7777-7777-777777777777"
        static let cappedPlace = "capped-block-place"
        static let cappedBlockId = "88888888-8888-8888-8888-888888888888"
        static let operationName = "block.refresh.operation"
        static let segmentStoryId = "99999999-9999-9999-9999-999999999999"
        static let mixedId = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
        static let abPlace = "ab-block-place"
        static let abBlockId = "cccccccc-cccc-cccc-cccc-cccccccccccc"
        static let directCallBlockId = "dddddddd-dddd-dddd-dddd-dddddddddddd"
        // The fixture's A/B test shares its salt with the overlay A/B fixture; these devices hash into its first and second branch.
        static let deviceKeepingAbBlock = "40909d27-4bef-4a8d-9164-6bfcf58ecc76"
        static let deviceCuttingAbBlock = "b4e0f767-fe8f-4825-9772-f1162f2db52d"
    }

    private let mapper: InappMapperProtocol
    private let dataFacade: MockInAppConfigurationDataFacade
    private let config: ConfigResponse
    private let candidates: ConfigCandidates

    init() throws {
        TestConfiguration.configure()
        SessionTemporaryStorage.shared.erase()

        let facade = DI.injectOrFail(InAppConfigurationDataFacadeProtocol.self)
        dataFacade = try #require(facade as? MockInAppConfigurationDataFacade,
                                  "The suite needs the mock facade so that resolving touches no network")
        mapper = DI.injectOrFail(InappMapperProtocol.self)
        config = try EmbeddedBlockConfig.config.getConfig()

        let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
        persistenceStorage.shownDatesByInApp = [:]
        persistenceStorage.deviceUUID = "00000000-0000-0000-0000-000000000000"

        candidates = config.candidates
    }

    private func resolvePlace(_ place: String,
                              trigger: ApplicationEvent? = nil,
                              candidates: ConfigCandidates? = nil) async -> InAppTransitionData? {
        await withCheckedContinuation { continuation in
            mapper.selectInappForPlace(place, trigger: trigger, candidates ?? self.candidates) { continuation.resume(returning: $0) }
        }
    }

    private func resolveId(_ id: String) async -> InAppTransitionData? {
        await withCheckedContinuation { continuation in
            mapper.getInAppById(id, candidates) { continuation.resume(returning: $0) }
        }
    }

    private func showable(_ ids: [String], askedBy blockInappId: String = Constants.blockId) async -> [String] {
        await showableInOrder(ids, askedBy: blockInappId).sorted()
    }

    private func showableInOrder(_ ids: [String], askedBy blockInappId: String = Constants.blockId) async -> [String] {
        await withCheckedContinuation { continuation in
            mapper.getShowableInappIds(ids, askedBy: blockInappId, candidates) { continuation.resume(returning: $0) }
        }
    }

    private var everyId: [String] {
        [Constants.blockId, Constants.unlimitedStoryId, Constants.modalId, Constants.onceStoryId]
    }

    // MARK: - By place

    @Test("A block gets the in-app set up for its place")
    func resolvesBlockForPlace() async throws {
        let resolved = try #require(await resolvePlace(Constants.place))
        #expect(resolved.inAppId == Constants.blockId)
        #expect(resolved.content.placeSystemName == Constants.place)
    }

    @Test("An unknown place resolves to nothing")
    func resolvesNothingForUnknownPlace() async {
        #expect(await resolvePlace("no-such-place") == nil)
    }

    /// `validityPeriod` is read on no path on either platform — the day it starts being read has to be a decision made on both at once.
    @Test("An expired validityPeriod does not keep a block from being drawn")
    func expiredValidityPeriodDoesNotStopThePlace() async throws {
        let expiry = try #require(expiryInStub(ofInappWithId: Constants.blockId))
        let today = ISO8601DateFormatter.string(from: Date(),
                                                timeZone: TimeZone(secondsFromGMT: 0) ?? .current,
                                                formatOptions: [.withFullDate])
        #expect(expiry.prefix(today.count) < today)

        let resolved = try #require(await resolvePlace(Constants.place))
        #expect(resolved.inAppId == Constants.blockId)
    }

    private func expiryInStub(ofInappWithId id: String) -> String? {
        guard let url = Bundle(for: MindboxTests.self).url(forResource: "EmbeddedBlockConfig", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let inapps = root["inapps"] as? [[String: Any]],
              let inapp = inapps.first(where: { $0["id"] as? String == id }) else {
            return nil
        }

        return (inapp["validityPeriod"] as? [String: Any])?["dateTimeUtc"] as? String
    }

    @Test("Resolving a place sends the targeting operation for the winner")
    func sendsTargetingForWinner() async {
        _ = await resolvePlace(Constants.place)
        #expect(dataFacade.trackTargetingCalls.contains { $0.id == Constants.blockId })
    }

    @Test("A place resolved again does not vouch for the same in-app twice")
    func placeVouchesOncePerSession() async {
        _ = await resolvePlace(Constants.place)
        _ = await resolvePlace(Constants.place)

        let vouched = dataFacade.trackTargetingCalls.filter { $0.id == Constants.blockId }
        #expect(vouched.count == 1)
    }

    @Test("A page asking again vouches for nothing it was already told about")
    func pageVouchesOncePerSession() async {
        _ = await showable(everyId)
        _ = await showable(everyId)

        let vouched = dataFacade.trackTargetingCalls.filter { $0.id == Constants.unlimitedStoryId }
        #expect(vouched.count == 1)
    }

    @Test("Another block asking about the same in-app vouches for it again")
    func anotherBlockVouchesAgain() async {
        _ = await showable(everyId, askedBy: Constants.blockId)
        _ = await showable(everyId, askedBy: Constants.mixedId)

        let vouched = dataFacade.trackTargetingCalls.filter { $0.id == Constants.unlimitedStoryId }
        #expect(vouched.count == 2)
    }

    @Test("A new session vouches for the page's in-apps again")
    func newSessionVouchesForThePageAgain() async {
        _ = await showable(everyId)
        SessionTemporaryStorage.shared.erase()
        _ = await showable(everyId)

        let vouched = dataFacade.trackTargetingCalls.filter { $0.id == Constants.unlimitedStoryId }
        #expect(vouched.count == 2)
    }

    @Test("An id asked twice is answered twice and vouched for once")
    func duplicateIdIsMirroredAndVouchedOnce() async {
        let answer = await showableInOrder([Constants.unlimitedStoryId, Constants.unlimitedStoryId])

        #expect(answer == [Constants.unlimitedStoryId, Constants.unlimitedStoryId])
        #expect(dataFacade.trackTargetingCalls.filter { $0.id == Constants.unlimitedStoryId }.count == 1)
    }

    @Test("The answer keeps the order the page asked in")
    func answerKeepsTheAskedOrder() async {
        #expect(await showableInOrder([Constants.modalId, Constants.unlimitedStoryId]) == [Constants.modalId, Constants.unlimitedStoryId])
        #expect(await showableInOrder([Constants.unlimitedStoryId, Constants.modalId]) == [Constants.unlimitedStoryId, Constants.modalId])
    }

    @Test("A new session vouches for the in-app again")
    func newSessionVouchesAgain() async {
        _ = await resolvePlace(Constants.place)
        SessionTemporaryStorage.shared.erase()
        _ = await resolvePlace(Constants.place)

        let vouched = dataFacade.trackTargetingCalls.filter { $0.id == Constants.blockId }
        #expect(vouched.count == 2)
    }

    @Test("Resolving a place leaves the show history untouched")
    func writesNothingToShowHistory() async {
        _ = await resolvePlace(Constants.place)

        let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
        #expect(persistenceStorage.shownDatesByInApp?.isEmpty == true)
        #expect(SessionTemporaryStorage.shared.sessionShownInApps.isEmpty)
        #expect(persistenceStorage.lastInappStateChangeDate == nil)
    }

    @Test("A place resolve that picked a winner drops the pass's buffered failures, like the overlay's pass")
    func placeResolveWithWinnerDropsBufferedFailures() async {
        _ = await resolvePlace(Constants.place)

        #expect(dataFacade.discardCollectedFailuresCalls == 1)
        #expect(dataFacade.sendCollectedFailuresCalls == 0)
    }

    @Test("A place resolve that picked nothing sends the pass's buffered failures")
    func placeResolveWithoutWinnerSendsBufferedFailures() async {
        _ = await resolvePlace("place-nobody-addresses")

        #expect(dataFacade.sendCollectedFailuresCalls == 1)
        #expect(dataFacade.discardCollectedFailuresCalls == 0)
    }

    @Test("A place resolve hands the in-apps its targeting cut to the failure collection")
    func placeResolveCollectsFailuresForTheCut() async {
        _ = await resolvePlace(Constants.place)

        #expect(dataFacade.collectedTargetingFailureIds == [Set([Constants.operationBlockId])])
    }

    /// Logged as a mistake at config mapping, but kept: a direct call still has to open it.
    @Test("A direct-call in-app targeted by an operation is still a valid in-app")
    func directCallWithOperationTargetingStaysValid() {
        #expect(candidates.renderable.contains { $0.id == Constants.operationStoryId })
    }

    @Test("Spent show limits do not stop an unlimited block")
    func showLimitsDoNotStopAnUnlimitedBlock() async throws {
        spendEveryShowBudget()

        let resolved = try #require(await resolvePlace(Constants.place))
        #expect(resolved.inAppId == Constants.blockId)
    }

    @Test("Spent show limits leave a non-unlimited block's place empty")
    func showLimitsStopANonUnlimitedBlock() async {
        spendEveryShowBudget()

        #expect(await resolvePlace(Constants.cappedPlace) == nil)
    }

    @Test("Without spent budgets the same block is drawn")
    func nonUnlimitedBlockIsDrawnWithBudgetsLeft() async throws {
        let resolved = try #require(await resolvePlace(Constants.cappedPlace))
        #expect(resolved.inAppId == Constants.cappedBlockId)
    }

    @Test("A block stopped by the show limits is still vouched for")
    func blockedByBudgetsIsStillVouchedFor() async {
        spendEveryShowBudget()

        #expect(await resolvePlace(Constants.cappedPlace) == nil)
        #expect(dataFacade.trackTargetingCalls.contains { $0.id == Constants.cappedBlockId })
    }

    @Test("Resolving a place vouches for every targeted in-app set up for it, not only the winner")
    func placeVouchesForTheLosersToo() async throws {
        let event = ApplicationEvent(name: Constants.operationName, model: nil)

        let resolved = try #require(await resolvePlace(Constants.place, trigger: event))

        #expect(resolved.inAppId == Constants.operationBlockId)
        #expect(Set(dataFacade.trackTargetingCalls.compactMap(\.id)) == [Constants.operationBlockId, Constants.blockId])
    }

    @Test("A place in-app spent by its frequency still gets its targeting")
    func spentPlaceInappIsStillVouchedFor() async {
        let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
        persistenceStorage.shownDatesByInApp = [Constants.cappedBlockId: [Date()]]

        #expect(await resolvePlace(Constants.cappedPlace) == nil)
        #expect(dataFacade.trackTargetingCalls.contains { $0.id == Constants.cappedBlockId })
    }

    @Test("A place in-app the A/B branch cut still gets its targeting")
    func abCutPlaceInappIsStillVouchedFor() async {
        let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
        persistenceStorage.deviceUUID = Constants.deviceCuttingAbBlock

        #expect(await resolvePlace(Constants.abPlace, candidates: config.candidates) == nil)
        #expect(dataFacade.trackTargetingCalls.contains { $0.id == Constants.abBlockId })
    }

    @Test("In the A/B branch that keeps it, the in-app wins its place")
    func abKeptPlaceInappWins() async throws {
        let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
        persistenceStorage.deviceUUID = Constants.deviceKeepingAbBlock

        let resolved = try #require(await resolvePlace(Constants.abPlace, candidates: config.candidates))
        #expect(resolved.inAppId == Constants.abBlockId)
    }

    @Test("A direct-call in-app at the place is not vouched for by the resolve")
    func directCallPlaceInappIsNotVouchedFor() async throws {
        let resolved = try #require(await resolvePlace(Constants.place))

        #expect(resolved.inAppId == Constants.blockId)
        #expect(dataFacade.trackTargetingCalls.contains { $0.id == Constants.directCallBlockId } == false)
    }

    @Test("A place that goes back to an earlier winner vouches for it again")
    func returningWinnerIsVouchedForAgain() async {
        let event = ApplicationEvent(name: Constants.operationName, model: nil)

        _ = await resolvePlace(Constants.place)
        _ = await resolvePlace(Constants.place, trigger: event)
        _ = await resolvePlace(Constants.place)

        let ids = dataFacade.trackTargetingCalls.compactMap(\.id)
        #expect(ids.filter { $0 == Constants.blockId }.count == 2)
        #expect(ids.filter { $0 == Constants.operationBlockId }.count == 1)
    }

    private func spendEveryShowBudget() {
        SessionTemporaryStorage.shared.inAppSettings = Settings.InAppSettings(maxInappsPerSession: 1,
                                                                             maxInappsPerDay: 1,
                                                                             minIntervalBetweenShows: "01:00:00")
        SessionTemporaryStorage.shared.sessionShownInApps = ["someone-else"]
        let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
        persistenceStorage.shownDatesByInApp = ["someone-else": [Date()]]
        persistenceStorage.lastInappStateChangeDate = Date()
    }

    @Test("Without the operation the place falls back to the always-on block")
    func pullDoesNotSeeTheOperationTargetedBlock() async throws {
        let resolved = try #require(await resolvePlace(Constants.place))
        #expect(resolved.inAppId == Constants.blockId)
    }

    @Test("With the operation the place resolves to the operation-targeted block")
    func pushResolvesTheOperationTargetedBlock() async throws {
        let event = ApplicationEvent(name: Constants.operationName, model: nil)

        let resolved = try #require(await resolvePlace(Constants.place, trigger: event))

        #expect(resolved.inAppId == Constants.operationBlockId)
    }

    @Test("An unrelated operation changes nothing at the place")
    func unrelatedOperationChangesNothing() async throws {
        let event = ApplicationEvent(name: "some.other.operation", model: nil)

        let resolved = try #require(await resolvePlace(Constants.place, trigger: event))

        #expect(resolved.inAppId == Constants.blockId)
    }

    // MARK: - By id

    @Test("Resolving by id ignores display conditions")
    func resolvesByIdWithoutChecks() async throws {
        let resolved = try #require(await resolveId(Constants.unlimitedStoryId))
        #expect(resolved.inAppId == Constants.unlimitedStoryId)
    }

    @Test("Resolving a block by id gives the variant with its place")
    func resolvesBlockByIdWithItsPlace() async throws {
        let resolved = try #require(await resolveId(Constants.blockId))
        #expect(resolved.content.placeSystemName == Constants.place)
    }

    @Test("An unknown id resolves to nothing")
    func resolvesNothingForUnknownId() async {
        #expect(await resolveId("44444444-4444-4444-4444-444444444444") == nil)
    }

    // MARK: - What a page may draw

    @Test("A page may draw the stories and the modal, but not the block")
    func feedKeepsDirectCallAndDropsTheBlock() async {
        #expect(await showable(everyId) == [Constants.unlimitedStoryId, Constants.modalId, Constants.onceStoryId].sorted())
    }

    @Test("A watched unlimited story is still drawn")
    func feedKeepsAWatchedUnlimitedStory() async {
        let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
        persistenceStorage.shownDatesByInApp = [Constants.unlimitedStoryId: [Date()]]

        #expect(await showable([Constants.unlimitedStoryId]) == [Constants.unlimitedStoryId])
    }

    @Test("A once story that was already shown is not drawn")
    func feedDropsASpentOnceStory() async {
        let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
        persistenceStorage.shownDatesByInApp = [Constants.onceStoryId: [Date()]]

        #expect(await showable([Constants.onceStoryId]).isEmpty)
    }

    @Test("An id no config knows is not drawn")
    func feedDropsUnknownId() async {
        #expect(await showable(["44444444-4444-4444-4444-444444444444"]).isEmpty)
    }

    @Test("A page vouches for every story it allows and for nothing it cuts")
    func feedVouchesForWhatItAllows() async {
        let allowed = await showable(everyId)
        let vouched = Set(dataFacade.trackTargetingCalls.compactMap(\.id))

        #expect(vouched == Set(allowed))
        #expect(!vouched.contains(Constants.blockId))
    }

    @Test("A story only an operation targets is not drawn for a page")
    func feedDropsAnOperationTargetedStory() async {
        #expect(await showable([Constants.operationStoryId]).isEmpty)
    }

    // MARK: - The page's question and the network

    @Test("A page's question fetches the pass's dependencies like a place resolve")
    func pageQuestionFetchesLikeAPlace() async {
        _ = await showable(everyId)

        #expect(dataFacade.fetchDependenciesCalls == 1)
    }

    @Test("A place resolve still fetches its dependencies")
    func placeResolveStillFetches() async {
        _ = await resolvePlace(Constants.place)

        #expect(dataFacade.fetchDependenciesCalls == 1)
    }

    @Test("A segment story is cut when the fetch brings no segmentations")
    func coldCacheCutsASegmentStory() async {
        dataFacade.targetingChecker.checkedSegmentations = nil

        #expect(await showable([Constants.segmentStoryId]).isEmpty)
    }

    @Test("A segment story on a warm cache is drawn")
    func warmCacheKeepsASegmentStory() async {
        dataFacade.targetingChecker.checkedSegmentations = [
            .init(segmentation: .init(ids: .init(externalId: "feed-segmentation")),
                  segment: .init(ids: .init(externalId: "feed-segment")))
        ]

        #expect(await showable([Constants.segmentStoryId]) == [Constants.segmentStoryId])
    }

    @Test("Spent show limits do not shrink a page's answer")
    func showLimitsDoNotShrinkThePagesAnswer() async {
        spendEveryShowBudget()

        #expect(await showable([Constants.unlimitedStoryId]) == [Constants.unlimitedStoryId])
    }

    @Test("An empty question gets an empty answer")
    func feedAnswersNothingToNothing() async {
        #expect(await showable([]).isEmpty)
    }

    @Test("Answering a page writes nothing to the show history")
    func feedAnswerWritesNothingToShowHistory() async {
        _ = await showable(everyId)

        let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
        #expect(persistenceStorage.shownDatesByInApp?.isEmpty == true)
        #expect(SessionTemporaryStorage.shared.sessionShownInApps.isEmpty)
    }

    // MARK: - Showing by id

    private func inappToShow(_ id: String, params: [String: JSONValue] = [:]) async -> InAppFormData? {
        await withCheckedContinuation { continuation in
            mapper.getInAppToShowById(id, params: params, candidates) { continuation.resume(returning: $0) }
        }
    }

    @Test("A direct-call story is ready to show")
    func directCallStoryIsReadyToShow() async throws {
        let formData = try #require(await inappToShow(Constants.onceStoryId))

        #expect(formData.inAppId == Constants.onceStoryId)
        #expect(formData.imagesDict.isEmpty)
    }

    @Test("The caller's params travel with the show")
    func callerParamsTravelWithTheShow() async throws {
        let params: [String: JSONValue] = ["formId": .string("160477")]
        let formData = try #require(await inappToShow(Constants.onceStoryId, params: params))

        #expect(formData.extraParams == params)
    }

    @Test("A story tap after an operation pass carries no leftover operation")
    func storyTapCarriesNoLeftoverOperation() async throws {
        let event = ApplicationEvent(name: Constants.operationName, model: nil)
        _ = await resolvePlace(Constants.place, trigger: event)

        let formData = try #require(await inappToShow(Constants.onceStoryId))

        #expect(formData.operation == nil)
    }

    @Test("A story already shown still opens")
    func alreadyShownStoryStillOpens() async throws {
        let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
        persistenceStorage.shownDatesByInApp = [Constants.onceStoryId: [Date()]]

        let formData = try #require(await inappToShow(Constants.onceStoryId))

        #expect(formData.inAppId == Constants.onceStoryId)
    }

    /// The page offers a mixed form because it has an overlay variant; the tap has to open that one
    /// even though the embedded variant comes first in the config.
    @Test("A tap on a mixed form opens its overlay variant")
    func mixedFormTapOpensTheOverlayVariant() async throws {
        let formData = try #require(await inappToShow(Constants.mixedId))

        #expect(formData.inAppId == Constants.mixedId)
        #expect(formData.content.isOverlayPresentable)
    }

    @Test("An id no config knows shows nothing")
    func unknownIdShowsNothing() async {
        #expect(await inappToShow("44444444-4444-4444-4444-444444444444") == nil)
    }

    @Test("A block's own id refuses to show over the screen")
    func blockIdDoesNotShowOverTheScreen() async {
        #expect(await inappToShow(Constants.blockId) == nil)
    }

    // MARK: - The trigger path on the same config

    @Test("The trigger path still picks the ordinary modal")
    func triggerPathPicksModal() async throws {
        let formData: InAppFormData? = await withCheckedContinuation { continuation in
            mapper.handleInapps(nil, candidates) { continuation.resume(returning: $0) }
        }

        #expect(try #require(formData).inAppId == Constants.modalId)
    }

    @Test("The startup catch-up vouches for no direct-call in-app")
    func catchUpSkipsDirectCallInapps() async {
        _ = await withCheckedContinuation { continuation in
            mapper.handleInapps(nil, candidates) { continuation.resume(returning: $0) }
        } as InAppFormData?

        #expect(!dataFacade.targetingArray.contains(Constants.unlimitedStoryId))
        #expect(!dataFacade.targetingArray.contains(Constants.onceStoryId))
    }

    /// A mixed form's overlay half stays the catch-up's — in sync with Android.
    @Test("The startup catch-up vouches for no in-app without an overlay variant")
    func catchUpSkipsPureEmbeddedInapps() async {
        _ = await withCheckedContinuation { continuation in
            mapper.handleInapps(nil, candidates) { continuation.resume(returning: $0) }
        } as InAppFormData?

        #expect(!dataFacade.targetingArray.contains(Constants.blockId))
        #expect(!dataFacade.targetingArray.contains(Constants.cappedBlockId))
        #expect(dataFacade.targetingArray.contains(Constants.mixedId))
    }

    @Test("A page keeps a mixed in-app — its overlay half can be drawn")
    func feedKeepsAMixedInapp() async {
        #expect(await showable([Constants.mixedId]) == [Constants.mixedId])
    }
}
