//
//  IntegrationFrameworkInitializationTests.swift
//  MindboxTests
//

import Testing
@_spi(Internal) @testable import Mindbox

@Suite(.serialized)
@MainActor
struct IntegrationFrameworkInitializationTests {

    private static let wrapperValue = "flutter/3.47.8; mindbox-flutter/2.16.0"

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

    @Test("Initialization stores the integration framework passed by a wrapper")
    func initializationStoresWrapperValue() async throws {
        var configuration = try MBConfiguration(plistName: "TestConfig1")
        configuration.integrationFramework = Self.wrapperValue

        coreController.initialization(configuration: configuration)
        await waitForInitializationFinished()

        #expect(storage.configuration?.integrationFramework == Self.wrapperValue)

        cleanup()
    }

    @Test("Initialization without a value clears the integration framework stored by an earlier one")
    func initializationWithoutValueClearsStoredOne() async throws {
        var configuration = try MBConfiguration(plistName: "TestConfig1")
        configuration.integrationFramework = Self.wrapperValue
        coreController.initialization(configuration: configuration)
        await waitForInitializationFinished()

        coreController.initialization(configuration: try MBConfiguration(plistName: "TestConfig1"))
        await waitForInitializationFinished()

        let stored = try #require(storage.configuration)
        #expect(stored.integrationFramework == nil)

        cleanup()
    }

    @Test("Initialization stores a value out of the format as invalid")
    func initializationStoresOutOfFormatValueAsInvalid() async throws {
        var configuration = try MBConfiguration(plistName: "TestConfig1")
        configuration.integrationFramework = "react-native/0.85.0\nX: y"

        coreController.initialization(configuration: configuration)
        await waitForInitializationFinished()

        #expect(storage.configuration?.integrationFramework == "invalid")

        cleanup()
    }

    @Test("Initialization stores a value of only spaces as native")
    func initializationStoresBlankValueAsNative() async throws {
        var configuration = try MBConfiguration(plistName: "TestConfig1")
        configuration.integrationFramework = "   "

        coreController.initialization(configuration: configuration)
        await waitForInitializationFinished()

        #expect(storage.configuration?.integrationFramework == "native")

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
