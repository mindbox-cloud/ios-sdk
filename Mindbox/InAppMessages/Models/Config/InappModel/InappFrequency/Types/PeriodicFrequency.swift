//
//  PeriodicFrequency.swift
//  Mindbox
//
//  Created by vailence on 10.04.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation

struct PeriodicFrequency: Decodable, Equatable {
    let unit: Unit
    let value: Int
    
    enum Unit: String, Decodable {
        case seconds = "seconds"
        case minutes = "minutes"
        case hours = "hours"
        case days = "days"

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let decodedString = try container.decode(String.self).lowercased()
            
            guard let value = Unit(rawValue: decodedString) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Неизвестная единица времени")
            }
            
            self = value
        }
    }
}

extension PeriodicFrequency.Unit {
    var calendarComponent: Calendar.Component {
        switch self {
        case .seconds:
            return .second
        case .minutes:
            return .minute
        case .hours:
            return .hour
        case .days:
            return .day
        }
    }
}
