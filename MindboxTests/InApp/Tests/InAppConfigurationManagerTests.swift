//
//  InAppConfigurationManagerTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import Testing
import QuartzCore
import class MindboxLogger.Locked
@testable import Mindbox

private let sessionEpochKey = Constants.Notification.sessionEpoch

@Suite("In-app configuration manager", .tags(.embeddedBlocks))
struct InAppConfigurationManagerTests {

    private enum Constants {
        static let liveStoryId = "55555555-5555-5555-5555-555555555555"
    }

    /// Answers land on the manager's queue while the test polls from its own thread — the box keeps that race-free.
    private final class Answers<Value> {
        @Locked private var storage: [Value] = []

        var all: [Value] { storage }
        var first: Value? { storage.first }
        var isEmpty: Bool { storage.isEmpty }

        func append(_ value: Value) {
            storage.append(value)
        }
    }

    /// A manager's own notification center, and every download conclusion announced on it.
    private final class ConclusionLog {
        let center = NotificationCenter()
        let announced = Answers<Int?>()
        private var observer: NSObjectProtocol?

        init() {
            observer = center.addObserver(forName: .mobileConfigDownloadConcluded, object: nil, queue: nil) { [announced] in
                announced.append($0.userInfo?[sessionEpochKey] as? Int)
            }
        }

        deinit {
            if let observer {
                center.removeObserver(observer)
            }
        }
    }

    /// Poll `isFetchPending` before delivering — a result delivered into a fetch that has not started yet would vanish.
    /// Fetches are held in the order they started; `deliver` answers the oldest.
    private final class HeldConfigAPI: InAppConfigurationAPI {
        private let lock = NSLock()
        private var held: [(InAppConfigurationAPIResult) -> Void] = []

        var pendingFetches: Int {
            lock.lock()
            defer { lock.unlock() }
            return held.count
        }

        var isFetchPending: Bool { pendingFetches > 0 }

        init() {
            super.init(persistenceStorage: MockPersistenceStorage())
        }

        override func fetchConfig(completionQueue: DispatchQueue, completion: @escaping (InAppConfigurationAPIResult) -> Void) {
            lock.lock()
            held.append { result in completionQueue.async { completion(result) } }
            lock.unlock()
        }

        func deliver(_ result: InAppConfigurationAPIResult) {
            deliver(result, takingNewest: false)
        }

        func deliverToNewest(_ result: InAppConfigurationAPIResult) {
            deliver(result, takingNewest: true)
        }

        private func deliver(_ result: InAppConfigurationAPIResult, takingNewest: Bool) {
            lock.lock()
            let pending = held.isEmpty ? nil : (takingNewest ? held.removeLast() : held.removeFirst())
            lock.unlock()

            pending?(result)
        }
    }

    /// No disk: the cache must not leak between tests, and a failure path must find it empty.
    private final class EmptyConfigRepository: InAppConfigurationRepository {
        override func fetchConfigFromCache() -> Data? { nil }
        override func saveConfigToCache(_ data: Data) {}
        override func clean() {}
    }

    /// Counts the config-only work the manager is supposed to do once per applied config, and
    /// forwards everything else to the real service.
    private final class CountingFilterService: InappFilterProtocol {
        private let wrapped = DI.injectOrFail(InappFilterProtocol.self)
        @Locked private(set) var prepareCount = 0

        func candidates(from response: ConfigResponse) -> ConfigCandidates {
            prepareCount += 1
            return wrapped.candidates(from: response)
        }

        func filterForTrigger(in candidates: ConfigCandidates) -> [InApp] {
            wrapped.filterForTrigger(in: candidates)
        }

        func filter(place: String, in candidates: ConfigCandidates) -> [InApp] {
            wrapped.filter(place: place, in: candidates)
        }

        func inapps(addressedTo place: String, in candidates: ConfigCandidates) -> [InApp] {
            wrapped.inapps(addressedTo: place, in: candidates)
        }

        func inapps(askedAbout ids: [String], in candidates: ConfigCandidates) -> [InApp] {
            wrapped.inapps(askedAbout: ids, in: candidates)
        }

        func filter(requestedIds ids: [String], in candidates: ConfigCandidates) -> [InApp] {
            wrapped.filter(requestedIds: ids, in: candidates)
        }

