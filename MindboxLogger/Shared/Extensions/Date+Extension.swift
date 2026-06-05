//
//  Date+Extension.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 13.02.2023.
//  Copyright © 2023 Mikhail Barilov. All rights reserved.
//

import Foundation

public extension Date {
    func toString() -> String {
        return Date.dateFormatter.string(from: self as Date)
    }

    func toFullString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return dateFormatter.string(from: self as Date)
    }

    static var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss.SSSS"
        return formatter
    }

    func toString(withFormat format: DateFormat) -> String {
        return format.string(from: self)
    }
}

public extension TimeInterval {
    private static let readableDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    var asReadableDateTime: String {
        let date = Date(timeIntervalSince1970: self)
        return Self.readableDateTimeFormatter.string(from: date)
    }
}
