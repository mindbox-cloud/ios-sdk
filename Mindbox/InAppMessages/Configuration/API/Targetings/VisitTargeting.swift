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
}
