//
//  SegmentTargeting.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 17.01.2023.
//

import Foundation

struct SegmentTargeting: ITargeting, Decodable {
    let kind: TargetingNegationConditionKindType
    let segmentationInternalId: String
    let segmentationExternalId: String
    let segmentExternalId: String
}
