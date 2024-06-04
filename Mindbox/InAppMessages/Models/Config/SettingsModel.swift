//
//  SettingsModel.swift
//  Mindbox
//
//  Created by vailence on 15.06.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

struct Settings: Decodable, Equatable {
    let operations: SettingsOperations?
    let ttl: TimeToLive?
    
    struct SettingsOperations: Decodable, Equatable {
        
        let viewProduct: Operation?
        let viewCategory: Operation?
        let setCart: Operation?
        
        struct Operation: Decodable, Equatable {
            let systemName: String
        }
    }
    
    struct TimeToLive: Decodable, Equatable {
        let inapps: String?
    }
}

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

extension Unit {
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
