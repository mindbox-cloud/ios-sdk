//
//  DisplayConditions.swift
//  Mindbox
//
//  Created by Sergei Semko on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

enum DisplayConditionsType: String, Decodable {
    case directCall
    case unknown

    init(from decoder: Decoder) throws {
        let container: SingleValueDecodingContainer = try decoder.singleValueContainer()
        let type: String = try container.decode(String.self)
        self = DisplayConditionsType(rawValue: type) ?? .unknown
    }
}

enum DisplayConditions: Decodable, Equatable {

    case directCall

    case unrestricted

    enum CodingKeys: String, CodingKey {
        case type = "$type"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        guard let type = try? container.decode(DisplayConditionsType.self, forKey: .type) else {
            throw CustomDecodingError.decodingError("displayConditions has no readable $type. Inapp will be ignored.")
        }

        switch type {
        case .directCall:
            self = .directCall
        case .unknown:
            throw CustomDecodingError.unknownType("displayConditions has unknown type. Inapp will be ignored.")
        }
    }
}
