//
//  EmbeddedBlockPlaceMemoryEndpointTests.swift
//  MindboxTests
//
//  Created by vailence on 25.09.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
@testable import Mindbox

// MARK: - Embedded block place memory across configurations

/// The memory of places outlives the configuration: neither a new endpoint nor a new domain starts
/// a place hidden again, the same as on Android. A stale record corrects itself — the place answers
/// with nothing, `onEmpty` forgets it.
@Suite("Embedded block place memory across configurations", .tags(.embeddedBlocks), .serialized)
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
        EmbeddedBlockAppPresence.shared.reset()
    }

    @Test("A new endpoint keeps the remembered places")
    func endpointChangeKeepsPlaces() async throws {
        try await initialize(endpoint: "shop-app", domain: "api.mindbox.ru")
        rememberPlaces()

        try await initialize(endpoint: "shop-app-staging", domain: "api.mindbox.ru")

        #expect(storage.embeddedBlockPlaceRecords?.keys.sorted() == ["banner", "stories"])
        cleanup()
    }

    @Test("Switching back to the first endpoint keeps the remembered places too")
    func endpointChangeBackKeepsPlaces() async throws {
        try await initialize(endpoint: "shop-app", domain: "api.mindbox.ru")
        rememberPlaces()
        try await initialize(endpoint: "shop-app-staging", domain: "api.mindbox.ru")

        try await initialize(endpoint: "shop-app", domain: "api.mindbox.ru")

        #expect(storage.embeddedBlockPlaceRecords?.keys.sorted() == ["banner", "stories"])
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
