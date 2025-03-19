//
//  SnackbarFormVariant.swift
//  Mindbox
//
//  Created by Egor Kitselyuk on 19.03.2025.
//

import Foundation

struct WebviewFormVariantDTO: iFormVariant, Decodable, Equatable {
    let content: WebviewFormVariantContentDTO?
}

struct WebviewFormVariant: iFormVariant, Decodable, Equatable {
    let content: WebviewFormVariantContent
}