        func filter(id: String, in candidates: ConfigCandidates) -> InApp? {
            wrapped.filter(id: id, in: candidates)
        }

        func filterInappsByOperation(event: ApplicationEvent?,
                                     operationInapps: [String: Set<String>],
                                     in candidates: ConfigCandidates) -> [InApp] {
            wrapped.filterInappsByOperation(event: event, operationInapps: operationInapps, in: candidates)
        }

        func filterOutNonOverlayInapps(_ inapps: [InApp]) -> [InApp] {
            wrapped.filterOutNonOverlayInapps(inapps)
        }

        func filterInappsByOperationForShow(event: ApplicationEvent?,
                                            operationInapps: [String: Set<String>],
                                            in candidates: ConfigCandidates) -> [InApp] {
            wrapped.filterInappsByOperationForShow(event: event, operationInapps: operationInapps, in: candidates)
        }

        func filterInappsByTargeting(inapps: [InApp],
                                     targetingChecker: InAppTargetingCheckerProtocol,
                                     pickVariant: (InApp) -> MindboxFormVariant?) -> [InAppTransitionData] {
            wrapped.filterInappsByTargeting(inapps: inapps, targetingChecker: targetingChecker, pickVariant: pickVariant)
        }
    }

    private let api = HeldConfigAPI()
    private let manager: InAppConfigurationManager

    init() {
        TestConfiguration.configure()
        SessionTemporaryStorage.shared.erase()

        let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
        persistenceStorage.shownDatesByInApp = [:]
        persistenceStorage.deviceUUID = "00000000-0000-0000-0000-000000000000"

        manager = Self.makeManager(api: api, configWaitBudget: 0.2)
    }

    private static func makeManager(api: InAppConfigurationAPI,
                                    configWaitBudget: TimeInterval,
                                    inappFilterService: InappFilterProtocol = DI.injectOrFail(InappFilterProtocol.self),
                                    now: @escaping () -> TimeInterval = { CACurrentMediaTime() },
                                    notificationCenter: NotificationCenter = .default) -> InAppConfigurationManager {
        InAppConfigurationManager(
            inAppConfigAPI: api,
            inAppConfigRepository: EmptyConfigRepository(),
            inappMapper: DI.injectOrFail(InappMapperProtocol.self),
            persistenceStorage: DI.injectOrFail(PersistenceStorage.self),
            featureToggleManager: DI.injectOrFail(FeatureToggleManager.self),
            webViewPrewarmService: DI.injectOrFail(InAppWebViewPrewarmServiceProtocol.self),
            inappFilterService: inappFilterService,
            configWaitBudget: configWaitBudget,
            now: now,
            notificationCenter: notificationCenter
        )
    }

    private func fixtureData() throws -> Data {
        let bundle = Bundle(for: MindboxTests.self)
        let url = try #require(bundle.url(forResource: "EmbeddedBlockConfig", withExtension: "json"))
        return try Data(contentsOf: url)
    }

    private func fixtureData(editingInapps edit: (inout [[String: Any]]) throws -> Void) throws -> Data {
        var root = try #require(try JSONSerialization.jsonObject(with: fixtureData()) as? [String: Any])
        var inapps = try #require(root["inapps"] as? [[String: Any]])
        try edit(&inapps)
        root["inapps"] = inapps
        return try JSONSerialization.data(withJSONObject: root)
    }

    enum DownloadOutcome: CaseIterable {
        case config
        case configWithoutSettings
        case nothing
        case failure
    }

    private func result(_ outcome: DownloadOutcome) throws -> InAppConfigurationAPIResult {
        switch outcome {
        case .config:
            return .data(try fixtureData())
        case .configWithoutSettings:
            var root = try #require(try JSONSerialization.jsonObject(with: fixtureData()) as? [String: Any])
            root["settings"] = nil
            return .data(try JSONSerialization.data(withJSONObject: root))
        case .nothing:
            return .empty
        case .failure:
            return .error(MindboxError.connectionError)
        }
    }

