//
//  InAppTargetingcheckerTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 19.01.2023.
//  Copyright © 2023 Mikhail Barilov. All rights reserved.
//

import XCTest
@testable import Mindbox

final class InAppTargetingCheckerTests: XCTestCase {
    
    var container: TestDependencyProvider!
    let inAppStub = InAppStub()
    let trueTargeting: Targeting = .true(TrueTargeting())
    var targetingChecker: InAppTargetingChecker!
    var storage: PersistenceStorage!
    
    override func setUp() {
        super.setUp()
        container = try! TestDependencyProvider()
        storage = DI.injectOrFail(PersistenceStorage.self)
        targetingChecker = container.inAppTargetingChecker
        targetingChecker.geoModels = InAppGeoResponse(city: 123, region: 456, country: 789)
    }
    
    override func tearDown() {
        targetingChecker = nil
        storage = nil
        container = nil
        super.tearDown()
    }
    
    // MARK: - TRUE
    func test_true_always_true() {
        XCTAssertTrue(targetingChecker.check(targeting: inAppStub.getTargetingTrueNode()))
    }
    
    // MARK: - CITY
    func test_city_targetging_positive_success() {
        let cityModel = CityTargeting(kind: .positive, ids: [123, 456])
        XCTAssertTrue(targetingChecker.check(targeting: inAppStub.getTargetingCity(model: cityModel)))
    }
    
    func test_city_targetging_positive_error() {
        let cityModel = CityTargeting(kind: .positive, ids: [788])
        XCTAssertFalse(targetingChecker.check(targeting: inAppStub.getTargetingCity(model: cityModel)))
    }
    
    func test_city_targetging_negative_success() {
        let cityModel = CityTargeting(kind: .negative, ids: [788])
        XCTAssertTrue(targetingChecker.check(targeting: inAppStub.getTargetingCity(model: cityModel)))
    }
    
    func test_city_targetging_negative_error() {
        let cityModel = CityTargeting(kind: .negative, ids: [123, 456])
        XCTAssertFalse(targetingChecker.check(targeting: inAppStub.getTargetingCity(model: cityModel)))
    }
    
    // MARK: - REGION
    func test_region_targetging_positive_success() {
        let regionModel = RegionTargeting(kind: .positive, ids: [789, 456])
        XCTAssertTrue(targetingChecker.check(targeting: inAppStub.getTargetingRegion(model: regionModel)))
    }
    
    func test_region_targetging_positive_error() {
        let regionModel = RegionTargeting(kind: .positive, ids: [788])
        XCTAssertFalse(targetingChecker.check(targeting: inAppStub.getTargetingRegion(model: regionModel)))
    }
    
    func test_region_targetging_negative_success() {
        let regionModel = RegionTargeting(kind: .negative, ids: [788])
        XCTAssertTrue(targetingChecker.check(targeting: inAppStub.getTargetingRegion(model: regionModel)))
    }
    
    func test_region_targetging_negative_error() {
        let regionModel = RegionTargeting(kind: .negative, ids: [789, 456])
        XCTAssertFalse(targetingChecker.check(targeting: inAppStub.getTargetingRegion(model: regionModel)))
    }
    
    // MARK: - COUNTRY
    func test_country_targetging_positive_success() {
        let countryModel = CountryTargeting(kind: .positive, ids: [789, 456])
        XCTAssertTrue(targetingChecker.check(targeting: inAppStub.getTargetingCountry(model: countryModel)))
    }
    
    func test_country_targetging_positive_error() {
        let countryModel = CountryTargeting(kind: .positive, ids: [788])
        XCTAssertFalse(targetingChecker.check(targeting: inAppStub.getTargetingCountry(model: countryModel)))
    }
    
    func test_country_targetging_negative_success() {
        let countryModel = CountryTargeting(kind: .negative, ids: [788])
        XCTAssertTrue(targetingChecker.check(targeting: inAppStub.getTargetingCountry(model: countryModel)))
    }
    
