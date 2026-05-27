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
}

public extension String {
    func toDate(withFormat format: DateFormat) -> Date? {
        let dateFormatterGet = DateFormatter()
        dateFormatterGet.locale = Locale(identifier: "en_US_POSIX")
        dateFormatterGet.dateFormat = format.value
        dateFormatterGet.timeZone = TimeZone(identifier: "UTC")

        return dateFormatterGet.date(from: self)
    }
}
