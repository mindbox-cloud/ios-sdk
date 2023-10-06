//
//  ContentPositionMargin.swift
//  Mindbox
//
//  Created by vailence on 14.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

struct ContentPositionMarginDTO: Decodable, Equatable {
    let kind: ContentPositionMarginKind
    let top: Double?
    let right: Double?
    let left: Double?
    let bottom: Double?
}

struct ContentPositionMargin: Decodable, Equatable {
    let kind: ContentPositionMarginKind
    let top: Double
    let right: Double
    let left: Double
    let bottom: Double
}

enum ContentPositionMarginKind: String, Decodable, Equatable {
    case dp
    case unknown
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(RawValue.self)
        self = ContentPositionMarginKind(rawValue: rawValue) ?? .unknown
    }
}