    private func waitUntil(_ condition: @autoclosure () -> Bool,
                           sourceLocation: SourceLocation = #_sourceLocation) async throws {
        let step: UInt64 = 20_000_000
        let ceiling = 200

        for _ in 0..<ceiling where !condition() {
            try await Task.sleep(nanoseconds: step)
        }

        #expect(condition(), "gave up after \(Double(ceiling) * Double(step) / 1_000_000_000)s", sourceLocation: sourceLocation)
    }

    @Test("A caller arriving before the config is answered when it lands")
    func callerBeforeConfigIsAnsweredOnArrival() async throws {
        manager.prepareConfiguration()
        try await waitUntil(api.isFetchPending)

        let answers = Answers<[String]?>()
        manager.getShowableInappIds([Constants.liveStoryId], askedBy: "a-block") { answers.append($0) }

        api.deliver(.data(try fixtureData()))

        try await waitUntil(!answers.isEmpty)
        #expect(answers.all == [[Constants.liveStoryId]])
    }

    @Test("A caller arriving after the config is answered from it")
    func callerAfterConfigIsAnsweredRightAway() async throws {
        manager.prepareConfiguration()
        try await waitUntil(api.isFetchPending)
        api.deliver(.data(try fixtureData()))

        let answers = Answers<[String]?>()
        manager.getShowableInappIds([Constants.liveStoryId], askedBy: "a-block") { answers.append($0) }

        try await waitUntil(!answers.isEmpty)
        #expect(answers.all == [[Constants.liveStoryId]])
    }

    @Test("A config that never arrives refuses the page after the budget instead of answering with nothing")
    func neverArrivingConfigIsRefusedAfterTheBudget() async throws {
        manager.prepareConfiguration()

        let answers = Answers<[String]?>()
        manager.getShowableInappIds([Constants.liveStoryId], askedBy: "a-block") { answers.append($0) }

        try await waitUntil(!answers.isEmpty)
        #expect(answers.all == [nil])
    }

    @Test("A config is in hand only once the download concluded with one")
    func hasConfigFollowsTheDownload() async throws {
        #expect(!manager.hasConfig)
        manager.prepareConfiguration()
        try await waitUntil(api.isFetchPending)
        #expect(!manager.hasConfig)

        api.deliver(.data(try fixtureData()))

        try await waitUntil(manager.hasConfig)
    }

    @Test("A failed download with no cache refuses the page at once")
    func failedDownloadIsRefusedWithoutWaitingOutTheBudget() async throws {
        let slowBudgetManager = Self.makeManager(api: api, configWaitBudget: 60)
        slowBudgetManager.prepareConfiguration()
        try await waitUntil(api.isFetchPending)

        let answers = Answers<[String]?>()
        slowBudgetManager.getShowableInappIds([Constants.liveStoryId], askedBy: "a-block") { answers.append($0) }
        api.deliver(.error(MindboxError.connectionError))

        try await waitUntil(!answers.isEmpty)
        #expect(answers.all == [nil])
    }

    @Test("A caller who gave up waiting is not answered again when the config lands")
    func callerThatGaveUpIsNotAnsweredTwice() async throws {
        manager.prepareConfiguration()
        try await waitUntil(api.isFetchPending)

        let answers = Answers<[String]?>()
        manager.getShowableInappIds([Constants.liveStoryId], askedBy: "a-block") { answers.append($0) }
        try await waitUntil(!answers.isEmpty)

        api.deliver(.data(try fixtureData()))
        try await waitUntil(self.api.isFetchPending == false)

        #expect(answers.all == [nil])
    }

    @Test("A caller arriving after a failed download is refused at once")
    func callerAfterFailedDownloadDoesNotWaitOutTheBudget() async throws {
        let slowBudgetManager = Self.makeManager(api: api, configWaitBudget: 60)
        slowBudgetManager.prepareConfiguration()
        try await waitUntil(api.isFetchPending)
        api.deliver(.error(MindboxError.connectionError))

        let answers = Answers<[String]?>()
        slowBudgetManager.getShowableInappIds([Constants.liveStoryId], askedBy: "a-block") { answers.append($0) }

        try await waitUntil(!answers.isEmpty)
        #expect(answers.all == [nil])
    }

