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
        let inapps: TTLUnit?
    }
}

extension Settings.TimeToLive {
    struct TTLUnit: Decodable, Equatable {
        let unit: Unit?
        let value: Int?
        
        enum Unit: String, Decodable {
            case seconds
            case minutes
            case hours
            case days
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            value = try? container.decode(Int.self, forKey: .value)
            let unitString = try? container.decode(String.self, forKey: .unit).lowercased()
            self.unit = Unit(rawValue: unitString ?? "")
        }

        
        private enum CodingKeys: String, CodingKey {
            case unit, value
        }
    }
}
