//
//  ProductSegmentChecker.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 29.03.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

final class ProductSegmentChecker: InternalTargetingChecker<ProductSegmentTargeting> {

    weak var checker: TargetingCheckerContextProtocol?

    override func prepareInternal(id: String, targeting: ProductSegmentTargeting, context: inout PreparationContext) {
        if let key = SessionTemporaryStorage.shared.viewProductOperation {
            context.operationInapps[key.lowercased(), default: []].insert(id)
        }
        context.productSegments.append(targeting.segmentationExternalId)
    }

    override func checkInternal(targeting: ProductSegmentTargeting) -> Bool {
        guard let checker = checker else {
            return false
        }

        guard let checkedProductSegmentations = checker.checkedProductSegmentations, !checkedProductSegmentations.isEmpty else {
            return false
        }

        let segment = checkedProductSegmentations.first(where: {
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