    @Test("A place asked while a download fails without a cache hears that the config is unavailable")
    func placeHearsConfigUnavailableWhenTheDownloadFails() async throws {
        let slowBudgetManager = Self.makeManager(api: api, configWaitBudget: 60)
        slowBudgetManager.prepareConfiguration()
        try await waitUntil(api.isFetchPending)

        let answers = Answers<EmbeddedPlaceSelection>()
        slowBudgetManager.selectInappForPlace("stories-list-container", trigger: nil) { answer, _, _ in answers.append(answer) }
        api.deliver(.error(MindboxError.connectionError))

        try await waitUntil(!answers.isEmpty)
        #expect(answers.all == [.configUnavailable])
    }

    @Test("A place asked after a failed download hears that the config is unavailable at once")
    func placeAfterFailedDownloadHearsConfigUnavailable() async throws {
        let slowBudgetManager = Self.makeManager(api: api, configWaitBudget: 60)
        slowBudgetManager.prepareConfiguration()
        try await waitUntil(api.isFetchPending)
        api.deliver(.error(MindboxError.connectionError))

        let answers = Answers<EmbeddedPlaceSelection>()
        slowBudgetManager.selectInappForPlace("stories-list-container", trigger: nil) { answer, _, _ in answers.append(answer) }

        try await waitUntil(!answers.isEmpty)
        #expect(answers.all == [.configUnavailable])
    }

    @Test("An unavailable config carries how long the place actually waited for it")
    func unavailableConfigCarriesTheRealWait() async throws {
        let clock = TestClock()
        let patientManager = Self.makeManager(api: api, configWaitBudget: 60, now: { clock.now })
        patientManager.prepareConfiguration()
        try await waitUntil(api.isFetchPending)

        let answers = Answers<(selection: EmbeddedPlaceSelection, duration: TimeInterval)>()
        patientManager.selectInappForPlace("stories-list-container", trigger: nil) { answer, processingDuration, _ in
            answers.append((answer, processingDuration))
        }
        clock.advance(12.5)
        api.deliver(.error(MindboxError.connectionError))

        try await waitUntil(!answers.isEmpty)
        let answer = try #require(answers.first)
        #expect(answer.selection == .configUnavailable)
        #expect(answer.duration == 12.5)
    }

    @Test("An empty config from the server is a decided place, not an unavailable one")
    func emptyConfigIsDecidedNotUnavailable() async throws {
        manager.prepareConfiguration()
        try await waitUntil(api.isFetchPending)
        api.deliver(.empty)

        let answers = Answers<EmbeddedPlaceSelection>()
        manager.selectInappForPlace("stories-list-container", trigger: nil) { answer, _, _ in answers.append(answer) }

        try await waitUntil(!answers.isEmpty)
        #expect(answers.all == [.decided(nil)])
    }

    @Test("A place the pass could not check is passed on as unavailable, not as decided")
    func uncheckedPlaceIsPassedOnAsUnavailable() async throws {
        let facade = try #require(DI.injectOrFail(InAppConfigurationDataFacadeProtocol.self) as? MockInAppConfigurationDataFacade)
        facade.cutByFetchFailure = true
        defer { facade.cutByFetchFailure = false }
        manager.prepareConfiguration()
        try await waitUntil(api.isFetchPending)
        api.deliver(.data(try fixtureData()))

        let answers = Answers<EmbeddedPlaceSelection>()
        manager.selectInappForPlace("no-such-place", trigger: nil) { answer, _, _ in answers.append(answer) }

        try await waitUntil(!answers.isEmpty)
        #expect(answers.all == [.targetingUnavailable])
    }

    @Test("A place asked before the config resolves once it lands")
    func placeAskedBeforeConfigResolvesOnArrival() async throws {
        manager.prepareConfiguration()
        try await waitUntil(api.isFetchPending)

        let answers = Answers<InAppTransitionData?>()
        manager.selectInappForPlace("stories-list-container", trigger: nil) { answer, _, _ in answers.append(answer.inapp) }
        api.deliver(.data(try fixtureData()))

        try await waitUntil(!answers.isEmpty)
        #expect((answers.first ?? nil)?.inAppId == "11111111-1111-1111-1111-111111111111")
    }

