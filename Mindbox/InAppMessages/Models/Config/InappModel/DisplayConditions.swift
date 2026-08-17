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

/// Fail-open: anything we cannot parse comes out as `unrestricted`, so an in-app never becomes
/// less showable over a value we could not read.
enum DisplayConditions: Decodable, Equatable {

    case directCall

    case unrestricted

    enum CodingKeys: String, CodingKey {
        case type = "$type"
    }

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
