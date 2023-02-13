//
//  Date+Extension.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 13.02.2023.
//  Copyright © 2023 Mikhail Barilov. All rights reserved.
//

import Foundation

extension Date {
    func toString() -> String {
        return Date.dateFormatter.string(from: self as Date)
    }

    func toFullString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return dateFormatter.string(from: self as Date)
    }
    
    func toUTCString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        return dateFormatter.string(from: self as Date)
    }
    
    static var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm:ss.SSSS"
        return formatter
    }
}
