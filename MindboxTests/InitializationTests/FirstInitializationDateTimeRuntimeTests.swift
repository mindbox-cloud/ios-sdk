//
//  FirstInitializationDateTimeRuntimeTests.swift
//  MindboxTests
//
//  Created by Mindbox on 12.03.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import XCTest
import Testing
@testable import Mindbox

// MARK: - Swift Testing (no host-app dependency)

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

// MARK: - XCTest (requires host-app context for CoreController → UIApplication.shared)

final class FirstInitializationDateTimeRuntimeTests: XCTestCase {

    private var storage: PersistenceStorage!
    private var coreController: CoreController!
    private var controllerQueue: DispatchQueue!

    override func setUp() {
        super.setUp()
        storage = DI.injectOrFail(PersistenceStorage.self)
        storage.reset()
        coreController = DI.injectOrFail(CoreController.self)
        controllerQueue = coreController.controllerQueue
        let databaseRepository = DI.injectOrFail(DatabaseRepositoryProtocol.self)
        try? databaseRepository.erase()
    }

    override func tearDown() {
        storage.reset()
        storage.userVisitCount = 0
        SessionTemporaryStorage.shared.erase()
        SessionTemporaryStorage.shared.isInstalledFromPersistenceStorageBeforeInitSDK = false
        controllerQueue = nil
        coreController = nil
        storage = nil
        super.tearDown()
    }

    func test_newUser_firstInitializationDateTimeIsSetOnInitializationInstall() throws {
        storage.reset()
        XCTAssertNil(storage.installationDate)
        XCTAssertNil(storage.firstInitializationDateTime)

        let configuration = try MBConfiguration(plistName: "TestConfig1")
        coreController.initialization(configuration: configuration)
        waitForInitializationFinished()

        let firstInitDate = try XCTUnwrap(storage.firstInitializationDateTime,
                                          "firstInitializationDateTime must be set for a new user after initialization.")
        let installationDate = try XCTUnwrap(storage.installationDate,
                                             "installationDate must be set for a new user after initialization.")
        XCTAssertLessThanOrEqual(
            firstInitDate.timeIntervalSince1970,
            installationDate.timeIntervalSince1970,
            "firstInitializationDateTime should not be later than installationDate."
        )
    }

    func test_reinitialization_doesNotOverwriteFirstInitializationDateTime() throws {
        let configuration1 = try MBConfiguration(plistName: "TestConfig1")
        coreController.initialization(configuration: configuration1)
        waitForInitializationFinished()

        let originalDate = try XCTUnwrap(storage.firstInitializationDateTime,
                                        "firstInitializationDateTime must be set after first initialization.")

        let configuration2 = try MBConfiguration(plistName: "TestConfig2")
        coreController.initialization(configuration: configuration2)
        waitForInitializationFinished()

        let dateAfterReinit = try XCTUnwrap(storage.firstInitializationDateTime,
                                            "firstInitializationDateTime must not be nil after reinitialization.")
        XCTAssertEqual(
            dateAfterReinit.timeIntervalSince1970,
            originalDate.timeIntervalSince1970,
            accuracy: 1.0,
            "firstInitializationDateTime must not change on reinitialization."
        )
    }
}

private extension FirstInitializationDateTimeRuntimeTests {
    func waitForInitializationFinished() {
        let expectation = self.expectation(description: "controller initialization")
        controllerQueue.async { expectation.fulfill() }
        wait(for: [expectation], timeout: 10)
    }
}
