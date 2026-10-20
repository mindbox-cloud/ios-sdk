//
//  DateFormatMigration.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 04.06.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

final class DateFormatMigration: MigrationProtocol {

    private let defaults = MBPersistenceStorage.defaults

    private let dateKeys: [String] = {
        let keys: [MBPersistenceStorage.UserDefaultsWrapper<Any>.Key] = [
            .installationData,
            .firstInitializationDateTime,
            .apnsTokenSaveDate,
            .configDownloadDate,
            .lastInfoUpdateTime,
            .deprecatedEventsRemoveDate
        ]
        return keys.map(\.rawValue)
    }()

    private lazy var legacyFormatters: [DateFormatter] = {
        func make(_ identifier: String) -> DateFormatter {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: identifier)
            formatter.dateStyle = .full
            formatter.timeStyle = .full
            return formatter
        }

        let base = Locale.current.identifier
        // Locale.current may already carry @hours=…; ICU honours the first hours= keyword, so replace it, never append.
        func identifier(forcingHourCycle hourCycle: String) -> String {
            let parts = base.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false)
            let languageAndRegion = String(parts[0])
            var keywords: [(key: String, value: String)] = []
            if parts.count == 2 {
                for keyword in parts[1].split(separator: ";") {
                    let pair = keyword.split(separator: "=", maxSplits: 1)
                    guard pair.count == 2 else { continue }
                    keywords.append((String(pair[0]), String(pair[1])))
                }
            }
            keywords.removeAll { $0.key == "hours" || $0.key == "hc" }
            keywords.append(("hours", hourCycle))
            let keywordString = keywords.map { "\($0.key)=\($0.value)" }.joined(separator: ";")
            return languageAndRegion + "@" + keywordString
        }

        return [
            make(base),
            make(identifier(forcingHourCycle: "h23")),
            make(identifier(forcingHourCycle: "h12"))
        ]
    }()

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

    var version: Int {
        -1
    }

    func run() throws {
        Logger.common(message: "[Migrations] Started DateFormatMigration — scanning \(dateKeys.count) persisted date key(s) for legacy values", level: .info, category: .migration)

        var convertedCount = 0
        for key in dateKeys {
            guard let raw = defaults.string(forKey: key) else { continue }
            guard raw.toDate(withFormat: .utc) == nil else {
                Logger.common(message: "[Migrations] Skip DateFormatMigration key '\(key)' — already in .utc format: '\(raw)'", level: .debug, category: .migration)
                continue
            }
            guard let date = legacyDate(from: raw) else {
                Logger.common(message: "[Migrations] Skip DateFormatMigration key '\(key)' — value not parseable by any legacy formatter: '\(raw)'", level: .error, category: .migration)
                continue
            }
            let newValue = date.toString(withFormat: .utc)
            defaults.set(newValue, forKey: key)
            convertedCount += 1
            Logger.common(message: "[Migrations] DateFormatMigration converted '\(key)': '\(raw)' → '\(newValue)'", level: .info, category: .migration)
        }

        Logger.common(message: "[Migrations] Finished DateFormatMigration — converted \(convertedCount) of \(dateKeys.count) key(s)", level: .info, category: .migration)
    }
}
