//
//  GeoTargetingChecker.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 19.01.2023.
//

import Foundation

final class GeoTargetingChecker: InternalTargetingChecker<GeoTargeting> {
    weak var checker: TargetingCheckerContextProtocol?
    
    override func prepareInternal(targeting: GeoTargeting, context: inout PreparationContext) -> Void {
        context.isNeedGeoRequest = true
    }
    
    override func checkInternal(targeting: GeoTargeting) -> Bool {
        guard let checker = checker else {
            assertionFailure("Need to init checker")
            return false
        }
        
        let geoModel = checker.geoModels
        let segment = targeting.ids.first(where: {
            $0 == geoModel?.country || $0 == geoModel?.region || $0 == geoModel?.city
        })
        
        switch targeting.kind {
        case .positive:
            return segment != nil
        case .negative:
            return segment == nil
        }
    }
}
