//
//  String+Extensions.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 15.02.2023.
//

import Foundation

public enum DateFormat: String, CaseIterable {
    case api = "yyyy-MM-dd'T'HH:mm:ss"
    case utc = "yyyy-MM-dd'T'HH:mm:ss'Z'"
    case utcWithMillis = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"

    var value: String {
        return self.rawValue
    }

    // Fixed-pattern formatter: POSIX locale + explicit UTC timezone, 24h `HH`.
    private static func makeFormatter(for format: DateFormat) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format.rawValue
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }

    // The set of formats is fixed and tiny, so every formatter is built once, up front.
    // `static let` is initialized exactly once (thread-safe), the dictionary is then immutable,
    // and each fully-configured `DateFormatter` is safe for concurrent string/date conversion on
    // iOS 7+ (min target iOS 12). No lock needed.
    private static let formatters: [DateFormat: DateFormatter] = {
        var dict = [DateFormat: DateFormatter]()
        for format in DateFormat.allCases {
            dict[format] = makeFormatter(for: format)
        }
        return dict
    }()

    // Falls back to building on demand instead of force-unwrapping: the dictionary always has an
    // entry for every case (built from `allCases`), so the fallback is unreachable in practice.
    private var formatter: DateFormatter {
        Self.formatters[self] ?? Self.makeFormatter(for: self)
    }

    func string(from date: Date) -> String {
        formatter.string(from: date)
    }

    func date(from string: String) -> Date? {
        formatter.date(from: string)
    }
}

public extension String {
    func toDate(withFormat format: DateFormat) -> Date? {
        return format.date(from: self)
    }
}
