//
//  InappFormVariantContent.swift
//  Mindbox
//
//  Created by vailence on 03.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

struct InappFormVariantContentDTO: Decodable, Equatable {
    let background: ContentBackgroundDTO?
    let elements: [ContentElementDTO]?
}

struct InappFormVariantContent: Decodable, Equatable {
    let background: ContentBackground
    let elements: [ContentElement]?
}
