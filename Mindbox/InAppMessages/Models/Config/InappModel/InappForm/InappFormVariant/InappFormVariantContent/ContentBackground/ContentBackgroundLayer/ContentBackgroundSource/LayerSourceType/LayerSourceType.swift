//
//  LayerSourceType.swift
//  FirebaseCore
//
//  Created by vailence on 03.08.2023.
//

import Foundation

enum LayerSourceType: String, Decodable, Equatable {
    case url
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let type: String = try container.decode(String.self)
        self = LayerSourceType(rawValue: type) ?? .unknown
    }
}
