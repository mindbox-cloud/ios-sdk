//
//  ContentElement.swift
//  Mindbox
//
//  Created by vailence on 04.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

struct ContentElement: Decodable, Equatable {
    let type: ContentElementType
    let color: String?
    let lineWidth: Int?
    let size: ContentElementSize?
    let position: ContentElementPosition?
    let gravity: ContentElementGravity?
    
    enum CodingKeys: String, CodingKey {
        case type = "$type"
        case color
        case lineWidth
        case size
        case position
        case gravity
    }
    
    init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<ContentElement.CodingKeys> = try decoder.container(keyedBy: ContentElement.CodingKeys.self)
        
        self.type = try container.decode(ContentElementType.self, forKey: ContentElement.CodingKeys.type)
        self.color = try container.decodeIfPresentSafely(String.self, forKey: .color)
        self.lineWidth = try container.decodeIfPresentSafely(Int.self, forKey: .lineWidth)
        self.size = try container.decodeIfPresent(ContentElementSize.self, forKey: .size)
        self.position = try container.decodeIfPresent(ContentElementPosition.self, forKey: .position)
        self.gravity = try container.decodeIfPresent(ContentElementGravity.self, forKey: .gravity)
        
        if !ContentElementValidator().isValid(item: self) {
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Layers cannot be empty."
            )
        }
    }
    
    internal init(type: ContentElementType, color: String? = nil, lineWidth: Int? = nil, size: ContentElementSize? = nil, position: ContentElementPosition? = nil, gravity: ContentElementGravity? = nil) {
        self.type = type
        self.color = color
        self.lineWidth = lineWidth
        self.size = size
        self.position = position
        self.gravity = gravity
    }
}
