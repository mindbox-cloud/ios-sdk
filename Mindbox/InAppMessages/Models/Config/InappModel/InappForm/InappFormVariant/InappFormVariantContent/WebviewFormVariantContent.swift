//
//  InappFormVariantContent.swift
//  Mindbox
//
//  Created by Egor Kitselyuk on 19.03.2025.
//

import Foundation

struct WebviewFormVariantContentDTO: Decodable, Equatable {
    let background: ContentBackgroundDTO?
}

struct WebviewFormVariantContent: Decodable, Equatable {
    let background: ContentBackground
}
