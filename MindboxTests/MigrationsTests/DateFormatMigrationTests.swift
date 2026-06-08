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

    /// Produces a legacy `.full`/`.full` string with the hour cycle pinned (e.g. `h12` / `h23`),
    /// keeping the current device language/region. Mirrors how `DateFormatMigration` builds its
    /// candidate locales, so a value written here is the same shape the migration must parse.
    private func legacyString(from date: Date, hourCycle: String) -> String {
        let base = Locale.current.identifier
        let separator = base.contains("@") ? ";" : "@"
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: base + separator + "hours=" + hourCycle)
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

    func test_run_convertsLegacyInstallationDate_andKeepsIsInstalledStable() throws {
        userDefaults.set(legacyString(from: fixedDate), forKey: installationKey)

        // Before migration: the legacy string is unparseable by the new `.utc` reader,
        // so the parsed `installationDate` is nil — but `isInstalled` stays true because
        // it depends on the stored string's presence, not on parsing it.
        let storageBefore = MBPersistenceStorage(defaults: userDefaults)
        XCTAssertNil(storageBefore.installationDate)
        XCTAssertTrue(storageBefore.isInstalled)

        try migration.run()

        // After migration: the date value parses again, and `isInstalled` is unchanged.
        let storageAfter = MBPersistenceStorage(defaults: userDefaults)
        XCTAssertNotNil(storageAfter.installationDate)
        XCTAssertTrue(storageAfter.isInstalled)
        XCTAssertEqual(
            storageAfter.installationDate.map { Int($0.timeIntervalSince1970) },
            Int(fixedDate.timeIntervalSince1970)
        )
        XCTAssertFalse(migration.isNeeded)
    }

    /// The original re-installation bug: a value written under 12h must still convert when the
    /// migration runs (even if the device is now in 24h). The 12h candidate rescues it.
    func test_run_convertsLegacyInstallationDate_writtenIn12hFormat() throws {
        userDefaults.set(legacyString(from: fixedDate, hourCycle: "h12"), forKey: installationKey)

        XCTAssertTrue(migration.isNeeded, "A 12h legacy value must be recognized as needing migration.")
        try migration.run()

        let raw = userDefaults.string(forKey: installationKey)
        XCTAssertEqual(
            raw?.toDate(withFormat: .utc).map { Int($0.timeIntervalSince1970) },
            Int(fixedDate.timeIntervalSince1970),
            "12h legacy installation date must be converted to the correct .utc instant."
        )
        XCTAssertFalse(migration.isNeeded)
    }

    /// Symmetric to the 12h case: a value written under 24h converts as well.
    func test_run_convertsLegacyInstallationDate_writtenIn24hFormat() throws {
        userDefaults.set(legacyString(from: fixedDate, hourCycle: "h23"), forKey: installationKey)

        XCTAssertTrue(migration.isNeeded, "A 24h legacy value must be recognized as needing migration.")
        try migration.run()

        let raw = userDefaults.string(forKey: installationKey)
        XCTAssertEqual(
            raw?.toDate(withFormat: .utc).map { Int($0.timeIntervalSince1970) },
            Int(fixedDate.timeIntervalSince1970),
            "24h legacy installation date must be converted to the correct .utc instant."
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

    /// Regression: an installed user must stay installed even when the stored installation
    /// date string cannot be parsed (e.g. a region / 12h↔24h time-format change made a
    /// legacy localized string unreadable). `isInstalled` depends on the string's presence,
    /// not on parsing it, so it stays true without any migration having run.
    func test_isInstalled_true_forUnparseableInstallationDate_withoutMigration() {
        userDefaults.set("definitely not a parseable date", forKey: installationKey)

        let storage = MBPersistenceStorage(defaults: userDefaults)

        XCTAssertNil(storage.installationDate)
        XCTAssertTrue(storage.isInstalled)
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
