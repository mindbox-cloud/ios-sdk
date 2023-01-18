//
//  GeoTargeting.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 18.01.2023.
//

import Foundation

struct GeoTargeting: ITargeting, Decodable {
    let kind: TargetingNegationConditionKindType
    let ids: [Int]
}
