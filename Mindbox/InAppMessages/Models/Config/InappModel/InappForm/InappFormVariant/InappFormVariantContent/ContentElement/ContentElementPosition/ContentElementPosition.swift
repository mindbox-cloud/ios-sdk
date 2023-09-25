//
//  ContentElementPosition.swift
//  Mindbox
//
//  Created by vailence on 04.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

struct ContentElementPositionDTO: Decodable, Equatable {
    let margin: ContentElementPositionMarginDTO?
}


struct ContentElementPosition: Decodable, Equatable {
    let margin: ContentElementPositionMargin
}
