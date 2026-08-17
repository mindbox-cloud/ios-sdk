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

/// The config wait. A block asks the moment it enters the window — on a first screen regularly before
/// the config is downloaded — and answering "nothing" then would collapse it for the screen's life.
/// So a caller waits for the first config, within a budget.
@Suite("In-app configuration manager", .tags(.embeddedBlocks))
struct InAppConfigurationManagerTests {

    private enum Constants {
        static let liveStoryId = "55555555-5555-5555-5555-555555555555"
    }

    /// Answers land on the manager's queue (or main); the test polls from its own thread — the
    /// box is what makes that pair race-free.
    private final class Answers<Value> {
        @Locked private var storage: [Value] = []

        var all: [Value] { storage }
        var first: Value? { storage.first }
        var isEmpty: Bool { storage.isEmpty }

        func append(_ value: Value) {
            storage.append(value)
        }
    }

    /// Holds the download until the test releases it — the "config is still on the network" state.
    ///
    /// The manager starts the fetch on its own queue, so the test polls `isFetchPending` before
    /// delivering: a result delivered into a fetch that has not started yet would vanish.
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
            configWaitBudget: 0.2
        )
    }

    private func fixtureData() throws -> Data {
        let bundle = Bundle(for: MindboxTests.self)
        let url = try #require(bundle.url(forResource: "EmbeddedBlockConfig", withExtension: "json"))
        return try Data(contentsOf: url)
    }

    /// Polls instead of confirming, because the manager answers on its own queue and the test has no
    /// hook into it. The ceiling is generous on purpose: it is there to fail a hung test, not to time
    /// anything, so a loaded machine cannot turn it red.
    private func waitUntil(_ condition: @autoclosure () -> Bool,
                           sourceLocation: SourceLocation = #_sourceLocation) async throws {
        let step: UInt64 = 20_000_000
        let ceiling = 200

        for _ in 0..<ceiling where !condition() {
            try await Task.sleep(nanoseconds: step)
        }

        #expect(condition(), "gave up after \(Double(ceiling) * Double(step) / 1_000_000_000)s", sourceLocation: sourceLocation)
    }

    /// A caller that arrives first must wait, not be fobbed off with an empty answer. That is what the
    /// single answer below proves: the manager answers a waiter exactly once, so had it answered before
    /// the config landed, the one answer on record would be the empty one.
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

    /// The budget is the ceiling, not the promise: a config that never comes must not keep a block's
    /// callback alive for the life of the process.
    @Test("A config that never arrives answers with nothing after the budget")
    func neverArrivingConfigAnswersNothingAfterTheBudget() async throws {
        manager.prepareConfiguration()

        let answers = Answers<[String]>()
        manager.getRenderableInappIds([Constants.liveStoryId]) { answers.append($0.inappIds) }

        try await waitUntil(!answers.isEmpty)
        #expect(answers.all == [[]])
    }

    /// A failed download is an answer too — nobody sits out the rest of the budget for a config that
    /// already said no. With no cache behind it, that answer is "nothing".
    @Test("A failed download with no cache answers with nothing at once")
    func failedDownloadAnswersWithoutWaitingOutTheBudget() async throws {
        let slowBudgetManager = InAppConfigurationManager(
            inAppConfigAPI: api,
            inAppConfigRepository: EmptyConfigRepository(),
            inappMapper: DI.injectOrFail(InappMapperProtocol.self),
            persistenceStorage: DI.injectOrFail(PersistenceStorage.self),
            featureToggleManager: DI.injectOrFail(FeatureToggleManager.self),
            webViewPrewarmService: DI.injectOrFail(InAppWebViewPrewarmServiceProtocol.self),
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
}
