//
//  ContentPosition.swift
//  Mindbox
//
//  Created by vailence on 14.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

struct ContentPosition: Decodable, Equatable {
    let gravity: FailableDecodable<ContentPositionGravity>?
    let margin: FailableDecodable<ContentPositionMargin>?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        gravity = try container.decodeIfPresent(FailableDecodable<ContentPositionGravity>.self, forKey: .gravity)
        margin = try container.decodeIfPresent(FailableDecodable<ContentPositionMargin>.self, forKey: .margin)
    }
    
    enum CodingKeys: String, CodingKey {
        case gravity, margin
    }
}
