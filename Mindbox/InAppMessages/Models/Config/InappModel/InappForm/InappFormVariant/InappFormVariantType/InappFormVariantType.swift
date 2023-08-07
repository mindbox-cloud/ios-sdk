//
//  InappFormVariantType.swift
//  Mindbox
//
//  Created by vailence on 03.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

enum InappFormVariantType: String, Decodable, Equatable {
    case modal
    case snackbar
    case unknown
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(RawValue.self)
        self = InappFormVariantType(rawValue: rawValue) ?? .unknown
    }
}
