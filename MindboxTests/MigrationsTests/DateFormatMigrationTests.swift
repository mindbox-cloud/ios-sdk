//
//  DateFormatMigrationTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 04.06.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox
import MindboxLogger

final class DateFormatMigrationTests: XCTestCase {

    private var migration: MigrationProtocol!
    private var userDefaults: UserDefaults!
    private let userDefaultsSuiteName = "DateFormatMigrationTests"

    private let installationKey = "MBPersistenceStorage-installationData"
    private let firstInitKey = "MBPersistenceStorage-firstInitializationDateTime"
    private let apnsKey = "MBPersistenceStorage-apnsTokenSaveDate"
    private let configKey = "MBPersistenceStorage-configDownloadDate"
    private let lastInfoKey = "MBPersistenceStorage-lastInfoUpdateTime"
    private let deprecatedKey = "MBPersistenceStorage-deprecatedEventsRemoveDate"

    private var allKeys: [String] {
        [installationKey, firstInitKey, apnsKey, configKey, lastInfoKey, deprecatedKey]
    }

    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: userDefaultsSuiteName)!
        userDefaults.removePersistentDomain(forName: userDefaultsSuiteName)
        MBPersistenceStorage.defaults = userDefaults
        migration = DateFormatMigration()
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: userDefaultsSuiteName)
        super.tearDown()
    }

    // MARK: - Helpers

    /// Produces a string in the legacy format (replica of the removed MBPersistenceStorage formatter).
    private func legacyString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .full
        return formatter.string(from: date)
    }

    /// Whole-second instant so legacy (`.full`) and `.utc` representations round-trip exactly.
    private var fixedDate: Date {
        Date(timeIntervalSince1970: 1_700_000_000)
    }
}

// MARK: - Scenarios

extension DateFormatMigrationTests {

    func test_isNeeded_true_whenLegacyValuePresent() {
        userDefaults.set(legacyString(from: fixedDate), forKey: installationKey)
        XCTAssertTrue(migration.isNeeded)
    }

    func test_isNeeded_false_whenNoValues() {
        XCTAssertFalse(migration.isNeeded)
        XCTAssertNoThrow(try migration.run())
    }

    func test_run_convertsLegacyInstallationDate_andRestoresIsInstalled() throws {
        userDefaults.set(legacyString(from: fixedDate), forKey: installationKey)

        // Before migration: the legacy string is unparseable by the new `.utc` reader.
        let storageBefore = MBPersistenceStorage(defaults: userDefaults)
        XCTAssertNil(storageBefore.installationDate)
        XCTAssertFalse(storageBefore.isInstalled)

        try migration.run()

        let storageAfter = MBPersistenceStorage(defaults: userDefaults)
        XCTAssertNotNil(storageAfter.installationDate)
        XCTAssertTrue(storageAfter.isInstalled)
        XCTAssertEqual(
            storageAfter.installationDate.map { Int($0.timeIntervalSince1970) },
            Int(fixedDate.timeIntervalSince1970)
        )
        XCTAssertFalse(migration.isNeeded)
    }

    func test_run_convertsAllSixKeys() throws {
        allKeys.forEach { userDefaults.set(legacyString(from: fixedDate), forKey: $0) }

        try migration.run()

        for key in allKeys {
            let raw = userDefaults.string(forKey: key)
            XCTAssertNotNil(raw?.toDate(withFormat: .utc), "Key \(key) was not converted to .utc")
        }
        XCTAssertFalse(migration.isNeeded)
    }

    func test_run_leavesAlreadyUtcValueUntouched() throws {
        let utc = fixedDate.toString(withFormat: .utc)
        userDefaults.set(utc, forKey: installationKey)

        XCTAssertFalse(migration.isNeeded)
        try migration.run()

        XCTAssertEqual(userDefaults.string(forKey: installationKey), utc)
    }

    func test_run_leavesUnparseableValueUntouched() throws {
        let garbage = "definitely not a date"
        userDefaults.set(garbage, forKey: installationKey)

        XCTAssertFalse(migration.isNeeded)
        try migration.run()

        XCTAssertEqual(userDefaults.string(forKey: installationKey), garbage)
    }

    func test_run_idempotent_whenCalledTwice() throws {
        userDefaults.set(legacyString(from: fixedDate), forKey: installationKey)

        try migration.run()
        let afterFirstRun = userDefaults.string(forKey: installationKey)
        XCTAssertFalse(migration.isNeeded)

        try migration.run()
        XCTAssertEqual(userDefaults.string(forKey: installationKey), afterFirstRun)
        XCTAssertFalse(migration.isNeeded)
    }
}
