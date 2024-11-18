//
//  GeoTargetingChecker.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 19.01.2023.
//

import Foundation

final class CityTargetingChecker: InternalTargetingChecker<CityTargeting> {
    weak var checker: TargetingCheckerContextProtocol?

    override func prepareInternal(id: String, targeting: CityTargeting, context: inout PreparationContext) {
        context.isNeedGeoRequest = true
    }

    override func checkInternal(targeting: CityTargeting) -> Bool {
        guard let checker = checker else {
            return false
        }

        guard let geoModel = checker.geoModels else {
            return false
        }

        let segment = targeting.ids.first(where: {
            $0 == geoModel.city
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

    override func prepareInternal(id: String, targeting: RegionTargeting, context: inout PreparationContext) {
        context.isNeedGeoRequest = true
    }

    override func checkInternal(targeting: RegionTargeting) -> Bool {
        guard let checker = checker else {
            return false
        }

        guard let geoModel = checker.geoModels else {
            return false
        }

        let segment = targeting.ids.first(where: {
            $0 == geoModel.region
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

    override func prepareInternal(id: String, targeting: CountryTargeting, context: inout PreparationContext) {
        context.isNeedGeoRequest = true
    }

    override func checkInternal(targeting: CountryTargeting) -> Bool {
        guard let checker = checker else {
            return false
        }

        guard let geoModel = checker.geoModels else {
            return false
        }

        let segment = targeting.ids.first(where: {
            $0 == geoModel.country
        })

        switch targeting.kind {
        case .positive:
            return segment != nil
        case .negative:
            return segment == nil
        }
    }
}
