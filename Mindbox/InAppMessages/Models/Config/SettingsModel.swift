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
    
    enum CodingKeys: CodingKey {
        case operations, ttl
    }

    init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<Settings.CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
        self.operations = try? container.decodeIfPresent(SettingsOperations.self, forKey: .operations)
        self.ttl = try? container.decodeIfPresent(TimeToLive.self, forKey: .ttl)
    }
    
    struct SettingsOperations: Decodable, Equatable {
        
        let viewProduct: Operation?
        let viewCategory: Operation?
        let setCart: Operation?
        
        enum CodingKeys: CodingKey {
            case viewProduct
            case viewCategory
            case setCart
        }
        
        init(from decoder: any Decoder) throws {
            let container: KeyedDecodingContainer<Settings.SettingsOperations.CodingKeys> = try decoder.container(keyedBy: Settings.SettingsOperations.CodingKeys.self)
            self.viewProduct = try? container.decodeIfPresent(Settings.SettingsOperations.Operation.self, forKey: Settings.SettingsOperations.CodingKeys.viewProduct)
            self.viewCategory = try? container.decodeIfPresent(Settings.SettingsOperations.Operation.self, forKey: Settings.SettingsOperations.CodingKeys.viewCategory)
            self.setCart = try? container.decodeIfPresent(Settings.SettingsOperations.Operation.self, forKey: Settings.SettingsOperations.CodingKeys.setCart)
        }
        
        struct Operation: Decodable, Equatable {
            let systemName: String
        }
    }
    
    struct TimeToLive: Decodable, Equatable {
        let inapps: String?
    }
}

extension Settings {
    init(operations: SettingsOperations? = nil, ttl: TimeToLive?) {
        self.operations = operations
        self.ttl = ttl
    }
}
