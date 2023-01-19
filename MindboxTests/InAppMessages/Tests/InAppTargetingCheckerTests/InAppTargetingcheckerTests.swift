//
//  InAppTargetingcheckerTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 19.01.2023.
//  Copyright © 2023 Mikhail Barilov. All rights reserved.
//

import XCTest
@testable import Mindbox

final class InAppTargetingcheckerTests: XCTestCase {
    
    let inAppStub = InAppStub()
    let trueTargeting: Targeting = .true(TrueTargeting())
    let targetingChecker: InAppTargetingCheckerProtocol = InAppTargetingChecker()

    override func setUpWithError() throws {
        targetingChecker.geoModels = InAppGeoResponse(city: 123, region: 456, country: 789)
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    // MARK: - TRUE
    func test_true_always_true() {
        XCTAssertTrue(targetingChecker.check(targeting: inAppStub.getTargetingTrueNode()))
    }
    
    // MARK: - GEO
    func test_geo_targeting_positive_success() {
        let geoModel = GeoTargeting(kind: .positive, ids: [789, 456])
        XCTAssertTrue(targetingChecker.check(targeting: inAppStub.getTargetingGeo(model: geoModel)))
    }
    
    func test_geo_targeting_positive_error() {
        let geoModel = GeoTargeting(kind: .positive, ids: [788])
        XCTAssertFalse(targetingChecker.check(targeting: inAppStub.getTargetingGeo(model: geoModel)))
    }
    
    func test_geo_targeting_negative_success() {
        let geoModel = GeoTargeting(kind: .negative, ids: [788])
        XCTAssertTrue(targetingChecker.check(targeting: inAppStub.getTargetingGeo(model: geoModel)))
    }
    
    func test_geo_targeting_negative_error() {
        let geoModel = GeoTargeting(kind: .negative, ids: [789, 456])
        XCTAssertFalse(targetingChecker.check(targeting: inAppStub.getTargetingGeo(model: geoModel)))
    }
    
    // MARK: - SEGMENT
    func test_segment_targeting_positive_success() {
        let segmentModel = SegmentTargeting(kind: .positive,
                                            segmentationInternalId: "-",
                                            segmentationExternalId: "123",
                                            segmentExternalId: "234")
        
        targetingChecker.checkedSegmentations.append(inAppStub.getCheckedSegmentation(segmentationID: "123", segmentID: "234"))
        XCTAssertTrue(targetingChecker.check(targeting: inAppStub.getTargetingSegment(model: segmentModel)))
    }
    
    func test_segment_targeting_positive_error() {
        let segmentModel = SegmentTargeting(kind: .positive,
                                            segmentationInternalId: "-",
                                            segmentationExternalId: "123",
                                            segmentExternalId: "234")
        
        targetingChecker.checkedSegmentations.append(inAppStub.getCheckedSegmentation(segmentationID: "123", segmentID: "233"))
        XCTAssertFalse(targetingChecker.check(targeting: inAppStub.getTargetingSegment(model: segmentModel)))
    }
    
    func test_segment_targeting_negative_success() {
        let segmentModel = SegmentTargeting(kind: .negative,
                                            segmentationInternalId: "-",
                                            segmentationExternalId: "123",
                                            segmentExternalId: "234")
        
        targetingChecker.checkedSegmentations.append(inAppStub.getCheckedSegmentation(segmentationID: "123", segmentID: nil))
        XCTAssertTrue(targetingChecker.check(targeting: inAppStub.getTargetingSegment(model: segmentModel)))
    }
    
    func test_segment_targeting_negative_error() {
        let segmentModel = SegmentTargeting(kind: .negative,
                                            segmentationInternalId: "-",
                                            segmentationExternalId: "123",
                                            segmentExternalId: "234")
        
        targetingChecker.checkedSegmentations.append(inAppStub.getCheckedSegmentation(segmentationID: "123", segmentID: "234"))
        XCTAssertFalse(targetingChecker.check(targeting: inAppStub.getTargetingSegment(model: segmentModel)))
    }
    
    func test_AND_targeting_both_true() {
        let country = GeoTargeting(kind: .positive, ids: [789])
        let city = GeoTargeting(kind: .positive, ids: [123])
        let andTargeting = AndTargeting(nodes: [.geo(country), .geo(city)])
        XCTAssertTrue(targetingChecker.check(targeting: inAppStub.getAnd(model: andTargeting)))
    }
    
    func test_AND_targeting_both_false() {
        let country = GeoTargeting(kind: .positive, ids: [234])
        let city = GeoTargeting(kind: .positive, ids: [234])
        let andTargeting = AndTargeting(nodes: [.geo(country), .geo(city)])
        XCTAssertFalse(targetingChecker.check(targeting: inAppStub.getAnd(model: andTargeting)))
    }
    
    func test_AND_targeting_one_true_one_false() {
        let country = GeoTargeting(kind: .positive, ids: [234])
        let city = GeoTargeting(kind: .positive, ids: [123])
        let andTargeting = AndTargeting(nodes: [.geo(country), .geo(city)])
        XCTAssertFalse(targetingChecker.check(targeting: inAppStub.getAnd(model: andTargeting)))
    }
    
    func test_OR_targeting_both_true() {
        let country = GeoTargeting(kind: .positive, ids: [456])
        let city = GeoTargeting(kind: .positive, ids: [123])
        let andTargeting = OrTargeting(nodes: [.geo(country), .geo(city)])
        XCTAssertTrue(targetingChecker.check(targeting: inAppStub.getOr(model: andTargeting)))
    }
    
    func test_OR_targeting_both_false() {
        let country = GeoTargeting(kind: .positive, ids: [234])
        let city = GeoTargeting(kind: .positive, ids: [234])
        let andTargeting = OrTargeting(nodes: [.geo(country), .geo(city)])
        XCTAssertFalse(targetingChecker.check(targeting: inAppStub.getOr(model: andTargeting)))
    }
    
    func test_OR_targeting_one_true_one_false() {
        let country = GeoTargeting(kind: .positive, ids: [234])
        let city = GeoTargeting(kind: .positive, ids: [123])
        let andTargeting = OrTargeting(nodes: [.geo(country), .geo(city)])
        XCTAssertTrue(targetingChecker.check(targeting: inAppStub.getOr(model: andTargeting)))
    }
}
