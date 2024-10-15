//
//  ContentElementSizeKind.swift
//  Mindbox
//
//  Created by vailence on 04.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

enum ContentElementSizeKind: String, Decodable, Equatable {
    case dp
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(RawValue.self)
        self = ContentElementSizeKind(rawValue: rawValue) ?? .unknown
    }
}
