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

    /// Replicas of the removed `MBPersistenceStorage` formatter (`.full`/`.full`), used only
    /// to read legacy values written by that formatter on this device — never to write new
    /// data (new values go through `.toString(withFormat: .utc)`).
    ///
    /// A single `.full`/`.full` formatter follows the device's current 12h/24h setting, so a
    /// value written under the *other* setting won't parse (the original re-installation bug).
    /// We therefore try several candidates that keep the device language/region — so the
    /// weekday, month, the "at" literal and the zone name match how the value was written —
    /// but pin the hour cycle:
    ///   - the device locale as-is (matches values written under the current setting);
    ///   - the device locale forced to 24-hour (`h23`);
    ///   - the device locale forced to 12-hour (`h12`).
    /// The first candidate that parses wins; the instant is then re-stored as `.utc` (24h/UTC),
    /// so legacy 12h values are rescued and normalized.
    private let legacyFormatters: [DateFormatter] = {
        func make(_ identifier: String) -> DateFormatter {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: identifier)
            formatter.dateStyle = .full
            formatter.timeStyle = .full
            return formatter
        }

        let base = Locale.current.identifier
        // Join the hour-cycle Unicode keyword with the correct separator: `@` for the first
        // keyword, `;` if the current identifier already carries one (e.g. `@calendar=…`).
        func identifier(forcingHourCycle hourCycle: String) -> String {
            let separator = base.contains("@") ? ";" : "@"
            return base + separator + "hours=" + hourCycle
        }

        return [
            make(base),
            make(identifier(forcingHourCycle: "h23")),
            make(identifier(forcingHourCycle: "h12"))
        ]
    }()

    /// Parses a legacy `.full`/`.full` string with the first candidate formatter that succeeds.
    /// Hour cycles don't cross-contaminate: a 24h string (`13:45:45`) is rejected by the 12h
    /// formatter and vice versa, so a successful parse always reflects the value's real time.
    private func legacyDate(from raw: String) -> Date? {
        for formatter in legacyFormatters {
            if let date = formatter.date(from: raw) {
                return date
            }
        }
        return nil
    }

    var description: String {
        "Migration converts persisted dates from the legacy localized format to fixed-pattern UTC."
    }

    var isNeeded: Bool {
        dateKeys.contains { key in
            guard let raw = defaults.string(forKey: key) else { return false }
            return raw.toDate(withFormat: .utc) == nil && legacyDate(from: raw) != nil
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
            // Unparseable by any legacy candidate (e.g. the device language changed) — best-effort skip.
            guard let date = legacyDate(from: raw) else {
                Logger.common(message: "📅 [DateFormatMigration] ⚠️ Skip '\(key)' — value not parseable by any legacy formatter: '\(raw)'", level: .error, category: .migration)
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
