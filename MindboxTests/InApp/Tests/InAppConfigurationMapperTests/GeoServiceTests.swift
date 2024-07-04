//
//  GeoServiceTests.swift
//  MindboxTests
//
//  Created by vailence on 13.06.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

final class GeoServiceTests: XCTestCase {
    
    var sut: GeoServiceProtocol!
    var networkFetcher: MockNetworkFetcher!
    var targetingChecker: InAppTargetingCheckerProtocol!
    var container: TestDependencyProvider!
    
    override func setUp() {
        super.setUp()
        container = try! TestDependencyProvider()
        networkFetcher = DI.injectOrFail(NetworkFetcher.self) as? MockNetworkFetcher
        targetingChecker = DI.injectOrFail(InAppTargetingCheckerProtocol.self)
        sut = DI.injectOrFail(GeoServiceProtocol.self)
    }
    
    override func tearDown() {
        sut = nil
        networkFetcher = nil
        targetingChecker = nil
        SessionTemporaryStorage.shared.erase()
        container = nil
        super.tearDown()
    }
    
    func test_geo_request_valid() throws {
        let model = InAppGeoResponse(city: 1, region: 2, country: 3)
        let responseData = try! JSONEncoder().encode(model)
        var result: InAppGeoResponse?
        networkFetcher.data = responseData
        
        let expectations = expectation(description: "test_geo_request")
        
        sut.geoRequest { response in
            result = response
            expectations.fulfill()
        }
        
        waitForExpectations(timeout: 1)
        
        XCTAssertEqual(result, model)
    }
    
    func test_geo_request_geoRequestCompleted() throws {
        let model = InAppGeoResponse(city: 1, region: 2, country: 3)
        let responseData = try! JSONEncoder().encode(model)
        var result: InAppGeoResponse?
        networkFetcher.data = responseData
        SessionTemporaryStorage.shared.geoRequestCompleted = true
        
        let expectations = expectation(description: "test_geo_request")
        
        sut.geoRequest { response in
            result = response
            expectations.fulfill()
        }
        
        waitForExpectations(timeout: 1)
        
        XCTAssertNil(result)
    }
}
