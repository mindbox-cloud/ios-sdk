//
//  InAppResponseModelTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 19.01.2023.
//  Copyright © 2023 Mikhail Barilov. All rights reserved.
//

import XCTest
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

final class InAppResponseModelTests: XCTestCase {

    func test_TrueTargeting_valid() throws {
        let config = try TrueTargetingConfig.valid.getConfig()
        XCTAssertNotNil(config)
    }

    func test_AndTargeting_invalid() {
        XCTAssertThrowsError(try AndTargetingConfig.fromTrueTargeting.getConfig())
    }

    func test_AndTargeting_valid() throws {
        let config = try AndTargetingConfig.valid.getConfig()
        XCTAssertFalse(config.nodes.isEmpty)
        XCTAssertEqual(config.nodes.count, 1)
    }

    func test_OrTargeting_invalid() {
        XCTAssertThrowsError(try OrTargetingConfig.fromTrueTargeting.getConfig())
    }

    func test_OrTargeting_valid() throws {
        let config = try OrTargetingConfig.valid.getConfig()
        XCTAssertFalse(config.nodes.isEmpty)
        XCTAssertEqual(config.nodes.count, 1)
    }

    func test_SegmentTargeting_invalid() {
        XCTAssertThrowsError(try SegmentTargetingConfig.fromOrTargeting.getConfig())
    }

    func test_SegmentTargeting_valid() throws {
        let config = try SegmentTargetingConfig.valid.getConfig()
        XCTAssertEqual(config.kind, .positive)
        XCTAssertEqual(config.segmentationExternalId, "00000000-0000-0000-0000-000000000001")
        XCTAssertEqual(config.segmentationInternalId, "00000000-0000-0000-0000-000000000002")
        XCTAssertEqual(config.segmentExternalId, "00000000-0000-0000-0000-000000000003")
    }

    func test_CityTargeting_invalid() {
        XCTAssertThrowsError(try CityTargetingConfig.fromSegmentTargeting.getConfig())
    }

    func test_CityTargeting_valid() throws {
        let config = try CityTargetingConfig.valid.getConfig()
        XCTAssertEqual(config.kind, .negative)
        XCTAssertFalse(config.ids.isEmpty)
        XCTAssertEqual(config.ids.count, 3)
        XCTAssertEqual(config.ids[0], 1)
    }

    func test_visit_targeting_valid() throws {
        let config = try VisitTargetingConfig.valid.getConfig()
        XCTAssertEqual(config.kind, .equals)
        XCTAssertEqual(config.value, 1)
    }

    func test_visit_targeting_negativeValue_throws() {
        XCTAssertThrowsError(try VisitTargetingConfig.negativeValue.getConfig())
    }

    func test_visit_targeting_invalid() {
        XCTAssertThrowsError(try VisitTargetingConfig.fromSegmentTargeting.getConfig())
    }

    func test_CommonTargeting_valid() throws {
        let config = try TargetingConfig.allTargetingsValid.getConfig()

        switch config {
        case .and(let andTargeting):
            XCTAssertEqual(andTargeting.nodes.count, 1)
            let firstNode = andTargeting.nodes[0]
            switch firstNode {
            case .or(let orTargeting):
                XCTAssertEqual(orTargeting.nodes.count, 3)
                let thirdNode = orTargeting.nodes[2]
                switch thirdNode {
                case .city(let cityTargeting):
                    XCTAssertEqual(cityTargeting.kind, .negative)
                    XCTAssertEqual(cityTargeting.ids, [1, 2, 3])
                default:
                    XCTFail("Expected city targeting")
                }
            default:
                XCTFail("Expected or targeting")
            }
        default:
            XCTFail("Expected and targeting")
        }
    }

    func test_unknown_targeting() throws {
        let config = try TargetingConfig.unknown.getConfig()

        switch config {
        case .unknown:
            break
        default:
            XCTFail("Expected unknown targeting")
        }
    }
}
