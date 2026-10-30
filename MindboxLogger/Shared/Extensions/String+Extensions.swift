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

    private static func makeFormatter(for format: DateFormat) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format.rawValue
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }

    private static let formatters: [DateFormat: DateFormatter] = {
        var dict = [DateFormat: DateFormatter]()
        for format in DateFormat.allCases {
            dict[format] = makeFormatter(for: format)
        }
        return dict
    }()

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
