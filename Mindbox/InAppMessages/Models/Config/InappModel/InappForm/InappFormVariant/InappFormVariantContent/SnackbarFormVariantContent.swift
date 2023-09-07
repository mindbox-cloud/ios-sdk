//
//  SnackbarFormVariantContent.swift
//  Mindbox
//
//  Created by vailence on 14.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

struct SnackbarFormVariantContentDTO: Decodable, Equatable {
    let background: ContentBackgroundDTO?
    let position: ContentPositionDTO?
    let elements: [ContentElementDTO]?
}

struct SnackbarFormVariantContent: Decodable, Equatable {
    let background: ContentBackground
    let position: ContentPosition
    let elements: [ContentElement]
}
