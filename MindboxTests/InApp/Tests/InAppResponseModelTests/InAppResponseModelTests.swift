//
//  InAppResponseModelTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 19.01.2023.
//  Copyright © 2023 Mikhail Barilov. All rights reserved.
//

import Testing
@testable import Mindbox

fileprivate enum TrueTargetingConfig: String, Configurable {
    typealias DecodeType = TrueTargeting

    case valid = "TrueTargetingModelValid"
}

fileprivate enum AndTargetingConfig: String, Configurable {
    typealias DecodeType = AndTargeting

    case valid = "AndTargetingModelValid"
    case fromTrueTargeting = "TrueTargetingModelValid"
}

fileprivate enum OrTargetingConfig: String, Configurable {
    typealias DecodeType = OrTargeting

    case valid = "OrTargetingModelValid"
    case fromTrueTargeting = "TrueTargetingModelValid"
}

fileprivate enum SegmentTargetingConfig: String, Configurable {
    typealias DecodeType = SegmentTargeting

    case valid = "SegmentTargetingModelValid"
    case fromOrTargeting = "OrTargetingModelValid"
}

fileprivate enum CityTargetingConfig: String, Configurable {
    typealias DecodeType = CityTargeting

    case valid = "GeoTargetingModelValid"
    case fromSegmentTargeting = "SegmentTargetingModelValid"
}

fileprivate enum VisitTargetingConfig: String, Configurable {
    typealias DecodeType = VisitTargeting

    case valid = "VisitTargetingModelValid"
    case negativeValue = "VisitTargetingNegativeValueModel"
    case fromSegmentTargeting = "SegmentTargetingModelValid"
}

fileprivate enum TargetingConfig: String, Configurable {
    typealias DecodeType = Targeting

    case allTargetingsValid = "AllTargetingsModelValid"
    case unknown = "UnknownTargetingsModel"
}

@Suite("InApp Response Model Tests")
struct InAppResponseModelTests {

    @Test("TrueTargeting decodes from valid JSON")
    func trueTargeting_valid() throws {
        try TrueTargetingConfig.valid.getConfig()
    }

    @Test("AndTargeting fails to decode from TrueTargeting JSON")
    func andTargeting_invalid() {
        #expect(throws: (any Error).self) {
            try AndTargetingConfig.fromTrueTargeting.getConfig()
        }
    }

    @Test("AndTargeting decodes from valid JSON")
    func andTargeting_valid() throws {
        let config = try AndTargetingConfig.valid.getConfig()
        #expect(!config.nodes.isEmpty)
        #expect(config.nodes.count == 1)
    }

    @Test("OrTargeting fails to decode from TrueTargeting JSON")
    func orTargeting_invalid() {
        #expect(throws: (any Error).self) {
            try OrTargetingConfig.fromTrueTargeting.getConfig()
        }
    }

    @Test("OrTargeting decodes from valid JSON")
    func orTargeting_valid() throws {
        let config = try OrTargetingConfig.valid.getConfig()
        #expect(!config.nodes.isEmpty)
        #expect(config.nodes.count == 1)
    }

    @Test("SegmentTargeting fails to decode from OrTargeting JSON")
    func segmentTargeting_invalid() {
        #expect(throws: (any Error).self) {
            try SegmentTargetingConfig.fromOrTargeting.getConfig()
        }
    }

    @Test("SegmentTargeting decodes from valid JSON")
    func segmentTargeting_valid() throws {
        let config = try SegmentTargetingConfig.valid.getConfig()
        #expect(config.kind == .positive)
        #expect(config.segmentationExternalId == "00000000-0000-0000-0000-000000000001")
        #expect(config.segmentationInternalId == "00000000-0000-0000-0000-000000000002")
        #expect(config.segmentExternalId == "00000000-0000-0000-0000-000000000003")
    }

    @Test("CityTargeting fails to decode from SegmentTargeting JSON")
    func cityTargeting_invalid() {
        #expect(throws: (any Error).self) {
            try CityTargetingConfig.fromSegmentTargeting.getConfig()
        }
    }

    @Test("CityTargeting decodes from valid JSON")
    func cityTargeting_valid() throws {
        let config = try CityTargetingConfig.valid.getConfig()
        #expect(config.kind == .negative)
        #expect(!config.ids.isEmpty)
        #expect(config.ids.count == 3)
        #expect(config.ids[0] == 1)
    }

    @Test("VisitTargeting decodes from valid JSON")
    func visitTargeting_valid() throws {
        let config = try VisitTargetingConfig.valid.getConfig()
        #expect(config.kind == .equals)
        #expect(config.value == 1)
    }

    @Test("VisitTargeting with negative value fails to decode")
    func visitTargeting_negativeValue_throws() {
        #expect(throws: (any Error).self) {
            try VisitTargetingConfig.negativeValue.getConfig()
        }
    }

    @Test("VisitTargeting fails to decode from SegmentTargeting JSON")
    func visitTargeting_invalid() {
        #expect(throws: (any Error).self) {
            try VisitTargetingConfig.fromSegmentTargeting.getConfig()
        }
    }

    @Test("Composite Targeting (And/Or/City) decodes correctly from AllTargetingsModelValid")
    func commonTargeting_valid() throws {
        let config = try TargetingConfig.allTargetingsValid.getConfig()

        switch config {
        case .and(let andTargeting):
            #expect(andTargeting.nodes.count == 1)
            let firstNode = andTargeting.nodes[0]

            switch firstNode {
            case .or(let orTargeting):
                #expect(orTargeting.nodes.count == 3)
                let thirdNode = orTargeting.nodes[2]

                switch thirdNode {
                case .city(let cityTargeting):
                    #expect(cityTargeting.kind == .negative)
                    #expect(cityTargeting.ids == [1, 2, 3])
                default:
                    Issue.record("Expected city targeting")
                    return
                }

            default:
                Issue.record("Expected or targeting")
                return
            }

        default:
            Issue.record("Expected and targeting")
            return
        }
    }

    @Test("Unknown targeting decodes to .unknown case")
    func unknown_targeting() throws {
        let config = try TargetingConfig.unknown.getConfig()

        switch config {
        case .unknown:
            break
        default:
            Issue.record("Expected unknown targeting")
            return
        }
    }
}
