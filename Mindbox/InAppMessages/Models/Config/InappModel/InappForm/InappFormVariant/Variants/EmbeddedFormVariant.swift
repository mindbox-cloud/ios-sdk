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

    /// Canonical by construction — `placeKey(_:)` of what the config said. The name the host passes
    /// goes through the same key, so the two meet whatever padding or letter case either side used.
    let placeSystemName: String

    init(content: InappFormVariantContent, placeSystemName: String) {
        self.content = content
        self.placeSystemName = Self.placeKey(placeSystemName)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(content: try container.decode(InappFormVariantContent.self, forKey: .content),
                  placeSystemName: try container.decode(String.self, forKey: .placeSystemName))
    }

    private enum CodingKeys: String, CodingKey {
        case content
        case placeSystemName
    }

    /// A place name is matched like an operation system name: the surrounding whitespace is trimmed
    /// and the letter case is ignored, so `Main-Screen-Top` and `main-screen-top` are one place, not
    /// two. In sync with Android's `PlaceKey`.
    static func placeKey(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
