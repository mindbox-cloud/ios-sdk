//
//  FirstInitializationDateTimeRuntimeTests.swift
//  MindboxTests
//
//  Created by Mindbox on 12.03.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
@testable import Mindbox

// MARK: - Storage tests (no host-app dependency)

@Suite(.serialized)
struct FirstInitializationDateTimeStorageTests {

    private let storage: PersistenceStorage

    init() {
        storage = DI.injectOrFail(PersistenceStorage.self)
        storage.reset()
    }

    @Test("reset() clears firstInitializationDateTime")
    func resetClearsFirstInitializationDate() {
        storage.firstInitializationDateTime = Date()
        #expect(storage.firstInitializationDateTime != nil)

        storage.reset()

        #expect(
            storage.firstInitializationDateTime == nil,
            "reset() must clear firstInitializationDateTime."
        )
    }

    @Test("softReset() does not clear firstInitializationDateTime")
    func softResetDoesNotClearFirstInitializationDate() throws {
        let date = Date()
        storage.firstInitializationDateTime = date
        #expect(storage.firstInitializationDateTime != nil)

        storage.softReset()

        let firstInitDate = try #require(
            storage.firstInitializationDateTime,
            "softReset() must NOT clear firstInitializationDateTime."
        )
        #expect(
            abs(firstInitDate.timeIntervalSince1970 - date.timeIntervalSince1970) <= 1.0,
            "firstInitializationDateTime should remain unchanged after softReset()."
        )
    }
}

// MARK: - Runtime tests (CoreController → UIApplication.shared)

@Suite(.serialized)
@MainActor
struct FirstInitializationDateTimeRuntimeTests {

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

    @Test("New user: firstInitializationDateTime is set on initialization (install)")
    func newUserFirstInitializationDateTimeIsSet() async throws {
        storage.reset()
        #expect(storage.installationDate == nil)
        #expect(storage.firstInitializationDateTime == nil)

        let configuration = try MBConfiguration(plistName: "TestConfig1")
        coreController.initialization(configuration: configuration)
        await waitForInitializationFinished()

        let firstInitDate = try #require(
            storage.firstInitializationDateTime,
            "firstInitializationDateTime must be set for a new user after initialization."
        )
        let installationDate = try #require(
            storage.installationDate,
            "installationDate must be set for a new user after initialization."
        )
        #expect(
            firstInitDate.timeIntervalSince1970 <= installationDate.timeIntervalSince1970,
            "firstInitializationDateTime should not be later than installationDate."
        )

        cleanup()
    }

    @Test("Reinitialization does not overwrite firstInitializationDateTime")
    func reinitializationDoesNotOverwrite() async throws {
        let configuration1 = try MBConfiguration(plistName: "TestConfig1")
        coreController.initialization(configuration: configuration1)
        await waitForInitializationFinished()

        let originalDate = try #require(
            storage.firstInitializationDateTime,
            "firstInitializationDateTime must be set after first initialization."
        )

        let configuration2 = try MBConfiguration(plistName: "TestConfig2")
        coreController.initialization(configuration: configuration2)
        await waitForInitializationFinished()

        let dateAfterReinit = try #require(
            storage.firstInitializationDateTime,
            "firstInitializationDateTime must not be nil after reinitialization."
        )
        #expect(
            abs(dateAfterReinit.timeIntervalSince1970 - originalDate.timeIntervalSince1970) <= 1.0,
            "firstInitializationDateTime must not change on reinitialization."
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