    func test_country_targetging_negative_error() {
        let countryModel = CountryTargeting(kind: .negative, ids: [789, 456])
        XCTAssertFalse(targetingChecker.check(targeting: inAppStub.getTargetingCountry(model: countryModel)))
    }
    
    // MARK: - SEGMENT
    func test_segment_targeting_positive_success() {
        let segmentModel = SegmentTargeting(kind: .positive,
                                            segmentationInternalId: "-",
                                            segmentationExternalId: "123",
                                            segmentExternalId: "234")
        targetingChecker.checkedSegmentations = []
        targetingChecker.checkedSegmentations?.append(inAppStub.getCheckedSegmentation(segmentationID: "123", segmentID: "234"))
        XCTAssertTrue(targetingChecker.check(targeting: inAppStub.getTargetingSegment(model: segmentModel)))
    }
    
    func test_segment_targeting_positive_error() {
        let segmentModel = SegmentTargeting(kind: .positive,
                                            segmentationInternalId: "-",
                                            segmentationExternalId: "123",
                                            segmentExternalId: "234")
        
        targetingChecker.checkedSegmentations?.append(inAppStub.getCheckedSegmentation(segmentationID: "123", segmentID: "233"))
        XCTAssertFalse(targetingChecker.check(targeting: inAppStub.getTargetingSegment(model: segmentModel)))
    }
    
    func test_segment_targeting_negative_success() {
        let segmentModel = SegmentTargeting(kind: .negative,
                                            segmentationInternalId: "-",
                                            segmentationExternalId: "123",
                                            segmentExternalId: "234")
        targetingChecker.checkedSegmentations = []
        targetingChecker.checkedSegmentations?.append(inAppStub.getCheckedSegmentation(segmentationID: "123", segmentID: nil))
        XCTAssertTrue(targetingChecker.check(targeting: inAppStub.getTargetingSegment(model: segmentModel)))
    }
    
    func test_segment_targeting_negative_error() {
        let segmentModel = SegmentTargeting(kind: .negative,
                                            segmentationInternalId: "-",
                                            segmentationExternalId: "123",
                                            segmentExternalId: "234")
        
        targetingChecker.checkedSegmentations?.append(inAppStub.getCheckedSegmentation(segmentationID: "123", segmentID: "234"))
        XCTAssertFalse(targetingChecker.check(targeting: inAppStub.getTargetingSegment(model: segmentModel)))
    }
    
    func test_AND_targeting_both_true() {
        let country = CountryTargeting(kind: .positive, ids: [789])
        let city = CityTargeting(kind: .positive, ids: [123])
        let andTargeting = AndTargeting(nodes: [.country(country), .city(city)])
        XCTAssertTrue(targetingChecker.check(targeting: inAppStub.getAnd(model: andTargeting)))
    }
    
    func test_AND_targeting_both_false() {
        let country = CountryTargeting(kind: .positive, ids: [234])
        let city = CityTargeting(kind: .positive, ids: [234])
        let andTargeting = AndTargeting(nodes: [.country(country), .city(city)])
        XCTAssertFalse(targetingChecker.check(targeting: inAppStub.getAnd(model: andTargeting)))
    }
    
    func test_AND_targeting_one_true_one_false() {
        let country = CountryTargeting(kind: .positive, ids: [234])
        let city = CityTargeting(kind: .positive, ids: [123])
        let andTargeting = AndTargeting(nodes: [.country(country), .city(city)])
        XCTAssertFalse(targetingChecker.check(targeting: inAppStub.getAnd(model: andTargeting)))
    }
    
    func test_OR_targeting_both_true() {
        let country = CountryTargeting(kind: .positive, ids: [456])
        let city = CityTargeting(kind: .positive, ids: [123])
        let andTargeting = OrTargeting(nodes: [.country(country), .city(city)])
        XCTAssertTrue(targetingChecker.check(targeting: inAppStub.getOr(model: andTargeting)))
    }
    
