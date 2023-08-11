//
//  ContentElementSize.swift
//  Mindbox
//
//  Created by vailence on 04.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

struct ContentElementSize: Decodable, Equatable {
    let kind: ContentElementSizeKind
    let width: Double
    let height: Double
    
    enum CodingKeys: String, CodingKey {
        case kind
        case width
        case height
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decode(ContentElementSizeKind.self, forKey: .kind)
        width = try container.decode(Double.self, forKey: .width)
        height = try container.decode(Double.self, forKey: .height)
        
        if !ContentElementSizeValidator().isValid(item: self) {
            throw CustomDecodingError.decodingError("Content element size validation not passed.")
        }
    }
    
    init(kind: ContentElementSizeKind, width: Double, height: Double) {
        self.kind = kind
        self.width = width
        self.height = height
    }
}
