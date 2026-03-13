//
//  FirstInitializationDateTimeRuntimeTests.swift
//  MindboxTests
//
//  Created by Mindbox on 12.03.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

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
}

extension FirstInitializationDateTimeRuntimeTests {

    func test_newUser_firstInitializationDateTimeIsSetOnInitializationInstall() throws {
        // given
        storage.reset()
        XCTAssertNil(storage.installationDate)
        XCTAssertNil(storage.firstInitializationDateTime)

        // when
        let configuration = try MBConfiguration(plistName: "TestConfig1")
        coreController.initialization(configuration: configuration)
        waitForInitializationFinished()

        // then
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

    func test_resetClearsFirstInitializationDate() {
        // given
        storage.firstInitializationDateTime = Date()
        XCTAssertNotNil(storage.firstInitializationDateTime)

        // when
        storage.reset()

        // then
        XCTAssertNil(storage.firstInitializationDateTime,
                     "reset() must clear firstInitializationDateTime.")
    }

    func test_softResetDoesNotClearFirstInitializationDate() throws {
        // given
        let date = Date()
        storage.firstInitializationDateTime = date
        XCTAssertNotNil(storage.firstInitializationDateTime)

        // when
        storage.softReset()

        // then
        let firstInitDate = try XCTUnwrap(storage.firstInitializationDateTime,
                                          "softReset() must NOT clear firstInitializationDateTime.")
        XCTAssertEqual(
            firstInitDate.timeIntervalSince1970,
            date.timeIntervalSince1970,
            accuracy: 1.0,
            "firstInitializationDateTime should remain unchanged after softReset()."
        )
    }
    
    func test_reinitialization_doesNotOverwriteFirstInitializationDateTime() throws {
        // given
        let configuration1 = try MBConfiguration(plistName: "TestConfig1")
        coreController.initialization(configuration: configuration1)
        waitForInitializationFinished()

        let originalDate = try XCTUnwrap(storage.firstInitializationDateTime,
                                        "firstInitializationDateTime must be set after first initialization.")

        // when
        let configuration2 = try MBConfiguration(plistName: "TestConfig2")
        coreController.initialization(configuration: configuration2)
        waitForInitializationFinished()

        // then
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