    func test_OR_targeting_both_false() {
        let country = CountryTargeting(kind: .positive, ids: [234])
        let city = CityTargeting(kind: .positive, ids: [234])
        let andTargeting = OrTargeting(nodes: [.country(country), .city(city)])
        XCTAssertFalse(targetingChecker.check(targeting: inAppStub.getOr(model: andTargeting)))
    }
    
    func test_OR_targeting_one_true_one_false() {
        let country = CountryTargeting(kind: .positive, ids: [234])
        let city = CityTargeting(kind: .positive, ids: [123])
        let andTargeting = OrTargeting(nodes: [.country(country), .city(city)])
        XCTAssertTrue(targetingChecker.check(targeting: inAppStub.getOr(model: andTargeting)))
    }
    
    func test_OR_contain_unknown() {
        let city = CityTargeting(kind: .positive, ids: [123])
        let orTargeting = OrTargeting(nodes: [.unknown, .city(city)])
        XCTAssertFalse(targetingChecker.check(targeting: inAppStub.getOr(model: orTargeting)))
    }
    
    func test_AND_contain_unknown() {
        let city = CityTargeting(kind: .positive, ids: [123])
        let andTargeting = AndTargeting(nodes: [.unknown, .city(city)])
        XCTAssertFalse(targetingChecker.check(targeting: inAppStub.getAnd(model: andTargeting)))
    }
    
    func test_unknown_false() {
        XCTAssertFalse(targetingChecker.check(targeting: .unknown))
    }
    
    // MARK: - VISIT
    func test_visit_gte_equal_true() {
        storage.userVisitCount = 1
        let visitTargeting = VisitTargeting(kind: .gte, value: 1)
        XCTAssertTrue(targetingChecker.check(targeting: .visit(visitTargeting)))
    }
    
    func test_visit_gte_greater_true() {
        storage.userVisitCount = 2
        let visitTargeting = VisitTargeting(kind: .gte, value: 1)
        XCTAssertTrue(targetingChecker.check(targeting: .visit(visitTargeting)))
    }
    
    func test_visit_gte_false() {
        storage.userVisitCount = 1
        let visitTargeting = VisitTargeting(kind: .gte, value: 2)
        XCTAssertFalse(targetingChecker.check(targeting: .visit(visitTargeting)))
    }
    
    func test_visit_lte_equal_true() {
        storage.userVisitCount = 1
        let visitTargeting = VisitTargeting(kind: .lte, value: 1)
        XCTAssertTrue(targetingChecker.check(targeting: .visit(visitTargeting)))
    }
    
    func test_visit_lte_less_true() {
        storage.userVisitCount = 1
        let visitTargeting = VisitTargeting(kind: .lte, value: 2)
        XCTAssertTrue(targetingChecker.check(targeting: .visit(visitTargeting)))
    }
    
    func test_visit_lte_false() {
        storage.userVisitCount = 2
        let visitTargeting = VisitTargeting(kind: .lte, value: 1)
        XCTAssertFalse(targetingChecker.check(targeting: .visit(visitTargeting)))
    }
    
    func test_visit_equal_true() {
        storage.userVisitCount = 1
        let visitTargeting = VisitTargeting(kind: .equals, value: 1)
        XCTAssertTrue(targetingChecker.check(targeting: .visit(visitTargeting)))
    }

    func test_visit_equal_false() {
        storage.userVisitCount = 2
        let visitTargeting = VisitTargeting(kind: .equals, value: 1)
        XCTAssertFalse(targetingChecker.check(targeting: .visit(visitTargeting)))
    }

    func test_visit_notEqual_true() {
        storage.userVisitCount = 1
        let visitTargeting = VisitTargeting(kind: .notEquals, value: 2)
        XCTAssertTrue(targetingChecker.check(targeting: .visit(visitTargeting)))
    }

    func test_visit_notEqual_false() {
        storage.userVisitCount = 1
        let visitTargeting = VisitTargeting(kind: .notEquals, value: 1)
        XCTAssertFalse(targetingChecker.check(targeting: .visit(visitTargeting)))
    }
}
