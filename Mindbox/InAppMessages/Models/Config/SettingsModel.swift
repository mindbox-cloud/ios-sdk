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
    
    struct SettingsOperations: Decodable, Equatable {
        
        let viewProduct: Operation?
        let viewCategory: Operation?
        let setCart: Operation?
        
        enum CodingKeys: CodingKey {
            case viewProduct
            case viewCategory
            case setCart
        }
        
        struct Operation: Decodable, Equatable {
            let systemName: String
        }
    }
    
    struct TimeToLive: Decodable, Equatable {
        let inapps: String?
        
        enum CodingKeys: CodingKey {
            case inapps
        }
    }
}

extension Settings {
    init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<Settings.CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
        self.operations = try? container.decodeIfPresent(SettingsOperations.self, forKey: .operations)
        self.ttl = try? container.decodeIfPresent(TimeToLive.self, forKey: .ttl)
    }
}

extension Settings.SettingsOperations {
    init(from decoder: any Decoder) throws {
        let container: KeyedDecodingContainer<Settings.SettingsOperations.CodingKeys> = try decoder.container(keyedBy: Settings.SettingsOperations.CodingKeys.self)
        self.viewProduct = try? container.decodeIfPresent(Settings.SettingsOperations.Operation.self, forKey: Settings.SettingsOperations.CodingKeys.viewProduct)
        self.viewCategory = try? container.decodeIfPresent(Settings.SettingsOperations.Operation.self, forKey: Settings.SettingsOperations.CodingKeys.viewCategory)
        self.setCart = try? container.decodeIfPresent(Settings.SettingsOperations.Operation.self, forKey: Settings.SettingsOperations.CodingKeys.setCart)
        
        if viewProduct == nil && viewCategory == nil && setCart == nil {
            // Will never be caught because of `try?` in `Settings.init`
            throw DecodingError.dataCorruptedError(forKey: .viewProduct, in: container, debugDescription: "All operations are nil")
        }
    }
}

extension Settings.TimeToLive {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let inapps = try? container.decodeIfPresent(String.self, forKey: .inapps) {
            self.inapps = inapps
        } else {
            throw DecodingError.dataCorruptedError(forKey: .inapps, in: container, debugDescription: "Missing required key 'inapps'")
        }
    }
}
