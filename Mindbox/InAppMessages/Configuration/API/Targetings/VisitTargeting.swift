//
//  VisitTargeting.swift
//  Mindbox
//
//  Created by vailence on 21.03.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation

enum VisitTargetingKindType: String, Decodable {
    case gte
    case lte
    case equals
    case notEquals
}

struct VisitTargeting: ITargeting, Decodable {
    let kind: VisitTargetingKindType
    let value: Int
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decode(VisitTargetingKindType.self, forKey: .kind)
        value = try container.decode(Int.self, forKey: .value)
    
        guard value >= 0 else {
            throw DecodingError.dataCorruptedError(forKey: .value, in: container, debugDescription: "VisitTargeting value must be >= 0")
        }
    }
    
    init(kind: VisitTargetingKindType, value: Int) {
        self.kind = kind
        self.value = value
    }
    
    private enum CodingKeys: String, CodingKey {
        case kind
        case value
    }
}
