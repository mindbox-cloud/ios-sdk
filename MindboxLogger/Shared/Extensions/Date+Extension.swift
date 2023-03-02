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
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return dateFormatter.string(from: self as Date)
    }
    
    static var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm:ss.SSSS"
        return formatter
    }
    
    func toString(withFormat format: DateFormat) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format.value
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        return dateFormatter.string(from: self)
    }
}