    @Test("A place outlives the wait budget: only the download's conclusion answers it")
    func placeIsNotAnsweredByTheWaitBudget() async throws {
        manager.prepareConfiguration()
        try await waitUntil(api.isFetchPending)

        let answers = Answers<InAppTransitionData?>()
        manager.selectInappForPlace("stories-list-container", trigger: nil) { answer, _, _ in answers.append(answer.inapp) }

        try await Task.sleep(nanoseconds: 600_000_000)
        #expect(answers.isEmpty, "the config wait budget must not answer a place — the block owns the give-up")

        api.deliver(.data(try fixtureData()))

        try await waitUntil(!answers.isEmpty)
        #expect((answers.first ?? nil)?.inAppId == "11111111-1111-1111-1111-111111111111")
    }

    @Test("The place's processing time runs from the block's request, the wait for the config included")
    func placeProcessingTimeIncludesTheWaitForTheConfig() async throws {
        let clock = TestClock()
        let patientManager = Self.makeManager(api: api, configWaitBudget: 60, now: { clock.now })
        patientManager.prepareConfiguration()
        try await waitUntil(api.isFetchPending)

        let answers = Answers<(inapp: InAppTransitionData?, duration: TimeInterval)>()
        patientManager.selectInappForPlace("stories-list-container", trigger: nil) { answer, processingDuration, _ in
            answers.append((answer.inapp, processingDuration))
        }
        clock.advance(12.5)
        api.deliver(.data(try fixtureData()))

        try await waitUntil(!answers.isEmpty)
        let answer = try #require(answers.first)
        #expect(answer.inapp != nil, "the place was not answered from the config")
        #expect(answer.duration == 12.5)
    }

    @Test("One applied config is prepared once, however many blocks and pages ask")
    func configIsPreparedOncePerDownload() async throws {
        let counting = CountingFilterService()
        let manager = Self.makeManager(api: api, configWaitBudget: 0.2, inappFilterService: counting)

        manager.prepareConfiguration()
        try await waitUntil(api.isFetchPending)
        api.deliver(.data(try fixtureData()))

        let pages = Answers<[String]?>()
        let places = Answers<InAppTransitionData?>()
        manager.getShowableInappIds([Constants.liveStoryId], askedBy: "a-block") { pages.append($0) }
        manager.selectInappForPlace("stories-list-container", trigger: nil) { answer, _, _ in places.append(answer.inapp) }
        manager.getShowableInappIds([Constants.liveStoryId], askedBy: "a-block") { pages.append($0) }
        manager.selectInappForPlace("stories-list-container", trigger: nil) { answer, _, _ in places.append(answer.inapp) }

        try await waitUntil(pages.all.count == 2 && places.all.count == 2)
        #expect(counting.prepareCount == 1)
    }

    @Test("An in-app asked by id is answered with nothing until a config lands, then from that config")
    func inappInCurrentConfigAnswersFromTheLandedConfig() async throws {
        #expect(manager.inappInCurrentConfig(withId: Constants.liveStoryId) == nil)
        manager.prepareConfiguration()
        try await waitUntil(api.isFetchPending)
        api.deliver(.data(try fixtureData()))
        try await waitUntil(manager.hasConfig)

        let inapp = try #require(manager.inappInCurrentConfig(withId: Constants.liveStoryId))
        #expect(inapp.id == Constants.liveStoryId)
        #expect(inapp.tags == ["templateType": "Popup"])
        #expect(manager.inappInCurrentConfig(withId: "no-such-inapp") == nil)
    }

    @Test("An id the config carries twice is answered with its first copy")
    func inappInCurrentConfigTakesTheFirstCopy() async throws {
        let data = try fixtureData { inapps in
            var copy = try #require(inapps.first { $0["id"] as? String == Constants.liveStoryId })
            copy["tags"] = ["templateType": "SecondCopy"]
            inapps.append(copy)
        }
        manager.prepareConfiguration()
        try await waitUntil(api.isFetchPending)
        api.deliver(.data(data))
        try await waitUntil(manager.hasConfig)

        #expect(manager.inappInCurrentConfig(withId: Constants.liveStoryId)?.tags == ["templateType": "Popup"])
    }

