//
//  SegmentTargetingChecker.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 19.01.2023.
//

import Foundation
import MindboxLogger

final class SegmentTargetingChecker: InternalTargetingChecker<SegmentTargeting> {

    weak var checker: TargetingCheckerContextProtocol?

    override func prepareInternal(id: String, targeting: SegmentTargeting, context: inout PreparationContext) {
        context.segments.append(targeting.segmentationExternalId)
    }

    override func checkInternal(targeting: SegmentTargeting) -> Bool {
        guard let checker = checker else {
            Logger.common(message: "[STC] Нет checker, false ❌ ", level: .info)
            return false
        }

        guard let checkedSegmentations = checker.checkedSegmentations, !checkedSegmentations.isEmpty else {
            Logger.common(message: "[STC] Нет сегментаций, false ❌ ", level: .info)
            return false
        }

        let segment = checkedSegmentations.first {
            $0.segment?.ids?.externalId == targeting.segmentExternalId
        }

//        Logger.common(message: "[STC] Targeting: \(targeting)", level: .info)
//        Logger.common(message: "[STC] CheckedSegmentations: \(checkedSegmentations)", level: .info)
        Logger.common(message: "[STC] Segment: \(String(describing: segment))", level: .info)

        switch targeting.kind {
        case .positive:
            if segment != nil {
                Logger.common(message: "[STC] Позитив: найден, true ✅", level: .info)
                return true
            } else {
                Logger.common(message: "[STC] Позитив: не найден, false ❌ ", level: .info)
                return false
            }
        case .negative:
            if segment == nil {
                Logger.common(message: "[STC] Негатив: не найден, true ✅", level: .info)
                return true
            } else {
                Logger.common(message: "[STC] Негатив: найден, false ❌ ", level: .info)
                return false
            }
        }
    }
}
