//
//  PositionMarginKind.swift
//  Mindbox
//
//  Created by vailence on 04.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

enum PositionMarginKind: String, Decodable, Equatable {
    case proportion
    case unknown
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let type: String = try container.decode(String.self)
        self = PositionMarginKind(rawValue: type) ?? .unknown
    }
}
