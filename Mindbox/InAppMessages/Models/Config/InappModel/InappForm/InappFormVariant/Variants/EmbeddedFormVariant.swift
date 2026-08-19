//
//  EmbeddedFormVariant.swift
//  Mindbox
//
//  Created by Sergei Semko on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

struct EmbeddedFormVariantDTO: iFormVariant, Decodable, Equatable {
    let content: InappFormVariantContentDTO?
    let placeSystemName: String?
}

struct EmbeddedFormVariant: iFormVariant, Decodable, Equatable {

    let content: InappFormVariantContent

    /// Trimmed and non-empty by construction; matched case-sensitively against the name the host passes.
    let placeSystemName: String
}
