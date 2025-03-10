//
//  ProductSegmentChecker.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 29.03.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

final class ProductSegmentChecker: InternalTargetingChecker<ProductSegmentTargeting> {
    
    weak var checker: TargetingCheckerContextProtocol?
    
    override func prepareInternal(id: String, targeting: ProductSegmentTargeting, context: inout PreparationContext) {
        let key = "viewProduct".lowercased()
        context.operationInapps[key, default: []].insert(id)
        context.productSegments.append(targeting.segmentationExternalId)
    }
    
    override func checkInternal(targeting: ProductSegmentTargeting) -> Bool {
        guard let checker = checker else {
            Logger.common(message: "[PSC] Нет checker, false ❌ ", level: .info)
            return false
        }
        
        guard let checkedProductSegmentations = checker.checkedProductSegmentations, !checkedProductSegmentations.isEmpty else {
            Logger.common(message: "[PSC] Нет сегментаций, false ❌ ", level: .info)
            return false
        }
        
        let segment = checkedProductSegmentations.first {
            $0.segment?.ids?.externalId == targeting.segmentExternalId
        }
        
        // Логи для отладки перед switch
        Logger.common(message: "[PSC] Targeting: \(targeting)", level: .info)
        Logger.common(message: "[PSC] CheckedProductSegmentations: \(checkedProductSegmentations)", level: .info)
        Logger.common(message: "[PSC] Segment: \(String(describing: segment))", level: .info)
        
        switch targeting.kind {
        case .positive:
            if segment != nil {
                Logger.common(message: "[PSC] Позитив: найден, true ✅", level: .info)
                return true
            } else {
                Logger.common(message: "[PSC] Позитив: не найден, false ❌ ", level: .info)
                return false
            }
        case .negative:
            if segment == nil {
                Logger.common(message: "[PSC] Негатив: не найден, true ✅", level: .info)
                return true
            } else {
                Logger.common(message: "[PSC] Негатив: найден, false ❌ ", level: .info)
                return false
            }
        }
    }
}
