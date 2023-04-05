//
//  InternalTargetingChecker.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 17.01.2023.
//

import Foundation
import MindboxLogger

protocol TargetingCheckerContextProtocol: AnyObject {
    var context: PreparationContext { get set }
    var checkedSegmentations: [SegmentationCheckResponse.CustomerSegmentation]? { get set }
    var geoModels: InAppGeoResponse? { get set }
    var event: ApplicationEvent? { get set }
}

protocol TargetingCheckerMap: AnyObject {
    var checkerMap: [Targeting: (Targeting) -> CheckerFunctions] { get set }
}

protocol TargetingCheckerActionProtocol: AnyObject {
    func prepare(targeting: Targeting)
    func check(targeting: Targeting) -> Bool
}

class CheckerFunctions {
    var prepare: (inout PreparationContext) -> Void = { _ in }
    var check: () -> Bool = { false }

    init(prepare: @escaping (inout PreparationContext) -> Void, check: @escaping () -> Bool) {
        self.prepare = prepare
        self.check = check
    }

    init() {}
}

protocol InAppTargetingCheckerProtocol: TargetingCheckerContextProtocol, TargetingCheckerActionProtocol, TargetingCheckerMap { }

final class InAppTargetingChecker: InAppTargetingCheckerProtocol {
    
    init() {
        setupCheckerMap()
    }
    
    var context = PreparationContext()
    var checkedSegmentations: [SegmentationCheckResponse.CustomerSegmentation]? = nil
    var geoModels: InAppGeoResponse?
    var event: ApplicationEvent?
    
    var checkerMap: [Targeting: (Targeting) -> CheckerFunctions] = [:]
    
    func prepare(targeting: Targeting) {
        guard let target = checkerMap[targeting] else {
            Logger.common(message: "target not exist in checkerMap. Targeting: \(targeting)", level: .error, category: .inAppMessages)
            return
        }
        
        target(targeting).prepare(&context)
    }
    
    func check(targeting: Targeting) -> Bool {
        guard let target = checkerMap[targeting] else {
            Logger.common(message: "target not exist in checkerMap. Targeting: \(targeting)", level: .error, category: .inAppMessages)
            return false
        }
        
        return target(targeting).check()
    }

    private func setupCheckerMap() {
        let checkerFunctions = CheckerFunctions()
        checkerMap[.unknown] = { _ in
            return checkerFunctions
        }

        let trueTargeting = TrueTargeting()
        let trueTargetingFactory = TrueTargetingFactory()
        checkerMap[.true(trueTargeting)] = trueTargetingFactory.makeChecker(for:)

        let andTargeting = AndTargeting(nodes: [])
        let andFactory = AndTargetingFactory(checker: self)
        checkerMap[.and(andTargeting)] = andFactory.makeChecker(for:)

        let orTargeting = OrTargeting(nodes: [])
        let orFactory = OrTargetingFactory(checker: self)
        checkerMap[.or(orTargeting)] = orFactory.makeChecker(for:)

        let segmentTargeting = SegmentTargeting(kind: .negative,
                                                segmentationInternalId: "",
                                                segmentationExternalId: "",
                                                segmentExternalId: "")
        let segmentTargetingFactory = SegmentTargetingFactory(checker: self)
        checkerMap[.segment(segmentTargeting)] = segmentTargetingFactory.makeChecker(for:)

        let cityTargeting = CityTargeting(kind: .negative, ids: [])
        let cityTargetingFactory = CityTargetingFactory(checker: self)
        checkerMap[.city(cityTargeting)] = cityTargetingFactory.makeChecker(for:)

        let regionTargeting = RegionTargeting(kind: .negative, ids: [])
        let regionTargetingFactory = RegionTargetingFactory(checker: self)
        checkerMap[.region(regionTargeting)] = regionTargetingFactory.makeChecker(for:)

        let countryTargeting = CountryTargeting(kind: .negative, ids: [])
        let countryTargetingFactory = CountryTargetingFactory(checker: self)
        checkerMap[.country(countryTargeting)] = countryTargetingFactory.makeChecker(for:)

        let customOperationTargeting = CustomOperationTargeting(systemName: "")
        let customOperationTargetingFactory = CustomOperationTargetingFactory(checker: self)
        checkerMap[.apiMethodCall(customOperationTargeting)] = customOperationTargetingFactory.makeChecker(for:)

        let categoryIDTargeting = CategoryIDTargeting(kind: .substring, value: "")
        let categoryIDTargetingFactory = CategoryIDTargetingFactory(checker: self)
        checkerMap[.viewProductCategoryId(categoryIDTargeting)] = categoryIDTargetingFactory.makeChecker(for:)

        let categoryIDInTargeting = CategoryIDInTargeting(kind: .any, values: [])
        let categoryIDInTargetingFactory = CategoryIDInTargetingFactory(checker: self)
        checkerMap[.viewProductCategoryIdIn(categoryIDInTargeting)] = categoryIDInTargetingFactory.makeChecker(for:)

        let productIDTargeting = ProductIDTargeting(kind: .substring, value: "")
        let productIDTargetingFactory = ProductCategoryIDTargetingFactory(checker: self)
        checkerMap[.viewProductId(productIDTargeting)] = productIDTargetingFactory.makeChecker(for:)
    }
}
