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
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        unit = try container.decode(Unit.self, forKey: .unit)
        value = try container.decode(Int.self, forKey: .value)
        
        guard value > 0 else {
            throw DecodingError.dataCorruptedError(forKey: .value, in: container, debugDescription: "PeriodicFrequency value must be > 0. Skip inapp")
        }
    }
    
    init(unit: Unit, value: Int) {
        self.unit = unit
        self.value = value
    }
    
    private enum CodingKeys: String, CodingKey {
        case unit
        case value
    }

    enum Unit: String, Decodable {
        case seconds
        case minutes
        case hours
        case days

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
