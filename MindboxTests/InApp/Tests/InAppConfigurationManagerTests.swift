//
//  InAppConfigurationManagerTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import Testing
import class MindboxLogger.Locked
@testable import Mindbox

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

    /// Poll `isFetchPending` before delivering — a result delivered into a fetch that has not started yet would vanish.
    private final class HeldConfigAPI: InAppConfigurationAPI {
        private let lock = NSLock()
        private var held: ((InAppConfigurationAPIResult) -> Void)?

        var isFetchPending: Bool {
            lock.lock()
            defer { lock.unlock() }
            return held != nil
        }

        init() {
            super.init(persistenceStorage: MockPersistenceStorage())
        }

        override func fetchConfig(completionQueue: DispatchQueue, completion: @escaping (InAppConfigurationAPIResult) -> Void) {
            lock.lock()
            held = { result in completionQueue.async { completion(result) } }
            lock.unlock()
        }

        func deliver(_ result: InAppConfigurationAPIResult) {
            lock.lock()
            let pending = held
            held = nil
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

        func filter(feedIds ids: [String], in candidates: ConfigCandidates) -> [InApp] {
            wrapped.filter(feedIds: ids, in: candidates)
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
                                     targetingChecker: InAppTargetingCheckerProtocol) -> [InAppTransitionData] {
            wrapped.filterInappsByTargeting(inapps: inapps, targetingChecker: targetingChecker)
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

        manager = InAppConfigurationManager(
            inAppConfigAPI: api,
            inAppConfigRepository: EmptyConfigRepository(),
            inappMapper: DI.injectOrFail(InappMapperProtocol.self),
            persistenceStorage: persistenceStorage,
            featureToggleManager: DI.injectOrFail(FeatureToggleManager.self),
            webViewPrewarmService: DI.injectOrFail(InAppWebViewPrewarmServiceProtocol.self),
            inappFilterService: DI.injectOrFail(InappFilterProtocol.self),
            configWaitBudget: 0.2
        )
    }

    private func fixtureData() throws -> Data {
        let bundle = Bundle(for: MindboxTests.self)
        let url = try #require(bundle.url(forResource: "EmbeddedBlockConfig", withExtension: "json"))
        return try Data(contentsOf: url)
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

        let answers = Answers<[String]>()
        manager.getRenderableInappIds([Constants.liveStoryId]) { answers.append($0.inappIds) }

        api.deliver(.data(try fixtureData()))

        try await waitUntil(!answers.isEmpty)
        #expect(answers.all == [[Constants.liveStoryId]])
    }

    @Test("A caller arriving after the config is answered from it")
    func callerAfterConfigIsAnsweredRightAway() async throws {
        manager.prepareConfiguration()
        try await waitUntil(api.isFetchPending)
        api.deliver(.data(try fixtureData()))

        let answers = Answers<[String]>()
        manager.getRenderableInappIds([Constants.liveStoryId]) { answers.append($0.inappIds) }

        try await waitUntil(!answers.isEmpty)
        #expect(answers.all == [[Constants.liveStoryId]])
    }

    @Test("A config that never arrives answers with nothing after the budget")
    func neverArrivingConfigAnswersNothingAfterTheBudget() async throws {
        manager.prepareConfiguration()

        let answers = Answers<[String]>()
        manager.getRenderableInappIds([Constants.liveStoryId]) { answers.append($0.inappIds) }

        try await waitUntil(!answers.isEmpty)
        #expect(answers.all == [[]])
    }

    @Test("A failed download with no cache answers with nothing at once")
    func failedDownloadAnswersWithoutWaitingOutTheBudget() async throws {
        let slowBudgetManager = InAppConfigurationManager(
            inAppConfigAPI: api,
            inAppConfigRepository: EmptyConfigRepository(),
            inappMapper: DI.injectOrFail(InappMapperProtocol.self),
            persistenceStorage: DI.injectOrFail(PersistenceStorage.self),
            featureToggleManager: DI.injectOrFail(FeatureToggleManager.self),
            webViewPrewarmService: DI.injectOrFail(InAppWebViewPrewarmServiceProtocol.self),
            inappFilterService: DI.injectOrFail(InappFilterProtocol.self),
            configWaitBudget: 60
        )
        slowBudgetManager.prepareConfiguration()
        try await waitUntil(api.isFetchPending)

        let answers = Answers<[String]>()
        slowBudgetManager.getRenderableInappIds([Constants.liveStoryId]) { answers.append($0.inappIds) }
        api.deliver(.error(MindboxError.connectionError))

        try await waitUntil(!answers.isEmpty)
        #expect(answers.all == [[]])
    }

    @Test("A place asked before the config resolves once it lands")
    func placeAskedBeforeConfigResolvesOnArrival() async throws {
        manager.prepareConfiguration()
        try await waitUntil(api.isFetchPending)

        let answers = Answers<InAppTransitionData?>()
        manager.selectInappForPlace("stories-list-container", trigger: nil) { answers.append($0) }
        api.deliver(.data(try fixtureData()))

        try await waitUntil(!answers.isEmpty)
        #expect((answers.first ?? nil)?.inAppId == "11111111-1111-1111-1111-111111111111")
    }

    @Test("One applied config is prepared once, however many blocks and feeds ask")
    func configIsPreparedOncePerDownload() async throws {
        let counting = CountingFilterService()
        let manager = InAppConfigurationManager(
            inAppConfigAPI: api,
            inAppConfigRepository: EmptyConfigRepository(),
            inappMapper: DI.injectOrFail(InappMapperProtocol.self),
            persistenceStorage: DI.injectOrFail(PersistenceStorage.self),
            featureToggleManager: DI.injectOrFail(FeatureToggleManager.self),
            webViewPrewarmService: DI.injectOrFail(InAppWebViewPrewarmServiceProtocol.self),
            inappFilterService: counting,
            configWaitBudget: 0.2
        )

        manager.prepareConfiguration()
        try await waitUntil(api.isFetchPending)
        api.deliver(.data(try fixtureData()))

        let feeds = Answers<[String]>()
        let places = Answers<InAppTransitionData?>()
        manager.getRenderableInappIds([Constants.liveStoryId]) { feeds.append($0.inappIds) }
        manager.selectInappForPlace("stories-list-container", trigger: nil) { places.append($0) }
        manager.getRenderableInappIds([Constants.liveStoryId]) { feeds.append($0.inappIds) }
        manager.selectInappForPlace("stories-list-container", trigger: nil) { places.append($0) }

        try await waitUntil(feeds.all.count == 2 && places.all.count == 2)
        #expect(counting.prepareCount == 1)
    }

    @Test("A config arriving later replaces the models the previous one left")
    func laterConfigReplacesThePreparedModels() async throws {
        manager.prepareConfiguration()
        try await waitUntil(api.isFetchPending)
        api.deliver(.data(try fixtureData()))

        let withBlock = Answers<InAppTransitionData?>()
        manager.selectInappForPlace("stories-list-container", trigger: nil) { withBlock.append($0) }
        try await waitUntil(!withBlock.isEmpty)
        #expect((withBlock.first ?? nil)?.inAppId == "11111111-1111-1111-1111-111111111111")

        manager.prepareConfiguration()
        try await waitUntil(api.isFetchPending)
        api.deliver(.empty)

        let withoutBlock = Answers<InAppTransitionData?>()
        manager.selectInappForPlace("stories-list-container", trigger: nil) { withoutBlock.append($0) }
        try await waitUntil(!withoutBlock.isEmpty)
        #expect((withoutBlock.first ?? nil)?.inAppId == nil)
    }
}
