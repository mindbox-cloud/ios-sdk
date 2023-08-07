//
//  ContentBackgroundLayer.swift
//  Mindbox
//
//  Created by vailence on 03.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

struct ContentBackgroundLayer: Decodable, Equatable {
    let type: ContentBackgroundLayerType
    let action: ContentBackgroundLayerAction?
    let source: ContentBackgroundLayerSource?

    enum CodingKeys: String, CodingKey {
        case type = "$type"
        case action
        case source
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(ContentBackgroundLayerType.self, forKey: .type)
        action = try container.decodeIfPresent(ContentBackgroundLayerAction.self, forKey: .action)
        source = try container.decodeIfPresent(ContentBackgroundLayerSource.self, forKey: .source)
        
        if !ContentBackgroundLayerValidator().isValid(item: self) {
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Invalid Layer."
            )
        }
    }
}
