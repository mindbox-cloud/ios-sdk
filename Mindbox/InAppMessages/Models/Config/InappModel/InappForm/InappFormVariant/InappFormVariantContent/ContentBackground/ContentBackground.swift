//
//  ContentBackground.swift
//  Mindbox
//
//  Created by vailence on 03.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

struct ContentBackgroundDTO: Decodable, Equatable {
    let layers: [ContentBackgroundLayerDTO]?
}

struct ContentBackground: Decodable, Equatable {
    let layers: [ContentBackgroundLayer]
}
