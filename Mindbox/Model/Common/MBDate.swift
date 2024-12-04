//
//  MBDate.swift
//  Mindbox
//
//  Created by Ihor Kandaurov on 19.05.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

public final class DateOnly: MBDate {
    override var dateFormat: String {
        "dd.MM.yyyy"
    }

    override func decodeWithFormat(_ rawString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: rawString)
    }
}

public final class DateTime: MBDate {
    override var dateFormat: String {
        "dd.MM.yyyy HH:mm:ss.FFF"
    }

    override func decodeWithFormat(_ rawString: String) -> Date? {
        return rawString.dateFromISO8601
    }
}

public class MBDate: Codable {
    public var string: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = dateFormat
        return dateFormatter.string(from: date)
    }

    public var date: Date

    var dateFormat: String {
        return ""
    }

    func decodeWithFormat(_ rawString: String) -> Date? {
        return nil
    }

    public init(_ date: Date) {
        self.date = date
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        date = Date()
        guard let decodedDate = decodeWithFormat(string) else {
            let error = MindboxError.internalError(.init(errorKey: "Invalid date specified in JSON."))
            Logger.error(error.asLoggerError())
            throw error
        }
        date = decodedDate
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(string)
    }
}

extension Date {
    public var asDateOnly: DateOnly {
        return DateOnly(self)
    }

    public var asDateTime: DateTime {
        return DateTime(self)
    }

    public var asDateTimeWithSeconds: String {
        return DateTimeWithSeconds(self).string
    }
}

fileprivate extension Date {
    struct Formatter {
        static let iso8601: DateFormatter = {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .iso8601)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
            return formatter
        }()
    }

    var iso8601: String {
        return Formatter.iso8601.string(from: self)
    }
}

fileprivate extension String {
    var dateFromISO8601: Date? {
        var data = self
        if range(of: ".") == nil {
            // Case where the string doesn't contain the optional milliseconds
            data = data.replacingOccurrences(of: "Z", with: ".000000Z")
        }
        return Date.Formatter.iso8601.date(from: data)
    }
}

public final class DateTimeWithSeconds: MBDate {
    override var dateFormat: String {
        "yyyy-MM-dd HH:mm:ss"
    }

    override func decodeWithFormat(_ rawString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = dateFormat
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: rawString)
    }
}
