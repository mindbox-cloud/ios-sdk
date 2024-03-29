//
//  SnackbarFormVariant.swift
//  Mindbox
//
//  Created by vailence on 14.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

struct SnackbarFormVariantDTO: iFormVariant, Decodable, Equatable {
    let content: SnackbarFormVariantContentDTO?
}

struct SnackbarFormVariant: iFormVariant, Decodable, Equatable {
    let content: SnackbarFormVariantContent
}
