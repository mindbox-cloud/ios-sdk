//
//  InAppStub.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 19.01.2023.
//  Copyright © 2023 Mikhail Barilov. All rights reserved.
//

import Foundation
@testable import Mindbox

class InAppStub {
    func getTargetingTrueNode() -> Targeting {
        .true(TrueTargeting())
    }
    
    func getTargetingCity(model: CityTargeting) -> Targeting {
        .city(model)
    }
    
    func getTargetingRegion(model: RegionTargeting) -> Targeting {
        .region(model)
    }
    
    func getTargetingCountry(model: CountryTargeting) -> Targeting {
        .country(model)
    }
    
    func getTargetingSegment(model: SegmentTargeting) -> Targeting {
        .segment(model)
    }
    
    func getCheckedSegmentation(segmentationID: String, segmentID: String?) -> SegmentationCheckResponse.CustomerSegmentation {
        var segment: SegmentationCheckResponse.Segment?
        if let segmentID = segmentID {
            segment = SegmentationCheckResponse.Segment(ids: SegmentationCheckResponse.Id(externalId: segmentID))
        }
        
        return .init(segmentation: SegmentationCheckResponse.Segmentation(ids: SegmentationCheckResponse.Id(externalId: segmentationID)),
                     segment: segment)
    }
    
    func getAnd(model: AndTargeting) -> Targeting {
        .and(model)
    }
    
    func getOr(model: OrTargeting) -> Targeting {
        .or(model)
    }
}
