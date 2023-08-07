//
//  ContentBackgroundLayerAction.swift
//  Mindbox
//
//  Created by vailence on 03.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

struct ContentBackgroundLayerAction: Decodable, Equatable {
    let type: LayerActionType
    let intentPayload: String?
    let value: String?

    enum CodingKeys: String, CodingKey {
        case type = "$type"
        case intentPayload
        case value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(LayerActionType.self, forKey: .type)
        self.intentPayload = try container.decodeIfPresent(String.self, forKey: .intentPayload)
        self.value = try container.decodeIfPresent(String.self, forKey: .value)
        
        if !ContentBackgroundLayerActionValidator().isValid(item: self) {
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Invalid layer action."
            )
        }
    }
}
