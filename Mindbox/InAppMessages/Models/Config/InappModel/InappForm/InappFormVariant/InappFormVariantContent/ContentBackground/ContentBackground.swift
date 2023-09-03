//
//  ContentBackground.swift
//  Mindbox
//
//  Created by vailence on 03.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

struct ContentBackground: Decodable, Equatable {
    let layers: FailableDecodableArray<ContentBackgroundLayer>
    
    enum CodingKeys: String, CodingKey {
        case layers
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let layers = try container.decode(FailableDecodableArray<ContentBackgroundLayer>.self, forKey: .layers)
        
        if layers.elements.isEmpty {
            throw DecodingError.dataCorruptedError(
                forKey: .layers,
                in: container,
                debugDescription: "Layers cannot be empty."
            )
        }
        
        self.layers = layers
    }
}
