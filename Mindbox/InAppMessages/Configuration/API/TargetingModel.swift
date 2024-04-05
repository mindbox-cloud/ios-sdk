//
//  TargetingModel.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 17.01.2023.
//

import Foundation

protocol ITargeting { }

enum TargetingNegationConditionKindType: String, Decodable {
    case negative
    case positive
}

enum InAppTargetingType: String, Decodable {
    case `true`
    case and
    case or
    case segment
    case country
    case region
    case city
    case apiMethodCall
    case viewProductCategoryId
    case viewProductCategoryIdIn
    case viewProductId
    case viewProductSegment
    case visit
    case pushEnabled
    case unknown
    
    init(from decoder: Decoder) throws {
        let container: SingleValueDecodingContainer = try decoder.singleValueContainer()
        let type: String = try container.decode(String.self)
        self = InAppTargetingType(rawValue: type) ?? .unknown
    }
}

enum Targeting: Decodable, Hashable, Equatable {
    case `true`(TrueTargeting)
    case and(AndTargeting)
    case or(OrTargeting)
    case segment(SegmentTargeting)
    case city(CityTargeting)
    case region(RegionTargeting)
    case country(CountryTargeting)
    case apiMethodCall(CustomOperationTargeting)
    case viewProductCategoryId(CategoryIDTargeting)
    case viewProductCategoryIdIn(CategoryIDInTargeting)
    case viewProductId(ProductIDTargeting)
    case viewProductSegment(ProductSegmentTargeting)
    case visit(VisitTargeting)
    case pushEnabled(PushEnabledTargeting)
    case unknown
    
    enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    static func == (lhs: Targeting, rhs: Targeting) -> Bool {
        switch (lhs, rhs) {
            case (.true, .true): return true
            case (.and, .and): return true
            case (.or, .or): return true
            case (.segment, .segment): return true
            case (.city, .city): return true
            case (.region, .region): return true
            case (.country, .country): return true
            case (.apiMethodCall, .apiMethodCall): return true
            case (.viewProductCategoryId, .viewProductCategoryId): return true
            case (.viewProductCategoryIdIn, .viewProductCategoryIdIn): return true
            case (.viewProductId, .viewProductId): return true
            case (.viewProductSegment, .viewProductSegment): return true
            case (.visit, .visit): return true
            case (.pushEnabled, .pushEnabled): return true
            case (.unknown, .unknown): return true
            default: return false
        }
    }
    
    func hash(into hasher: inout Hasher) {
        switch self {
            case .true: hasher.combine("true")
            case .and: hasher.combine("and")
            case .or: hasher.combine("or")
            case .segment: hasher.combine("segment")
            case .city: hasher.combine("city")
            case .region: hasher.combine("region")
            case .country: hasher.combine("country")
            case .apiMethodCall: hasher.combine("apiMethodCall")
            case .viewProductCategoryId: hasher.combine("viewProductCategoryId")
            case .viewProductCategoryIdIn: hasher.combine("viewProductCategoryIdIn")
            case .viewProductId: hasher.combine("viewProductId")
            case .viewProductSegment: hasher.combine("viewProductSegment")
            case .visit: hasher.combine("visit")
            case .pushEnabled: hasher.combine("pushEnabled")
            case .unknown: hasher.combine("unknown")
        }
    }
    
    init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<Targeting.CodingKeys> = try decoder.container(
            keyedBy: CodingKeys.self)
        guard let type = try? container.decode(InAppTargetingType.self, forKey: .type) else {
            self = .unknown
            return
        }
        
        let targetingContainer: SingleValueDecodingContainer = try decoder.singleValueContainer()
        
        switch type {
            case .true:
                let trueTargeting = try targetingContainer.decode(TrueTargeting.self)
                self = .true(trueTargeting)
            case .and:
                let andTargeting = try targetingContainer.decode(AndTargeting.self)
                self = .and(andTargeting)
            case .or:
                let orTargeting = try targetingContainer.decode(OrTargeting.self)
                self = .or(orTargeting)
            case .segment:
                let segmentTargeting = try targetingContainer.decode(SegmentTargeting.self)
                self = .segment(segmentTargeting)
            case .city:
                let cityTargeting = try targetingContainer.decode(CityTargeting.self)
                self = .city(cityTargeting)
            case .region:
                let regionTargeting = try targetingContainer.decode(RegionTargeting.self)
                self = .region(regionTargeting)
            case .country:
                let countryTargeting = try targetingContainer.decode(CountryTargeting.self)
                self = .country(countryTargeting)
            case .apiMethodCall:
                let customOperationTargeting = try targetingContainer.decode(CustomOperationTargeting.self)
                self = .apiMethodCall(customOperationTargeting)
            case .viewProductCategoryId:
                let categoryIDTargeting = try targetingContainer.decode(CategoryIDTargeting.self)
                self = .viewProductCategoryId(categoryIDTargeting)
            case .viewProductCategoryIdIn:
                let categoryIDInTargeting = try targetingContainer.decode(CategoryIDInTargeting.self)
                self = .viewProductCategoryIdIn(categoryIDInTargeting)
            case .viewProductId:
                let productIDTargeting = try targetingContainer.decode(ProductIDTargeting.self)
                self = .viewProductId(productIDTargeting)
            case .viewProductSegment:
                let productSegmentTargeting = try targetingContainer.decode(ProductSegmentTargeting.self)
                self = .viewProductSegment(productSegmentTargeting)
            case .visit:
                let visitTargeting = try targetingContainer.decode(VisitTargeting.self)
                self = .visit(visitTargeting)
            case .pushEnabled:
                let pushEnabledTargeting = try targetingContainer.decode(PushEnabledTargeting.self)
                self = .pushEnabled(pushEnabledTargeting)
            case .unknown:
                self = .unknown
        }
    }
}
