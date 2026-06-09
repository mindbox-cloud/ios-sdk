//
//  DateFormatMigrationTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 04.06.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
@testable import Mindbox
import MindboxLogger

// A class-based suite so `deinit` can restore the global `MBPersistenceStorage.defaults`
// after every test. `.serialized` because the tests mutate that shared global.
@Suite(.serialized)
final class DateFormatMigrationTests {

    private let migration: MigrationProtocol
    private let userDefaults: UserDefaults
    private let userDefaultsSuiteName = "DateFormatMigrationTests"
    private let originalDefaults: UserDefaults

    private let installationKey = "MBPersistenceStorage-installationData"
    private let firstInitKey = "MBPersistenceStorage-firstInitializationDateTime"
    private let apnsKey = "MBPersistenceStorage-apnsTokenSaveDate"
    private let configKey = "MBPersistenceStorage-configDownloadDate"
    private let lastInfoKey = "MBPersistenceStorage-lastInfoUpdateTime"
    private let deprecatedKey = "MBPersistenceStorage-deprecatedEventsRemoveDate"

    private var allKeys: [String] {
        [installationKey, firstInitKey, apnsKey, configKey, lastInfoKey, deprecatedKey]
    }

    init() {
        originalDefaults = MBPersistenceStorage.defaults
        userDefaults = UserDefaults(suiteName: userDefaultsSuiteName)!
        userDefaults.removePersistentDomain(forName: userDefaultsSuiteName)
        MBPersistenceStorage.defaults = userDefaults
        migration = DateFormatMigration()
    }

    deinit {
        userDefaults.removePersistentDomain(forName: userDefaultsSuiteName)
        // Restore the global so this suite never leaks its private suite into other tests.
        MBPersistenceStorage.defaults = originalDefaults
    }

    // MARK: - Helpers

