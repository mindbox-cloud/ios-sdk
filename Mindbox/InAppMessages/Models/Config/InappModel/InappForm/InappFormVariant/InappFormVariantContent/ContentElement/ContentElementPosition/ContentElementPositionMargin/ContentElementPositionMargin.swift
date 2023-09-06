//
//  ContentElementPositionMargin.swift
//  Mindbox
//
//  Created by vailence on 04.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

struct ContentElementPositionMarginDTO: Decodable, Equatable {
    let kind: PositionMarginKind
    let top: Double?
    let right: Double?
    let left: Double?
    let bottom: Double?
}

struct ContentElementPositionMargin: Decodable, Equatable {
    let kind: PositionMarginKind
    let top: Double
    let right: Double
    let left: Double
    let bottom: Double
}
