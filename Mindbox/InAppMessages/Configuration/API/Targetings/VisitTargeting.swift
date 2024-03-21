//
//  VisitTargeting.swift
//  Mindbox
//
//  Created by vailence on 21.03.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation

enum VisitTargetingKindType: String, Decodable {
    case greaterOrEqual
    case lessOrEqual
    case equal
    case notEqual
    
    enum CodingKeys: String, CodingKey {
        case greaterOrEqual = "gte"
        case lessOrEqual = "lte"
        case equals
        case notEquals
    }
}

struct VisitTargeting: ITargeting, Decodable {
    let kind: VisitTargetingKindType
    let value: Int
}
