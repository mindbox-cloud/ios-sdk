//
//  EmbeddedFormVariant.swift
//  Mindbox
//
//  Created by Sergei Semko on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

/// The place name is optional here and required in the domain model on purpose: a variant without a
/// usable place is dropped by the variants filter, which can skip one variant, while a throw at
/// decode time would take the whole in-app down.
struct EmbeddedFormVariantDTO: iFormVariant, Decodable, Equatable {
    let content: InappFormVariantContentDTO?
    let placeSystemName: String?
}

/// An in-app rendered inside a block the host app placed in its own layout, addressed by the place
/// name. The only variant that never reaches the overlay displayer.
struct EmbeddedFormVariant: iFormVariant, Decodable, Equatable {

    let content: InappFormVariantContent

    /// Trimmed and non-empty by construction. Case is significant: it is matched against the name the
    /// host app passes, and a case-only mismatch is a configuration error rather than a match.
    let placeSystemName: String
}
