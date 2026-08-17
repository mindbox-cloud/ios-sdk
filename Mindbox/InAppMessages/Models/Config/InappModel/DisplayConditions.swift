//
//  DisplayConditions.swift
//  Mindbox
//
//  Created by Sergei Semko on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

enum DisplayConditionsType: String, Decodable {
    case directCall
    case unknown

    init(from decoder: Decoder) throws {
        let container: SingleValueDecodingContainer = try decoder.singleValueContainer()
        let type: String = try container.decode(String.self)
        self = DisplayConditionsType(rawValue: type) ?? .unknown
    }
}

/// What is allowed to initiate the show.
///
/// A restriction field: anything we fail to understand comes out as `unrestricted`, so an in-app never
/// becomes less showable because of a value we could not parse.
enum DisplayConditions: Decodable, Equatable {

    /// Only a direct call by id — no trigger ever shows this in-app.
    case directCall

    /// A trigger or a direct call, which is how in-apps behaved before the field existed.
    case unrestricted

    enum CodingKeys: String, CodingKey {
        case type = "$type"
    }

    /// Never throws: this runs inside the in-app decoder, where a thrown error discards the whole
    /// in-app.
    init(from decoder: Decoder) throws {
        guard let container = try? decoder.container(keyedBy: CodingKeys.self) else {
            Logger.common(message: "[DisplayConditions] Value is not an object. Showing as before.",
                          level: .error, category: .inAppMessages)
            self = .unrestricted
            return
        }

        let type = (try? container.decode(DisplayConditionsType.self, forKey: .type)) ?? .unknown

        switch type {
        case .directCall:
            self = .directCall
        case .unknown:
            Logger.common(message: "[DisplayConditions] Unknown type. Showing as before.",
                          level: .error, category: .inAppMessages)
            self = .unrestricted
        }
    }
}
