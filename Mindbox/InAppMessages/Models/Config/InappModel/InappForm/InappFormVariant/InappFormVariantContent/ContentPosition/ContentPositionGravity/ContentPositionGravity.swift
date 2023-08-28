//
//  ContentPositionGravity.swift
//  Mindbox
//
//  Created by vailence on 14.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

struct ContentPositionGravity: Decodable, Equatable {
    let vertical: VerticalType?
    let horizontal: HorizontalType?
    
    enum HorizontalType: String, Decodable {
        case left
        case right
        case center
        case unknown
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(RawValue.self)
            self = HorizontalType(rawValue: rawValue) ?? .unknown
        }
    }
    
    enum VerticalType: String, Decodable {
        case top
        case bottom
        case center
        case unknown
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(RawValue.self)
            self = VerticalType(rawValue: rawValue) ?? .unknown
        }
    }
    
    enum CodingKeys: CodingKey {
        case vertical
        case horizontal
    }
    
    init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<ContentPositionGravity.CodingKeys> = try decoder.container(keyedBy: ContentPositionGravity.CodingKeys.self)
        
        self.vertical = try container.decodeIfPresent(ContentPositionGravity.VerticalType.self, forKey: .vertical)
        self.horizontal = try container.decodeIfPresent(ContentPositionGravity.HorizontalType.self, forKey: .horizontal)
        
        if vertical == .unknown || horizontal == .unknown {
            throw CustomDecodingError.unknownType("")
        }
    }
}
