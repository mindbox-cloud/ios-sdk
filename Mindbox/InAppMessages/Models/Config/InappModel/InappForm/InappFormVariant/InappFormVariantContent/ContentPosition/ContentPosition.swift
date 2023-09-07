//
//  ContentPosition.swift
//  Mindbox
//
//  Created by vailence on 14.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

struct ContentPositionDTO: Decodable, Equatable {
    let gravity: ContentPositionGravityDTO?
    let margin: ContentPositionMarginDTO?
}

struct ContentPosition: Decodable, Equatable {
    let gravity: ContentPositionGravity?
    let margin: ContentPositionMargin
}
