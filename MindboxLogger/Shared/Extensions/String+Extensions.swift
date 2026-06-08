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

    // The set of formats is fixed and tiny, so every fixed-pattern formatter is built once,
    // up front. `static let` is initialized exactly once (thread-safe), the dictionary is then
    // immutable, and each fully-configured `DateFormatter` is safe for concurrent string/date
    // conversion on iOS 7+ (min target iOS 12). No lock needed.
    // Each formatter uses POSIX locale + explicit UTC timezone, 24h `HH`.
    private static let formatters: [DateFormat: DateFormatter] = {
        var dict = [DateFormat: DateFormatter]()
        for format in [DateFormat.api, .utc, .utcWithMillis] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format.rawValue
            formatter.timeZone = TimeZone(identifier: "UTC")
            dict[format] = formatter
        }
        return dict
    }()

    func string(from date: Date) -> String {
        Self.formatters[self]!.string(from: date)
    }

    func date(from string: String) -> Date? {
        Self.formatters[self]!.date(from: string)
    }
}

public extension String {
    func toDate(withFormat format: DateFormat) -> Date? {
        return format.date(from: self)
    }
}
