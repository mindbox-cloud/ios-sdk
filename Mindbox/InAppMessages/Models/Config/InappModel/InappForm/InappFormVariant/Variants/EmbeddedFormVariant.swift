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

    static func placeKey(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
