//
//  SegmentTargetingChecker.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 19.01.2023.
//

import Foundation

final class SegmentTargetingChecker: InternalTargetingChecker<SegmentTargeting> {

    weak var checker: TargetingCheckerContextProtocol?
    
    override func prepareInternal(targeting: SegmentTargeting, context: inout PreparationContext) -> Void {
        context.segments.append(targeting.segmentationExternalId)
    }
    
    override func checkInternal(targeting: SegmentTargeting) -> Bool {
        guard let checker = checker else {
            return false
        }
        
        let segment = checker.checkedSegmentations.first(where: {
            $0.segment?.ids?.externalId == targeting.segmentExternalId
        })
        
        switch targeting.kind {
        case .positive:
            return segment != nil
        case .negative:
            return segment == nil
        }
    }
}
