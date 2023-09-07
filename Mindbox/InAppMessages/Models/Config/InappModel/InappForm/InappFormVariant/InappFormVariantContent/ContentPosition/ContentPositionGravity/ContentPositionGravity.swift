//
//  ContentPositionGravity.swift
//  Mindbox
//
//  Created by vailence on 14.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

struct ContentPositionGravityDTO: Decodable, Equatable {
    let vertical: GravityVerticalType?
    let horizontal: GravityHorizontalType?
}

struct ContentPositionGravity: Decodable, Equatable {
    let vertical: GravityVerticalType?
    let horizontal: GravityHorizontalType?
}

enum GravityHorizontalType: String, Decodable {
    case left
    case right
    case center
    case unknown
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(RawValue.self)
        self = GravityHorizontalType(rawValue: rawValue) ?? .unknown
    }
}

enum GravityVerticalType: String, Decodable {
    case top
    case bottom
    case center
    case unknown
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(RawValue.self)
        self = GravityVerticalType(rawValue: rawValue) ?? .unknown
    }
}