    @Test("An id whose first copy is meant for another SDK version is answered with the copy for this one")
    func inappInCurrentConfigSkipsACopyForAnotherSDK() async throws {
        let data = try fixtureData { inapps in
            let index = try #require(inapps.firstIndex { $0["id"] as? String == Constants.liveStoryId })
            var otherSDKCopy = inapps[index]
            otherSDKCopy["sdkVersion"] = ["min": 9999, "max": NSNull()]
            otherSDKCopy["tags"] = ["templateType": "OtherSDK"]
            inapps.insert(otherSDKCopy, at: index)
        }
        manager.prepareConfiguration()
        try await waitUntil(api.isFetchPending)
        api.deliver(.data(data))
        try await waitUntil(manager.hasConfig)

        #expect(manager.inappInCurrentConfig(withId: Constants.liveStoryId)?.tags == ["templateType": "Popup"])
    }

    @Test("A config arriving later replaces the in-app an id is answered with")
    func laterConfigReplacesTheRenderableInapp() async throws {
        manager.prepareConfiguration()
        try await waitUntil(api.isFetchPending)
        api.deliver(.data(try fixtureData()))
        try await waitUntil(manager.hasConfig)
        #expect(manager.inappInCurrentConfig(withId: Constants.liveStoryId)?.tags == ["templateType": "Popup"])

        let replaced = try fixtureData { inapps in
            let index = try #require(inapps.firstIndex { $0["id"] as? String == Constants.liveStoryId })
            inapps[index]["tags"] = ["templateType": "Replaced"]
        }
        manager.prepareConfiguration()
        try await waitUntil(api.isFetchPending)
        api.deliver(.data(replaced))

        try await waitUntil(manager.inappInCurrentConfig(withId: Constants.liveStoryId)?.tags == ["templateType": "Replaced"])
    }

    @Test("A config arriving later replaces the models the previous one left")
    func laterConfigReplacesThePreparedModels() async throws {
        manager.prepareConfiguration()
        try await waitUntil(api.isFetchPending)
        api.deliver(.data(try fixtureData()))

        let withBlock = Answers<InAppTransitionData?>()
        manager.selectInappForPlace("stories-list-container", trigger: nil) { answer, _, _ in withBlock.append(answer.inapp) }
        try await waitUntil(!withBlock.isEmpty)
        #expect((withBlock.first ?? nil)?.inAppId == "11111111-1111-1111-1111-111111111111")

        manager.prepareConfiguration()
        try await waitUntil(api.isFetchPending)
        api.deliver(.empty)

        let withoutBlock = Answers<InAppTransitionData?>()
        manager.selectInappForPlace("stories-list-container", trigger: nil) { answer, _, _ in withoutBlock.append(answer.inapp) }
        try await waitUntil(!withoutBlock.isEmpty)
        #expect((withoutBlock.first ?? nil)?.inAppId == nil)
    }

    // MARK: - The session behind the config

    @Test("Every download announces it concluded, stamped with the session it started in", arguments: DownloadOutcome.allCases)
    func everyDownloadAnnouncesItsConclusion(_ outcome: DownloadOutcome) async throws {
        let log = ConclusionLog()
        let manager = Self.makeManager(api: api, configWaitBudget: 0.2, notificationCenter: log.center)
        let startedIn = SessionTemporaryStorage.shared.ledger.sessionEpoch

        manager.prepareConfiguration()
        try await waitUntil(api.isFetchPending)
        SessionTemporaryStorage.shared.erase()
        api.deliver(try result(outcome))

        try await waitUntil(!log.announced.isEmpty)
        #expect(log.announced.all == [startedIn])
    }

    @Test("A place waiting for a download is answered with the session the download started in, not the one it lands in")
    func placeAnswerCarriesTheSessionOfItsConfig() async throws {
        let startedIn = SessionTemporaryStorage.shared.ledger.sessionEpoch
        manager.prepareConfiguration()
        try await waitUntil(api.isFetchPending)

        let sessions = Answers<Int>()
        manager.selectInappForPlace("stories-list-container", trigger: nil) { _, _, sessionEpoch in sessions.append(sessionEpoch) }
        SessionTemporaryStorage.shared.erase()
        api.deliver(.data(try fixtureData()))

        try await waitUntil(!sessions.isEmpty)
        #expect(sessions.all == [startedIn])
    }

