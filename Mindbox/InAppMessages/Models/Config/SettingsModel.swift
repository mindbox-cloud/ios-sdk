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
    
    struct SettingsOperations: Decodable, Equatable {
        
        let viewProduct: Operation?
        let viewCategory: Operation?
        let setCart: Operation?
        
        struct Operation: Decodable, Equatable {
            let systemName: String
        }
    }
}

extension Settings.TimeToLive {
    struct TTLUnit: Decodable, Equatable {
        let unit: Unit?
        let value: Int?
        
        init(unit: Unit?, value: Int?) {
            self.unit = unit
            self.value = value
        }
        
        private enum CodingKeys: String, CodingKey {
            case unit, value
        }
    }
}

enum Unit: String, Decodable {
    case seconds = "seconds"
    case minutes = "minutes"
    case hours = "hours"
    case days = "days"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let decodedString = try container.decode(String.self).lowercased() // Преобразование к нижнему регистру
        
        guard let value = Unit(rawValue: decodedString) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Неизвестная единица времени")
        }
        
        self = value
    }
}
