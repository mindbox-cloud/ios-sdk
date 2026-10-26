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
        MBPersistenceStorage.defaults = originalDefaults
    }

    // MARK: - Helpers

    private func legacyString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .full
        return formatter.string(from: date)
    }

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

        let storageBefore = MBPersistenceStorage(defaults: userDefaults)
        #expect(storageBefore.installationDate == nil)
        #expect(storageBefore.isInstalled)

        try migration.run()

        let storageAfter = MBPersistenceStorage(defaults: userDefaults)
        #expect(storageAfter.installationDate != nil)
        #expect(storageAfter.isInstalled)
        #expect(
            storageAfter.installationDate.map { Int($0.timeIntervalSince1970) }
                == Int(fixedDate.timeIntervalSince1970)
        )
        #expect(migration.isNeeded == false)
    }

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

    @Test("isInstalled stays true for an unparseable installation date, without migration")
    func isInstalledTrueForUnparseableInstallationDateWithoutMigration() {
        userDefaults.set("definitely not a parseable date", forKey: installationKey)

        let storage = MBPersistenceStorage(defaults: userDefaults)

        #expect(storage.installationDate == nil)
        #expect(storage.isInstalled)
    }

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
