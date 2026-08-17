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

/// The three new ways into the selection: by place, by id, and the list a feed may draw. The config
/// behind them holds a block for `stories-list-container`, an unlimited direct-call story, an
/// ordinary modal, and a `once` direct-call story — the pair that shows the frequency rule.
///
/// The config also carries `validityPeriod` on every in-app, in all three shapes the backend sends —
/// including one long expired. iOS does not read the field at all, and the stub keeps it so that the
/// day someone starts reading it, these tests say what changed.
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
    }

    private let mapper: InappMapperProtocol
    private let dataFacade: MockInAppConfigurationDataFacade
    private let config: ConfigResponse

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
    }

    private func resolvePlace(_ place: String, trigger: ApplicationEvent? = nil) async -> InAppTransitionData? {
        await withCheckedContinuation { continuation in
            mapper.selectInappForPlace(place, trigger: trigger, config) { continuation.resume(returning: $0) }
        }
    }

    private func resolveId(_ id: String) async -> InAppTransitionData? {
        await withCheckedContinuation { continuation in
            mapper.getInAppById(id, config) { continuation.resume(returning: $0) }
        }
    }

    private func renderable(_ ids: [String]) async -> [String] {
        await withCheckedContinuation { continuation in
            mapper.getRenderableInappIds(ids, config) { answer in
                // The caller is what turns an answer into events: the selection no longer vouches by
                // itself, so a test that expects targeting has to deliver the answer like a block does.
                answer.vouch()
                continuation.resume(returning: answer.inappIds.sorted())
            }
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

    /// The block in this config has been out of its validity period since 2020, and it is drawn anyway:
    /// the field is not read on any path. It keeps arriving for every in-app and does not raise
    /// `sdkVersion.min`, so the day it starts being read has to be a decision — on both platforms at
    /// once, since neither reads it today.
    @Test("An expired validityPeriod does not keep a block from being drawn")
    func expiredValidityPeriodDoesNotStopThePlace() async throws {
        // The premise is asserted, not assumed: without it this test is a copy of the one above, and
        // stripping the field from the stub would leave it passing while claiming to prove something.
        let expiry = try #require(expiryInStub(ofInappWithId: Constants.blockId))
        let today = ISO8601DateFormatter.string(from: Date(),
                                                timeZone: TimeZone(secondsFromGMT: 0) ?? .current,
                                                formatOptions: [.withFullDate])
        // ISO dates sort the way they run, so a prefix comparison is enough and needs no parsing.
        #expect(expiry.prefix(today.count) < today)

        let resolved = try #require(await resolvePlace(Constants.place))
        #expect(resolved.inAppId == Constants.blockId)
    }

    /// Reads `validityPeriod.dateTimeUtc` straight out of the stub file: the SDK's own models dropped
    /// the field, so nothing else can report that it is still there.
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

    /// Selection is the only thing the block path still sends: the targeting operation for the in-app it
    /// picked.
    @Test("Resolving a place sends the targeting operation for the winner")
    func sendsTargetingForWinner() async {
        _ = await resolvePlace(Constants.place)
        #expect(dataFacade.trackTargetingCalls.contains { $0.id == Constants.blockId })
    }

    /// Both paths that answer a page repeat by design — a block reappears, an operation lands, a new
    /// config arrives — and the event says "this in-app was offered to this user", which stays true
    /// whether it is offered once or ten times. So the second answer adds nothing to the funnel.
    @Test("A place resolved again does not vouch for the same in-app twice")
    func placeVouchesOncePerSession() async {
        _ = await resolvePlace(Constants.place)
        _ = await resolvePlace(Constants.place)

        let vouched = dataFacade.trackTargetingCalls.filter { $0.id == Constants.blockId }
        #expect(vouched.count == 1)
    }

    /// A feed's question is its own occurrence — the same rule the operation targeting of overlays
    /// lives by: every occurrence is a new offer. A page that asks again is drawing the feed again,
    /// so every delivered answer vouches anew (in sync with Android).
    @Test("A feed asking again vouches for the same in-apps again")
    func feedVouchesPerDeliveredAnswer() async {
        _ = await renderable(everyId)
        _ = await renderable(everyId)

        let vouched = dataFacade.trackTargetingCalls.filter { $0.id == Constants.unlimitedStoryId }
        #expect(vouched.count == 2)
    }

    /// A new session is a new offer: the dedup lives in the session storage and goes away with it.
    @Test("A new session vouches for the in-app again")
    func newSessionVouchesAgain() async {
        _ = await resolvePlace(Constants.place)
        SessionTemporaryStorage.shared.erase()
        _ = await resolvePlace(Constants.place)

        let vouched = dataFacade.trackTargetingCalls.filter { $0.id == Constants.blockId }
        #expect(vouched.count == 2)
    }

    /// Picking an in-app for a place is not showing it. The show is written down when the block's page
    /// reports what it drew (`EmbeddedBlockWebViewProvider`), so an in-app the block never managed to
    /// draw spends nothing — and a resolve that answered a block already showing that page spends
    /// nothing twice.
    @Test("Resolving a place leaves the show history untouched")
    func writesNothingToShowHistory() async {
        _ = await resolvePlace(Constants.place)

        let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
        #expect(persistenceStorage.shownDatesByInApp?.isEmpty == true)
        #expect(SessionTemporaryStorage.shared.sessionShownInApps.isEmpty)
        #expect(persistenceStorage.lastInappStateChangeDate == nil)
    }

    /// The show budgets apply to a block the same way they apply to a modal, minus the one-at-a-time lock
    /// This block is `unlimited`, which is what the contract gives a block, so it walks
    /// past spent budgets exactly as an unlimited modal does.
    @Test("Spent show limits do not stop an unlimited block")
    func showLimitsDoNotStopAnUnlimitedBlock() async throws {
        spendEveryShowBudget()

        let resolved = try #require(await resolvePlace(Constants.place))
        #expect(resolved.inAppId == Constants.blockId)
    }

    /// And the other half of the same rule: a block whose frequency is not `unlimited` waits its turn
    /// like everyone else, so spent budgets leave its place empty. Off contract, on purpose — the day a
    /// config sends a block with a real frequency, this is what happens.
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

    /// A block the budgets stopped was not offered to anyone, so it is not vouched for either.
    @Test("A block stopped by the show limits is not vouched for")
    func blockedByBudgetsIsNotVouchedFor() async {
        spendEveryShowBudget()

        _ = await resolvePlace(Constants.cappedPlace)

        #expect(dataFacade.trackTargetingCalls.contains { $0.id == Constants.cappedBlockId } == false)
    }

    /// Somebody else has used up the session, the day and the interval.
    private func spendEveryShowBudget() {
        SessionTemporaryStorage.shared.inAppSettings = Settings.InAppSettings(maxInappsPerSession: 1,
                                                                             maxInappsPerDay: 1,
                                                                             minIntervalBetweenShows: "01:00:00")
        SessionTemporaryStorage.shared.sessionShownInApps = ["someone-else"]
        let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
        persistenceStorage.shownDatesByInApp = ["someone-else": [Date()]]
        persistenceStorage.lastInappStateChangeDate = Date()
    }

    /// The pull cannot see an operation-targeted in-app: the checker needs the operation's name, and a
    /// block asking for itself has none to give. This is what the push exists for.
    @Test("Without the operation the place falls back to the always-on block")
    func pullDoesNotSeeTheOperationTargetedBlock() async throws {
        let resolved = try #require(await resolvePlace(Constants.place))
        #expect(resolved.inAppId == Constants.blockId)
    }

    /// The push: the same resolve carrying the operation finds the in-app targeted at it, and catalog
    /// order decides between two candidates of equal priority.
    @Test("With the operation the place resolves to the operation-targeted block")
    func pushResolvesTheOperationTargetedBlock() async throws {
        let event = ApplicationEvent(name: Constants.operationName, model: nil)

        let resolved = try #require(await resolvePlace(Constants.place, trigger: event))

        #expect(resolved.inAppId == Constants.operationBlockId)
    }

    /// A different operation is nobody's trigger here: the place answers as if nothing happened.
    @Test("An unrelated operation changes nothing at the place")
    func unrelatedOperationChangesNothing() async throws {
        let event = ApplicationEvent(name: "some.other.operation", model: nil)

        let resolved = try #require(await resolvePlace(Constants.place, trigger: event))

        #expect(resolved.inAppId == Constants.blockId)
    }

    // MARK: - By id

    /// The story is direct-call only, and that is ignored on purpose: an in-app the page has already
    /// offered has to open.
    @Test("Resolving by id ignores display conditions")
    func resolvesByIdWithoutChecks() async throws {
        let resolved = try #require(await resolveId(Constants.unlimitedStoryId))
        #expect(resolved.inAppId == Constants.unlimitedStoryId)
    }

    /// A direct call shows blocks too, so a block's own id has to resolve — the caller routes it into the
    /// place it is addressed to instead of over the screen.
    @Test("Resolving a block by id gives the variant with its place")
    func resolvesBlockByIdWithItsPlace() async throws {
        let resolved = try #require(await resolveId(Constants.blockId))
        #expect(resolved.content.placeSystemName == Constants.place)
    }

    @Test("An unknown id resolves to nothing")
    func resolvesNothingForUnknownId() async {
        #expect(await resolveId("44444444-4444-4444-4444-444444444444") == nil)
    }

    // MARK: - What a feed may draw

    /// The chain is the trigger path's, minus one step: direct call would drop exactly the in-apps a
    /// feed is made of. A block is dropped because a feed does not open inside a feed.
    @Test("A feed may draw the stories and the modal, but not the block")
    func feedKeepsDirectCallAndDropsTheBlock() async {
        #expect(await renderable(everyId) == [Constants.unlimitedStoryId, Constants.modalId, Constants.onceStoryId].sorted())
    }

    /// The frequency rule the whole selection lives by: an unlimited story is never recorded, so being
    /// watched changes nothing — it stays in the feed and goes grey through localState.
    @Test("A watched unlimited story is still drawn")
    func feedKeepsAWatchedUnlimitedStory() async {
        let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
        persistenceStorage.shownDatesByInApp = [Constants.unlimitedStoryId: [Date()]]

        #expect(await renderable([Constants.unlimitedStoryId]) == [Constants.unlimitedStoryId])
    }

    /// The pair: a `once` story that has spent its budget is filtered here like on any other path —
    /// the feed asks the same selection everyone asks.
    @Test("A once story that was already shown is not drawn")
    func feedDropsASpentOnceStory() async {
        let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
        persistenceStorage.shownDatesByInApp = [Constants.onceStoryId: [Date()]]

        #expect(await renderable([Constants.onceStoryId]).isEmpty)
    }

    @Test("An id no config knows is not drawn")
    func feedDropsUnknownId() async {
        #expect(await renderable(["44444444-4444-4444-4444-444444444444"]).isEmpty)
    }

    /// The answer and its targeting events are one set: every allowed id is a targeted in-app, so what
    /// the page was offered is exactly what was vouched for. What the answer cut is not vouched for — the
    /// block's own id is asked about and dropped, and no event goes out for it.
    @Test("A feed vouches for every story it allows and for nothing it cuts")
    func feedVouchesForWhatItAllows() async {
        let allowed = await renderable(everyId)
        let vouched = Set(dataFacade.trackTargetingCalls.compactMap(\.id))

        #expect(vouched == Set(allowed))
        #expect(!vouched.contains(Constants.blockId))
    }

    /// A feed asks about itself, with no operation to give — so a story that only an operation targets
    /// is not drawn, however many times that operation has fired before. The same reason the pull cannot
    /// see an operation-targeted block: the checker needs the operation's name.
    @Test("A story only an operation targets is not drawn for a feed")
    func feedDropsAnOperationTargetedStory() async {
        #expect(await renderable([Constants.operationStoryId]).isEmpty)
    }

    // MARK: - The feed answers without the network

    /// The wire contract gives the page three seconds, so the feed is answered from what the session
    /// has already fetched — fail closed, in sync with Android. The place resolve that built the page
    /// is what ordinarily warms those caches, and it still fetches.
    @Test("A feed's question asks nothing of the network")
    func feedAsksNothingOfTheNetwork() async {
        _ = await renderable(everyId)

        #expect(dataFacade.fetchDependenciesCalls == 0)
    }

    @Test("A place resolve still fetches its dependencies")
    func placeResolveStillFetches() async {
        _ = await resolvePlace(Constants.place)

        #expect(dataFacade.fetchDependenciesCalls == 1)
    }

    /// Fail closed: a story whose targeting needs data nobody fetched is cut, not waited for. An
    /// unwarmed checker answers "not targeted" for a segment it knows nothing about.
    @Test("A segment story on a cold cache is cut from the feed")
    func coldCacheCutsASegmentStory() async {
        dataFacade.targetingChecker.checkedSegmentations = nil

        #expect(await renderable([Constants.segmentStoryId]).isEmpty)
    }

    /// The other half of fail closed: the same story is drawn as soon as the session already knows
    /// the segment — no fetch happens on the way.
    @Test("A segment story on a warm cache is drawn without a fetch")
    func warmCacheKeepsASegmentStory() async {
        dataFacade.targetingChecker.checkedSegmentations = [
            .init(segmentation: .init(ids: .init(externalId: "feed-segmentation")),
                  segment: .init(ids: .init(externalId: "feed-segment")))
        ]

        #expect(await renderable([Constants.segmentStoryId]) == [Constants.segmentStoryId])
        #expect(dataFacade.fetchDependenciesCalls == 0)
    }

    /// Answering a feed shows nothing, so the limits that budget shows have nothing to say about it —
    /// a spent daily cap must not empty a feed the user is looking at. Frequency is the one budget the
    /// answer does respect, and it has its own pair of tests above.
    @Test("Spent show limits do not shrink a feed's answer")
    func showLimitsDoNotShrinkTheFeedAnswer() async {
        SessionTemporaryStorage.shared.inAppSettings = Settings.InAppSettings(maxInappsPerSession: 1,
                                                                             maxInappsPerDay: 1,
                                                                             minIntervalBetweenShows: "01:00:00")
        SessionTemporaryStorage.shared.sessionShownInApps = ["someone-else"]
        let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
        persistenceStorage.shownDatesByInApp = ["someone-else": [Date()]]
        persistenceStorage.lastInappStateChangeDate = Date()

        #expect(await renderable([Constants.unlimitedStoryId]) == [Constants.unlimitedStoryId])
    }

    @Test("An empty question gets an empty answer")
    func feedAnswersNothingToNothing() async {
        #expect(await renderable([]).isEmpty)
    }

    /// Asking is not showing: the answer must leave no trace, or a feed drawn once would spend its
    /// stories' frequency budget without a single one being opened.
    @Test("Answering a feed writes nothing to the show history")
    func feedAnswerWritesNothingToShowHistory() async {
        _ = await renderable(everyId)

        let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
        #expect(persistenceStorage.shownDatesByInApp?.isEmpty == true)
        #expect(SessionTemporaryStorage.shared.sessionShownInApps.isEmpty)
    }

    // MARK: - Showing by id

    private func inappToShow(_ id: String, params: [String: JSONValue] = [:]) async -> InAppFormData? {
        await withCheckedContinuation { continuation in
            mapper.getInAppToShowById(id, params: params, config) { continuation.resume(returning: $0) }
        }
    }

    /// A story is a web page: there are no images to fetch, so the show is ready as soon as the config
    /// says which page it is.
    @Test("A direct-call story is ready to show")
    func directCallStoryIsReadyToShow() async throws {
        let formData = try #require(await inappToShow(Constants.onceStoryId))

        #expect(formData.inAppId == Constants.onceStoryId)
        #expect(formData.imagesDict.isEmpty)
    }

    /// The params the page sent travel with the show and are not read on the way.
    @Test("The caller's params travel with the show")
    func callerParamsTravelWithTheShow() async throws {
        let params: [String: JSONValue] = ["formId": .string("160477")]
        let formData = try #require(await inappToShow(Constants.onceStoryId, params: params))

        #expect(formData.extraParams == params)
    }

    /// On the trigger path an in-app that was already shown is skipped. Here the opposite has to hold:
    /// what the user just tapped opens however many times it has been opened before.
    @Test("A story already shown still opens")
    func alreadyShownStoryStillOpens() async throws {
        let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
        persistenceStorage.shownDatesByInApp = [Constants.onceStoryId: [Date()]]

        let formData = try #require(await inappToShow(Constants.onceStoryId))

        #expect(formData.inAppId == Constants.onceStoryId)
    }

    @Test("An id no config knows shows nothing")
    func unknownIdShowsNothing() async {
        #expect(await inappToShow("44444444-4444-4444-4444-444444444444") == nil)
    }

    /// A block's id resolves — a direct call may need its content — but showing means the overlay
    /// displayer, and a variant drawn inside the host layout has nothing to show there.
    @Test("A block's own id refuses to show over the screen")
    func blockIdDoesNotShowOverTheScreen() async {
        #expect(await inappToShow(Constants.blockId) == nil)
    }

    // MARK: - The trigger path on the same config

    /// The pair to the place cases: adding two entries must not change what the trigger path picks, and
    /// it must still refuse the block and the direct-call story.
    @Test("The trigger path still picks the ordinary modal")
    func triggerPathPicksModal() async throws {
        let formData: InAppFormData? = await withCheckedContinuation { continuation in
            mapper.handleInapps(nil, config) { continuation.resume(returning: $0) }
        }

        #expect(try #require(formData).inAppId == Constants.modalId)
    }

    /// A direct-call in-app answers no trigger, so the startup catch-up must not vouch for it either:
    /// otherwise every start pumps the story funnel with every user, block or no block. Its targeting
    /// travels with the explicit show instead.
    @Test("The startup catch-up vouches for no direct-call in-app")
    func catchUpSkipsDirectCallInapps() async {
        _ = await withCheckedContinuation { continuation in
            mapper.handleInapps(nil, config) { continuation.resume(returning: $0) }
        } as InAppFormData?

        #expect(!dataFacade.targetingArray.contains(Constants.unlimitedStoryId))
        #expect(!dataFacade.targetingArray.contains(Constants.onceStoryId))
    }
}
