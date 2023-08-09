//
//  InappFormVariant.swift
//  Mindbox
//
//  Created by vailence on 03.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

struct InappFormVariant: Decodable, Equatable {
    let type: InappFormVariantType
    let content: InappFormVariantContent?
    
    enum CodingKeys: String, CodingKey {
        case type = "$type"
        case content
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(InappFormVariantType.self, forKey: .type)
        content = try container.decodeIfPresent(InappFormVariantContent.self, forKey: .content)
        
        if !InappFormVariantValidator().isValid(item: self) {
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Invalid Variant"
            )
        }
    }
    
    internal init(type: InappFormVariantType, content: InappFormVariantContent? = nil) {
        self.type = type
        self.content = content
    }
}
