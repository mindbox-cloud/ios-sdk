//
//  DisplayConditions.swift
//  Mindbox
//
//  Created by Sergei Semko on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

enum DisplayConditions: Decodable, Equatable {

    case directCall

    case unrestricted

    enum CodingKeys: String, CodingKey {
        case type = "$type"
    }

    private static let directCallType = "directCall"

    /// Throws `DecodingError` when the value is not an object or `$type` is missing or not a string,
    /// and `CustomDecodingError.unknownType` when `$type` is a string the SDK does not know.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawType = try container.decode(String.self, forKey: .type)

        guard rawType == Self.directCallType else {
            throw CustomDecodingError.unknownType("displayConditions has unknown $type '\(rawType)'")
        }

        self = .directCall
    }
}
