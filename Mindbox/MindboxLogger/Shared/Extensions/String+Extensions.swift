//
//  String+Extensions.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 15.02.2023.
//

import Foundation

enum DateFormat: String {
    case api = "yyyy-MM-dd'T'HH:mm:ss"
    case utc = "yyyy-MM-dd'T'HH:mm:ss'Z'"
    
    var value: String {
        return self.rawValue
    }
}


extension String {
    func toDate(withFormat format: DateFormat) -> Date? {
        let dateFormatterGet = DateFormatter()
        dateFormatterGet.dateFormat = format.value
        dateFormatterGet.timeZone = TimeZone(identifier: "UTC")
        
        return dateFormatterGet.date(from: self)
    }
}
