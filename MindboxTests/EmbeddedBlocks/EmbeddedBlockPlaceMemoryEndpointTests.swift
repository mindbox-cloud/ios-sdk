//
//  EmbeddedBlockPlaceMemoryEndpointTests.swift
//  MindboxTests
//
//  Created by vailence on 25.09.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
@testable import Mindbox

// MARK: - Embedded block place memory across endpoints

/// The memory of places belongs to the endpoint whose config named them: a new endpoint starts
/// every place hidden, a new domain on the same endpoint keeps what was remembered.
@Suite(.serialized)
@MainActor
struct EmbeddedBlockPlaceMemoryEndpointTests {

    private let storage: PersistenceStorage
    private let coreController: CoreController
    private let controllerQueue: DispatchQueue

    init() {
        TestConfiguration.configure()
        storage = DI.injectOrFail(PersistenceStorage.self)
        storage.reset()
        coreController = DI.injectOrFail(CoreController.self)
        controllerQueue = coreController.controllerQueue
        let databaseRepository = DI.injectOrFail(DatabaseRepositoryProtocol.self)
        try? databaseRepository.erase()
    }

    @Test("A new endpoint forgets every remembered place")
    func endpointChangeForgetsPlaces() async throws {
        try await initialize(endpoint: "shop-app", domain: "api.mindbox.ru")
        rememberPlaces()

        try await initialize(endpoint: "shop-app-staging", domain: "api.mindbox.ru")

        #expect(storage.embeddedBlockPlaceRecords == nil)
        cleanup()
    }

    @Test("The reset is visible as soon as initialization returns, before the controller queue runs")
    func resetIsVisibleBeforeInitializationFinishes() async throws {
        try await initialize(endpoint: "shop-app", domain: "api.mindbox.ru")
        rememberPlaces()

        // A block created right after this line reads the memory on the main thread: it must not see
        // the old endpoint's places.
        coreController.initialization(configuration: try MBConfiguration(endpoint: "shop-app-staging", domain: "api.mindbox.ru"))
        #expect(storage.embeddedBlockPlaceRecords == nil)

        await waitForInitializationFinished()
        cleanup()
    }

    @Test("The same endpoint on another domain keeps the remembered places")
    func domainChangeKeepsPlaces() async throws {
        try await initialize(endpoint: "shop-app", domain: "api.mindbox.ru")
        rememberPlaces()

        try await initialize(endpoint: "shop-app", domain: "api-staging.mindbox.ru")

        #expect(storage.embeddedBlockPlaceRecords?.keys.sorted() == ["banner", "stories"])
        cleanup()
    }

    @Test("Repeating the same configuration keeps the remembered places")
    func sameConfigurationKeepsPlaces() async throws {
        try await initialize(endpoint: "shop-app", domain: "api.mindbox.ru")
        rememberPlaces()

        try await initialize(endpoint: "shop-app", domain: "api.mindbox.ru")

        #expect(storage.embeddedBlockPlaceRecords?.keys.sorted() == ["banner", "stories"])
        cleanup()
    }

    // MARK: - Helpers

    private func initialize(endpoint: String, domain: String) async throws {
        let configuration = try MBConfiguration(endpoint: endpoint, domain: domain)
        coreController.initialization(configuration: configuration)
        await waitForInitializationFinished()
    }

    /// Written the way the block writes them: through the memory the container hands out.
    private func rememberPlaces() {
        let memory = DI.injectOrFail(EmbeddedBlockPlaceRemembering.self)
        memory.rememberShownContent(at: "stories")
        memory.rememberShownContent(at: "banner")
    }

    private func waitForInitializationFinished() async {
        await withCheckedContinuation { continuation in
            controllerQueue.async {
                continuation.resume()
            }
        }
    }

    private func cleanup() {
        storage.reset()
        storage.userVisitCount = 0
        SessionTemporaryStorage.shared.erase()
        SessionTemporaryStorage.shared.isInstalledFromPersistenceStorageBeforeInitSDK = false
    }
}
