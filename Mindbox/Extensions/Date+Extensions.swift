//
//  Date+Extensions.swift
//  Mindbox
//
//  Created by Mindbox on 09.03.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

extension Date {

    private static let iso8601Formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        return formatter
    }()

    var iso8601: String {
        Self.iso8601Formatter.string(from: self)
    }

    static func fromISO8601(_ string: String) -> Date? {
        var data = string
        if string.range(of: ".") == nil {
            data = data.replacingOccurrences(of: "Z", with: ".000000Z")
        }
        return iso8601Formatter.date(from: data)
    }
}
