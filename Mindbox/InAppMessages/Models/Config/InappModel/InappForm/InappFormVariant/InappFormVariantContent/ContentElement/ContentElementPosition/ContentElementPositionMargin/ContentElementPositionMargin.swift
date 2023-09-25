//
//  ContentElementPositionMargin.swift
//  Mindbox
//
//  Created by vailence on 04.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

struct ContentElementPositionMarginDTO: Decodable, Equatable {
    let kind: ElementPositionMarginKind
    let top: Double?
    let right: Double?
    let left: Double?
    let bottom: Double?
}

struct ContentElementPositionMargin: Decodable, Equatable {
    let kind: ElementPositionMarginKind
    let top: Double
    let right: Double
    let left: Double
    let bottom: Double
}

enum ElementPositionMarginKind: String, Decodable, Equatable {
    case proportion
    case unknown
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(RawValue.self)
        self = ElementPositionMarginKind(rawValue: rawValue) ?? .unknown
    }
}
