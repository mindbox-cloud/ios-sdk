//
//  ContentBackgroundLayerSource.swift
//  Mindbox
//
//  Created by vailence on 03.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

struct ContentBackgroundLayerSource: Decodable, Equatable {
    let type: LayerSourceType
    let value: String?
    
    enum CodingKeys: String, CodingKey {
        case type = "$type"
        case value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(LayerSourceType.self, forKey: .type)
        self.value = try container.decodeIfPresent(String.self, forKey: .value)

        if !ContentBackgroundLayerSourceValidator().isValid(item: self) {
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Invalid layer source."
            )
        }
    }
    
    init(type: LayerSourceType, value: String? = nil) {
        self.type = type
        self.value = value
    }
}
