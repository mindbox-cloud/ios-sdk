//
//  GeoTargeting.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 18.01.2023.
//

import Foundation

struct CityTargeting: ITargeting, Decodable {
    let kind: TargetingNegationConditionKindType
    let ids: [Int]
}

struct RegionTargeting: ITargeting, Decodable {
    let kind: TargetingNegationConditionKindType
    let ids: [Int]
}

struct CountryTargeting: ITargeting, Decodable {
    let kind: TargetingNegationConditionKindType
    let ids: [Int]
}