    @Test("A place asked with an earlier session's config in hand waits for this session's download")
    func placeWaitsPastAnEarlierSessionsConfig() async throws {
        manager.prepareConfiguration()
        try await waitUntil(api.isFetchPending)
        api.deliver(.data(try fixtureData()))
        try await waitUntil(manager.hasConfig)
        SessionTemporaryStorage.shared.erase()
        let current = SessionTemporaryStorage.shared.ledger.sessionEpoch

        let answers = Answers<(inappId: String?, sessionEpoch: Int)>()
        manager.selectInappForPlace("stories-list-container", trigger: nil) { answer, _, sessionEpoch in
            answers.append((answer.inapp?.inAppId, sessionEpoch))
        }
        try await Task.sleep(nanoseconds: 300_000_000)
        #expect(answers.isEmpty, "the place must not be answered from the previous session's config")

        manager.prepareConfiguration()
        try await waitUntil(api.isFetchPending)
        api.deliver(.data(try fixtureData()))

        try await waitUntil(!answers.isEmpty)
        let answer = try #require(answers.first)
        #expect(answer.inappId == "11111111-1111-1111-1111-111111111111")
        #expect(answer.sessionEpoch == current)
    }

    @Test("A page asked with an earlier session's config in hand is answered from it at once")
    func pageIsAnsweredFromAnEarlierSessionsConfig() async throws {
        manager.prepareConfiguration()
        try await waitUntil(api.isFetchPending)
        api.deliver(.data(try fixtureData()))
        try await waitUntil(manager.hasConfig)
        SessionTemporaryStorage.shared.erase()

        let answers = Answers<[String]?>()
        manager.getShowableInappIds([Constants.liveStoryId], askedBy: "a-block") { answers.append($0) }

        try await waitUntil(!answers.isEmpty)
        #expect(answers.all == [[Constants.liveStoryId]])
    }

    // MARK: - Downloads that overlap

    @Test("A download a later one superseded leaves the later one's config and conclusion in place when it lands last")
    func supersededDownloadLandingLastChangesNothing() async throws {
        let log = ConclusionLog()
        let manager = Self.makeManager(api: api, configWaitBudget: 0.2, notificationCenter: log.center)
        manager.prepareConfiguration()
        try await waitUntil(api.pendingFetches == 1)
        SessionTemporaryStorage.shared.erase()
        let later = SessionTemporaryStorage.shared.ledger.sessionEpoch
        manager.prepareConfiguration()
        try await waitUntil(api.pendingFetches == 2)

        api.deliverToNewest(.data(try fixtureData()))
        try await waitUntil(!log.announced.isEmpty)
        api.deliver(.empty)
        try await waitUntil(api.pendingFetches == 0)

        let answers = Answers<(inappId: String?, sessionEpoch: Int)>()
        manager.selectInappForPlace("stories-list-container", trigger: nil) { answer, _, sessionEpoch in
            answers.append((answer.inapp?.inAppId, sessionEpoch))
        }
        try await waitUntil(!answers.isEmpty)
        let answer = try #require(answers.first)
        #expect(answer.inappId == "11111111-1111-1111-1111-111111111111")
        #expect(answer.sessionEpoch == later)
        #expect(log.announced.all == [later])
    }

    @Test("A download a later one superseded leaves its waiters to the later one when it lands first")
    func supersededDownloadLandingFirstLeavesItsWaiters() async throws {
        manager.prepareConfiguration()
        try await waitUntil(api.pendingFetches == 1)
        SessionTemporaryStorage.shared.erase()
        let later = SessionTemporaryStorage.shared.ledger.sessionEpoch
        manager.prepareConfiguration()
        try await waitUntil(api.pendingFetches == 2)

        let answers = Answers<(selection: EmbeddedPlaceSelection, sessionEpoch: Int)>()
        manager.selectInappForPlace("stories-list-container", trigger: nil) { answer, _, sessionEpoch in
            answers.append((answer, sessionEpoch))
        }
        api.deliver(.data(try fixtureData()))
        try await Task.sleep(nanoseconds: 300_000_000)
        #expect(answers.isEmpty, "the superseded download must not answer the waiting place")

        api.deliver(.empty)

        try await waitUntil(!answers.isEmpty)
        let answer = try #require(answers.first)
        #expect(answer.selection == .decided(nil))
        #expect(answer.sessionEpoch == later)
    }
}