    /// Produces a string in the legacy format (replica of the removed MBPersistenceStorage
    /// formatter) under the device's current 12h/24h setting.
    private func legacyString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .full
        return formatter.string(from: date)
    }

    /// Independent oracle for the hour-cycle rescue: builds a legacy `.full`/`.full` string with the
    /// hour cycle pinned through the structured `Locale.Components` API — a *different* mechanism than
    /// the `@hours=` identifier `DateFormatMigration` assembles itself. The base stays `Locale.current`
    /// so only the hour cycle differs from the migration's candidates (the date layout still matches).
    /// If the migration's hour-cycle keyword were wrong, this independently-built opposite-cycle string
    /// would fail to parse — so the test proves the rescue works, not just that both sides build the
    /// same identifier.
    @available(iOS 16.0, *)
    private func independentLegacyString(from date: Date, hourCycle: Locale.HourCycle) -> String {
        var components = Locale.Components(locale: .current)
        components.hourCycle = hourCycle
        let formatter = DateFormatter()
        formatter.locale = Locale(components: components)
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

    @Test("isNeeded is true when a legacy value is present")
    func isNeededTrueWhenLegacyValuePresent() {
        userDefaults.set(legacyString(from: fixedDate), forKey: installationKey)
        #expect(migration.isNeeded)
    }

    @Test("isNeeded is false and run() is a no-op when there are no values")
    func isNeededFalseWhenNoValues() throws {
        #expect(migration.isNeeded == false)
        try migration.run()
    }

    @Test("run() converts a legacy installation date and keeps isInstalled stable")
    func runConvertsLegacyInstallationDateAndKeepsIsInstalledStable() throws {
        userDefaults.set(legacyString(from: fixedDate), forKey: installationKey)

        // Before migration: the legacy string is unparseable by the new `.utc` reader,
        // so the parsed `installationDate` is nil — but `isInstalled` stays true because
        // it depends on the stored string's presence, not on parsing it.
        let storageBefore = MBPersistenceStorage(defaults: userDefaults)
        #expect(storageBefore.installationDate == nil)
        #expect(storageBefore.isInstalled)

        try migration.run()

        // After migration: the date value parses again, and `isInstalled` is unchanged.
        let storageAfter = MBPersistenceStorage(defaults: userDefaults)
        #expect(storageAfter.installationDate != nil)
        #expect(storageAfter.isInstalled)
        #expect(
            storageAfter.installationDate.map { Int($0.timeIntervalSince1970) }
                == Int(fixedDate.timeIntervalSince1970)
        )
        #expect(migration.isNeeded == false)
    }

    /// The original re-installation bug: a value written under 12h must still convert when the
    /// migration runs (even if the device is now in 24h). The 12h candidate rescues it.
    @available(iOS 16.0, *)
    @Test("run() converts a legacy installation date written in 12h format")
    func runConvertsLegacyInstallationDateWrittenIn12hFormat() throws {
        userDefaults.set(
            independentLegacyString(from: fixedDate, hourCycle: .oneToTwelve),
            forKey: installationKey
        )

        #expect(migration.isNeeded, "A 12h legacy value must be recognized as needing migration.")
        try migration.run()

        let raw = userDefaults.string(forKey: installationKey)
        #expect(
            raw?.toDate(withFormat: .utc).map { Int($0.timeIntervalSince1970) }
                == Int(fixedDate.timeIntervalSince1970),
            "12h legacy installation date must be converted to the correct .utc instant."
        )
        #expect(migration.isNeeded == false)
    }

    /// Symmetric to the 12h case: a value written under 24h converts as well.
    @available(iOS 16.0, *)
    @Test("run() converts a legacy installation date written in 24h format")
    func runConvertsLegacyInstallationDateWrittenIn24hFormat() throws {
        userDefaults.set(
            independentLegacyString(from: fixedDate, hourCycle: .zeroToTwentyThree),
            forKey: installationKey
        )

        #expect(migration.isNeeded, "A 24h legacy value must be recognized as needing migration.")
        try migration.run()

        let raw = userDefaults.string(forKey: installationKey)
        #expect(
            raw?.toDate(withFormat: .utc).map { Int($0.timeIntervalSince1970) }
                == Int(fixedDate.timeIntervalSince1970),
            "24h legacy installation date must be converted to the correct .utc instant."
        )
        #expect(migration.isNeeded == false)
    }

    @Test("run() converts all six persisted date keys")
    func runConvertsAllSixKeys() throws {
        allKeys.forEach { userDefaults.set(legacyString(from: fixedDate), forKey: $0) }

        try migration.run()

        for key in allKeys {
            let raw = userDefaults.string(forKey: key)
            #expect(raw?.toDate(withFormat: .utc) != nil, "Key \(key) was not converted to .utc")
        }
        #expect(migration.isNeeded == false)
    }

    @Test("run() leaves an already-.utc value untouched")
    func runLeavesAlreadyUtcValueUntouched() throws {
        let utc = fixedDate.toString(withFormat: .utc)
        userDefaults.set(utc, forKey: installationKey)

        #expect(migration.isNeeded == false)
        try migration.run()

        #expect(userDefaults.string(forKey: installationKey) == utc)
    }

    @Test("run() leaves an unparseable value untouched")
    func runLeavesUnparseableValueUntouched() throws {
        let garbage = "definitely not a date"
        userDefaults.set(garbage, forKey: installationKey)

        #expect(migration.isNeeded == false)
        try migration.run()

        #expect(userDefaults.string(forKey: installationKey) == garbage)
    }

    /// Regression: an installed user must stay installed even when the stored installation
    /// date string cannot be parsed (e.g. a region / 12h↔24h time-format change made a
    /// legacy localized string unreadable). `isInstalled` depends on the string's presence,
    /// not on parsing it, so it stays true without any migration having run.
    @Test("isInstalled stays true for an unparseable installation date, without migration")
    func isInstalledTrueForUnparseableInstallationDateWithoutMigration() {
        userDefaults.set("definitely not a parseable date", forKey: installationKey)

        let storage = MBPersistenceStorage(defaults: userDefaults)

        #expect(storage.installationDate == nil)
        #expect(storage.isInstalled)
    }

    /// Ordering contract: `DateFormatMigration` must sort ahead of any date-consuming migration
    /// in `MigrationManager`'s ascending-by-`version` chain. If this regresses (e.g. a renumber),
    /// `FirstInitializationDateTimeMigration` would read an unparseable legacy `installationDate`
    /// as `nil` and silently skip — the original upgrade bug.
    @Test("version sorts before any date-consuming migration")
    func versionSortsBeforeDateConsumingMigration() {
        #expect(
            DateFormatMigration().version < FirstInitializationDateTimeMigration().version,
            "DateFormatMigration must run before FirstInitializationDateTimeMigration."
        )
    }

    @Test("run() is idempotent when called twice")
    func runIdempotentWhenCalledTwice() throws {
        userDefaults.set(legacyString(from: fixedDate), forKey: installationKey)

        try migration.run()
        let afterFirstRun = userDefaults.string(forKey: installationKey)
        #expect(migration.isNeeded == false)

        try migration.run()
        #expect(userDefaults.string(forKey: installationKey) == afterFirstRun)
        #expect(migration.isNeeded == false)
    }
}
