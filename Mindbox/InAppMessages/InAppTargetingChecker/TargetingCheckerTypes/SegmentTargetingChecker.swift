//
//  SegmentTargetingChecker.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 19.01.2023.
//

import Foundation

final class SegmentTargetingChecker: InternalTargetingChecker<SegmentTargeting> {

    weak var checker: TargetingCheckerContextProtocol?

    override func prepareInternal(id: String, targeting: SegmentTargeting, context: inout PreparationContext) {
        context.segments.append(targeting.segmentationExternalId)
    }

    override func checkInternal(targeting: SegmentTargeting) -> Bool {
        guard let checker = checker else {
            return false
        }

        guard let checkedSegmentations = checker.checkedSegmentations,
                !checkedSegmentations.isEmpty else {
            return false
        }

        let segment = checkedSegmentations.first(where: {
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
