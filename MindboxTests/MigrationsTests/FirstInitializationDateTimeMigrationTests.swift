//
//  FirstInitializationDateTimeMigrationTests.swift
//  MindboxTests
//
//  Created by Mindbox on 12.03.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
@testable import Mindbox

@Suite(.serialized)
struct FirstInitializationDateTimeMigrationTests {

    private let storage: PersistenceStorage
    private let migrationManager: MigrationManagerProtocol

    init() {
        storage = DI.injectOrFail(PersistenceStorage.self)
        storage.reset()
        migrationManager = MigrationManager(persistenceStorage: storage)
    }

    @Test("Existing user: migration copies installationDate")
    func existingUserMigrationCopiesInstallationDate() throws {
        let oldDate = Date(timeIntervalSince1970: 1_000_000)
        storage.installationDate = oldDate
        storage.firstInitializationDateTime = nil

        migrationManager.migrate()

        let firstInitDate = try #require(
            storage.firstInitializationDateTime,
            "firstInitializationDateTime must be set after migration."
        )
        #expect(
            abs(firstInitDate.timeIntervalSince1970 - oldDate.timeIntervalSince1970) <= 1.0,
            "firstInitializationDateTime should match the old installationDate."
        )
    }

    @Test("Existing user: migration does not overwrite existing firstInitializationDateTime")
    func existingUserMigrationDoesNotOverwriteExisting() throws {
        let originalDate = Date(timeIntervalSince1970: 1_000_000)
        storage.firstInitializationDateTime = originalDate
        storage.installationDate = Date(timeIntervalSince1970: 2_000_000)

        migrationManager.migrate()

        let firstInitDate = try #require(storage.firstInitializationDateTime)
        #expect(
            abs(firstInitDate.timeIntervalSince1970 - originalDate.timeIntervalSince1970) <= 1.0,
            "firstInitializationDateTime must not be overwritten once set."
        )
    }
}
