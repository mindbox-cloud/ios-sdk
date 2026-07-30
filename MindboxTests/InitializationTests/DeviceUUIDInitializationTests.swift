//
//  DeviceUUIDInitializationTests.swift
//  MindboxTests
//
//  Created by Mindbox on 08.06.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
@testable import Mindbox

// MARK: - deviceUUID / applicationInstanceId behavior on initialization

@Suite(.serialized)
@MainActor
struct DeviceUUIDInitializationTests {

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

    @Test("Honest reinstall: empty storage generates a deviceUUID and an applicationInstanceId")
    func honestReinstallGeneratesNewIdentifiers() async throws {
        storage.reset()
        #expect(storage.deviceUUID == nil)
        #expect(storage.installationDate == nil)
        #expect(storage.applicationInstanceId == nil)

        let configuration = try MBConfiguration(plistName: "TestConfig1")
        coreController.initialization(configuration: configuration)
        await waitForInitializationFinished()

        let deviceUUID = try #require(
            storage.deviceUUID,
            "A genuine first installation must generate a deviceUUID."
        )
        #expect(!deviceUUID.isEmpty, "Generated deviceUUID must not be empty.")

        let instanceId = try #require(
            storage.applicationInstanceId,
            "A genuine first installation must generate an applicationInstanceId."
        )
        #expect(!instanceId.isEmpty, "Generated applicationInstanceId must not be empty.")

        cleanup()
    }

    @Test("Persisted deviceUUID is reused on install, not regenerated")
    func persistedDeviceUUIDIsReused() async throws {
        storage.reset()
        // Simulate a locale-driven re-installation: `isInstalled` became false (installationDate
        // absent), yet a deviceUUID from a previous installation is still persisted. The fix must
        // reuse that deviceUUID instead of generating a new one.
        let persistedUUID = "00000000-0000-0000-0000-0000000000AA"
        storage.deviceUUID = persistedUUID
        #expect(storage.installationDate == nil)
        #expect(storage.isInstalled == false)

        let configuration = try MBConfiguration(plistName: "TestConfig1")
        coreController.initialization(configuration: configuration)
        await waitForInitializationFinished()

        #expect(
            storage.deviceUUID == persistedUUID,
            "primaryInitialization must reuse the persisted deviceUUID, not regenerate it."
        )

        cleanup()
    }

    @Test("Reinstall over an existing installation keeps deviceUUID and refreshes instanceId")
    func reinstallKeepsDeviceUUIDRefreshesInstanceId() async throws {
        let configuration = try MBConfiguration(plistName: "TestConfig1")
        coreController.initialization(configuration: configuration)
        await waitForInitializationFinished()

        let originalUUID = try #require(
            storage.deviceUUID,
            "deviceUUID must be set after the first installation."
        )
        let originalInstanceId = try #require(
            storage.applicationInstanceId,
            "applicationInstanceId must be set after the first installation."
        )
        #expect(storage.isInstalled, "Storage must be installed after the first initialization.")

        // Re-initialize with a configuration whose endpoint differs: changedState becomes `.rest`,
        // so repeatInitialization runs install() again over the existing installation.
        let changedConfiguration = try MBConfiguration(
            endpoint: "app-with-hub-IOS-reinstall",
            domain: "api.mindbox.ru"
        )
        coreController.initialization(configuration: changedConfiguration)
        await waitForInitializationFinished()

        #expect(
            storage.deviceUUID == originalUUID,
            "deviceUUID must stay stable across a reinstall over an existing installation."
        )
        let newInstanceId = try #require(
            storage.applicationInstanceId,
            "applicationInstanceId must be present after reinstall."
        )
        #expect(
            newInstanceId != originalInstanceId,
            "install() must generate a fresh applicationInstanceId on reinstall."
        )

        cleanup()
    }

    // MARK: - Helpers

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
