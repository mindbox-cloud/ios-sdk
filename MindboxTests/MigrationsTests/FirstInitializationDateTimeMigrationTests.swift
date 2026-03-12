//
//  FirstInitializationDateTimeMigrationTests.swift
//  MindboxTests
//
//  Created by Mindbox on 12.03.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

final class FirstInitializationDateTimeMigrationTests: XCTestCase {

    private var storage: PersistenceStorage!
    private var migrationManager: MigrationManagerProtocol!

    override func setUp() {
        super.setUp()
        storage = DI.injectOrFail(PersistenceStorage.self)
        storage.reset()
        migrationManager = MigrationManager(persistenceStorage: storage)
    }

    override func tearDown() {
        migrationManager = nil
        storage = nil
        super.tearDown()
    }
}

extension FirstInitializationDateTimeMigrationTests {

    func test_existingUser_migrationCopiesInstallationDate() throws {
        // given: existing user with an old installationDate, no firstInitializationDateTime
        let oldDate = Date(timeIntervalSince1970: 1_000_000)
        storage.installationDate = oldDate
        storage.firstInitializationDateTime = nil

        // when
        migrationManager.migrate()

        // then
        let firstInitDate = try XCTUnwrap(storage.firstInitializationDateTime,
                                          "firstInitializationDateTime must be set after migration.")
        XCTAssertEqual(
            firstInitDate.timeIntervalSince1970,
            oldDate.timeIntervalSince1970,
            accuracy: 1.0,
            "firstInitializationDateTime should match the old installationDate."
        )
    }

    func test_existingUser_migrationDoesNotOverwriteExistingFirstInitializationDate() throws {
        // given: firstInitializationDateTime is already set
        let originalDate = Date(timeIntervalSince1970: 1_000_000)
        storage.firstInitializationDateTime = originalDate
        storage.installationDate = Date(timeIntervalSince1970: 2_000_000)

        // when
        migrationManager.migrate()

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
