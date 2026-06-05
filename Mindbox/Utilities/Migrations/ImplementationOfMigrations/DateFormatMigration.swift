//
//  DateFormatMigration.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 04.06.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

/// Converts the persisted date strings written by the previous localized
/// formatter (`dateStyle = .full`, `timeStyle = .full`) into the canonical
/// fixed-pattern `.utc` representation used after the formatter unification.
///
/// - Important: Must run first in `MigrationManager.migrate()`, before any
///   date-consuming migration (e.g. `FirstInitializationDateTimeMigration`,
///   which reads `installationDate` as a parsed `Date`). Without this conversion
///   an upgraded user's date strings stay unparseable by `.utc`, so the parsed
///   `Date` values read as `nil`. `isInstalled` itself is independent of parsing
///   (it checks the presence of the stored string), so it is unaffected.
final class DateFormatMigration: MigrationProtocol {

    private let defaults = MBPersistenceStorage.defaults

    /// Raw UserDefaults keys of the six persisted dates. Kept as literals to match the
    /// stored identifiers (mirrors `MBPersistenceStorage.UserDefaultsWrapper.Key`).
    private let dateKeys = [
        "MBPersistenceStorage-installationData",
        "MBPersistenceStorage-firstInitializationDateTime",
        "MBPersistenceStorage-apnsTokenSaveDate",
        "MBPersistenceStorage-configDownloadDate",
        "MBPersistenceStorage-lastInfoUpdateTime",
        "MBPersistenceStorage-deprecatedEventsRemoveDate"
    ]

    /// Replica of the removed `MBPersistenceStorage` formatter. Localized styles are used
    /// here solely to read legacy values written by that same formatter on this device —
    /// never to write new data. New values are written via `.toString(withFormat: .utc)`.
    private let legacyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .full
        return formatter
    }()

    var description: String {
        "Migration converts persisted dates from the legacy localized format to fixed-pattern UTC."
    }

    var isNeeded: Bool {
        dateKeys.contains { key in
            guard let raw = defaults.string(forKey: key) else { return false }
            return raw.toDate(withFormat: .utc) == nil && legacyFormatter.date(from: raw) != nil
        }
    }

    /// Runs explicitly before the versioned chain in `MigrationManager`, not via the sorted array,
    /// so it is intentionally excluded from `versionCodeForMigration` accounting.
    var version: Int {
        0
    }

    func run() throws {
        Logger.common(message: "📅 [DateFormatMigration] Started — scanning \(dateKeys.count) persisted date key(s) for legacy values", level: .info, category: .migration)

        var convertedCount = 0
        for key in dateKeys {
            guard let raw = defaults.string(forKey: key) else { continue }
            // Already migrated (or natively written in the new format) — leave untouched.
            guard raw.toDate(withFormat: .utc) == nil else {
                Logger.common(message: "📅 [DateFormatMigration] Skip '\(key)' — already in .utc format: '\(raw)'", level: .debug, category: .migration)
                continue
            }
            // Unparseable by the legacy formatter (e.g. device locale/timezone changed) — best-effort skip.
            guard let date = legacyFormatter.date(from: raw) else {
                Logger.common(message: "📅 [DateFormatMigration] ⚠️ Skip '\(key)' — value not parseable by legacy formatter: '\(raw)'", level: .error, category: .migration)
                continue
            }
            let newValue = date.toString(withFormat: .utc)
            defaults.set(newValue, forKey: key)
            convertedCount += 1
            Logger.common(message: "📅 [DateFormatMigration] Converted '\(key)': '\(raw)' → '\(newValue)'", level: .info, category: .migration)
        }

        Logger.common(message: "📅 [DateFormatMigration] ✅ Finished — converted \(convertedCount) of \(dateKeys.count) key(s)", level: .info, category: .migration)
    }
}
