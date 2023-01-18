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
    case unknown
    
    init(from decoder: Decoder) throws {
        let container: SingleValueDecodingContainer = try decoder.singleValueContainer()
        let type: String = try container.decode(String.self)
        self = InAppTargetingType(rawValue: type) ?? .unknown
    }
}

enum Targeting: Decodable, Hashable {
    case `true`(TrueTargeting)
    case and(AndTargeting)
    case or(OrTargeting)
    case segment(SegmentTargeting)
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
        default: return false
        }
    }
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .true: hasher.combine("true")
        case .and: hasher.combine("and")
        case .or: hasher.combine("or")
        case .segment: hasher.combine("segment")
        default: preconditionFailure("Out of range.")
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
            let trueTargeting: TrueTargeting = try targetingContainer.decode(TrueTargeting.self)
            self = .true(trueTargeting)
        case .and:
            let andTargeting: AndTargeting = try targetingContainer.decode(AndTargeting.self)
            self = .and(andTargeting)
        case .or:
            let orTargeting: OrTargeting = try targetingContainer.decode(OrTargeting.self)
            self = .or(orTargeting)
        case .segment:
            let segmentTargeting: SegmentTargeting = try targetingContainer.decode(SegmentTargeting.self)
            self = .segment(segmentTargeting)
        case .unknown:
            self = .unknown
        }
    }
}

