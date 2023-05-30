//
//  ProductSegmentTargeting.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 29.03.2023.
//

import Foundation

struct ProductSegmentTargeting: ITargeting, Decodable {
    let kind: TargetingNegationConditionKindType
    let segmentationInternalId: String
    let segmentationExternalId: String
    let segmentExternalId: String
}
