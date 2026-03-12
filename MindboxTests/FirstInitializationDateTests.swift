//
//  FirstInitializationDateTests.swift
//  MindboxTests
//
//  Created by Mindbox on 09.03.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

final class FirstInitializationDateTests: XCTestCase {

    private var storage: PersistenceStorage!

    override func setUp() {
        super.setUp()
        storage = DI.injectOrFail(PersistenceStorage.self)
    }

    override func tearDown() {
        storage = nil
        super.tearDown()
    }

    /// Simulates the inline migration logic from `CoreController.install()`.
    private func simulateInstallInlineMigration() {
        if storage.firstInitializationDateTime == nil {
            storage.firstInitializationDateTime = storage.installationDate ?? Date()
        }
        storage.installationDate = Date()
    }
}

// MARK: - Inline migration scenarios

extension FirstInitializationDateTests {

    func test_newUser_firstInitializationDateTimeIsSetOnFirstInstall() throws {
        // given: brand new user, nothing is set
        storage.installationDate = nil
        storage.firstInitializationDateTime = nil

        // when
        let beforeInstall = Date()
        simulateInstallInlineMigration()

        // then
        let firstInitDate = try XCTUnwrap(storage.firstInitializationDateTime,
                                          "firstInitializationDateTime must be set for a new user after install.")
        XCTAssertGreaterThanOrEqual(firstInitDate, beforeInstall.addingTimeInterval(-1),
                                    "firstInitializationDateTime should be close to the current time.")
    }

    func test_existingUser_firstInitializationDateTimeCopiesInstallationDate() throws {
        // given: existing user with an old installationDate, no firstInitializationDateTime
        let oldDate = Date(timeIntervalSince1970: 1_000_000)
        storage.installationDate = oldDate
        storage.firstInitializationDateTime = nil

        // when
        simulateInstallInlineMigration()

        // then
        let firstInitDate = try XCTUnwrap(storage.firstInitializationDateTime,
                                          "firstInitializationDateTime must be set after inline migration.")
        XCTAssertEqual(
            firstInitDate.timeIntervalSince1970,
            oldDate.timeIntervalSince1970,
            accuracy: 1.0,
            "firstInitializationDateTime should match the old installationDate."
        )

        let currentInstallDate = try XCTUnwrap(storage.installationDate)
        XCTAssertNotEqual(
            currentInstallDate.timeIntervalSince1970,
            oldDate.timeIntervalSince1970,
            accuracy: 1.0,
            "installationDate should be updated to the current time."
        )
    }

    func test_writeOnce_firstInitializationDateTimeIsNotOverwritten() throws {
        // given: firstInitializationDateTime is already set
        let originalDate = Date(timeIntervalSince1970: 1_000_000)
        storage.firstInitializationDateTime = originalDate
        storage.installationDate = Date(timeIntervalSince1970: 2_000_000)

        // when: simulate another install (e.g. config change)
        simulateInstallInlineMigration()

        // then
        let firstInitDate = try XCTUnwrap(storage.firstInitializationDateTime)
        XCTAssertEqual(
            firstInitDate.timeIntervalSince1970,
            originalDate.timeIntervalSince1970,
            accuracy: 1.0,
            "firstInitializationDateTime must not be overwritten once set."
        )
    }
}

// MARK: - Reset behavior

extension FirstInitializationDateTests {

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
}
