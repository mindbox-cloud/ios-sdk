//
//  String+Extensions.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 15.02.2023.
//

import Foundation

public enum DateFormat: String {
    case api = "yyyy-MM-dd'T'HH:mm:ss"
    case utc = "yyyy-MM-dd'T'HH:mm:ss'Z'"
    case utcWithMillis = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"

    var value: String {
        return self.rawValue
    }

    private static let cacheLock = NSLock()
    private static var formatters: [DateFormat: DateFormatter] = [:]

    // Cached, fixed-pattern formatter: POSIX locale + explicit UTC timezone, 24h `HH`.
    // Created once per format and reused. Must only be touched while holding `cacheLock`.
    private var formatter: DateFormatter {
        if let formatter = Self.formatters[self] {
            return formatter
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = value
        formatter.timeZone = TimeZone(identifier: "UTC")
        Self.formatters[self] = formatter
        return formatter
    }

    // The lock spans the actual format/parse calls, not just cache lookup:
    // a shared DateFormatter must not be used for string/date conversion concurrently.
    func string(from date: Date) -> String {
        Self.cacheLock.lock()
        defer { Self.cacheLock.unlock() }
        return formatter.string(from: date)
    }

    func date(from string: String) -> Date? {
        Self.cacheLock.lock()
        defer { Self.cacheLock.unlock() }
        return formatter.date(from: string)
    }
}

public extension String {
    func toDate(withFormat format: DateFormat) -> Date? {
        return format.date(from: self)
    }
}
