//
//  GeoTargetingChecker.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 19.01.2023.
//

import Foundation

final class CityTargetingChecker: InternalTargetingChecker<CityTargeting> {
    weak var checker: TargetingCheckerContextProtocol?
    
    override func prepareInternal(targeting: CityTargeting, context: inout PreparationContext) -> Void {
        context.isNeedGeoRequest = true
    }
    
    override func checkInternal(targeting: CityTargeting) -> Bool {
        guard let checker = checker else {
            return false
        }
        
        let geoModel = checker.geoModels
        let segment = targeting.ids.first(where: {
            $0 == geoModel?.city
        })
        
        switch targeting.kind {
        case .positive:
            return segment != nil
        case .negative:
            return segment == nil
        }
    }
}

final class RegionTargetingChecker: InternalTargetingChecker<RegionTargeting> {
    weak var checker: TargetingCheckerContextProtocol?
    
    override func prepareInternal(targeting: RegionTargeting, context: inout PreparationContext) -> Void {
        context.isNeedGeoRequest = true
    }
    
    override func checkInternal(targeting: RegionTargeting) -> Bool {
        guard let checker = checker else {
            return false
        }
        
        let geoModel = checker.geoModels
        let segment = targeting.ids.first(where: {
            $0 == geoModel?.region
        })
        
        switch targeting.kind {
        case .positive:
            return segment != nil
        case .negative:
            return segment == nil
        }
    }
}

final class CountryTargetingChecker: InternalTargetingChecker<CountryTargeting> {
    weak var checker: TargetingCheckerContextProtocol?
    
    override func prepareInternal(targeting: CountryTargeting, context: inout PreparationContext) -> Void {
        context.isNeedGeoRequest = true
    }
    
    override func checkInternal(targeting: CountryTargeting) -> Bool {
        guard let checker = checker else {
            return false
        }
        
        let geoModel = checker.geoModels
        let segment = targeting.ids.first(where: {
            $0 == geoModel?.country
        })
        
        switch targeting.kind {
        case .positive:
            return segment != nil
        case .negative:
            return segment == nil
        }
    }
}

