//
//  LayerActionType.swift
//  Mindbox
//
//  Created by vailence on 03.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

enum LayerActionType: String, Decodable, Equatable {
    case redirectUrl
    case unknown
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let type: String = try container.decode(String.self)
        self = LayerActionType(rawValue: type) ?? .unknown
    }
}
