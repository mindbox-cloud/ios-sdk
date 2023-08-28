//
//  ContentPositionMargin.swift
//  Mindbox
//
//  Created by vailence on 14.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

struct ContentPositionMargin: Decodable, Equatable {
    let kind: PositionMarginKind
    let top: Double?
    let right: Double?
    let left: Double?
    let bottom: Double?
    
    enum CodingKeys: CodingKey {
        case kind
        case top
        case right
        case left
        case bottom
    }
    
    init(from decoder: Decoder, gravity: ContentPositionGravity) throws {
        let container: KeyedDecodingContainer<ContentPositionMargin.CodingKeys> = try decoder.container(keyedBy: ContentPositionMargin.CodingKeys.self)
        
        self.kind = try container.decode(PositionMarginKind.self, forKey: .kind)
        self.top = try container.decodeIfPresentSafely(Double.self, forKey: .top)
        self.right = try container.decodeIfPresentSafely(Double.self, forKey: .right)
        self.left = try container.decodeIfPresentSafely(Double.self, forKey: .left)
        self.bottom = try container.decodeIfPresentSafely(Double.self, forKey: .bottom)
        
        if !ContentPositionMarginValidator().isValid(item: self) {
            throw CustomDecodingError.decodingError("ContentPositionMargin not passed validation. It will be ignored.")
        }
    }
    
    init(kind: PositionMarginKind, top: Double? = nil, right: Double? = nil, left: Double? = nil, bottom: Double? = nil) {
        self.kind = kind
        self.top = top
        self.right = right
        self.left = left
        self.bottom = bottom
    }
}
