//
//  SDKVersionValidatorTests.swift
//  MindboxTests
//
//  Created by vailence on 15.06.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

class SDKVersionValidatorTests: XCTestCase {
    
    var validator: SDKVersionValidator!

    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        validator = nil
        super.tearDown()
    }
        
    func test_whenMinVersionIsTooHigh_returnsFalse() {
        let sdkVersion = InAppConfigResponse.SdkVersion(min: 10, max: nil)
        validator = SDKVersionValidator(sdkVersionNumeric: 6)
        XCTAssertFalse(validator.isValid(item: sdkVersion))
    }
    
    func testValidator_whenMaxVersionIsTooLow_returnsFalse() {
        let sdkVersion = InAppConfigResponse.SdkVersion(min: nil, max: 5)
        validator = SDKVersionValidator(sdkVersionNumeric: 6)
        XCTAssertFalse(validator.isValid(item: sdkVersion))
    }
    
    func testValidator_whenVersionIsWithinBounds_returnsTrue() {
        let sdkVersion = InAppConfigResponse.SdkVersion(min: 5, max: 7)
        validator = SDKVersionValidator(sdkVersionNumeric: 6)
        XCTAssertTrue(validator.isValid(item: sdkVersion))
    }
    
    func testValidator_whenMinAndMaxAreNil_returnsTrue() {
        let sdkVersion = InAppConfigResponse.SdkVersion(min: nil, max: nil)
        validator = SDKVersionValidator(sdkVersionNumeric: 6)
        XCTAssertFalse(validator.isValid(item: sdkVersion))
    }
    
    func testValidator_whenVersionIsNull_returnsFalse() {
        validator = SDKVersionValidator(sdkVersionNumeric: 6)
        XCTAssertFalse(validator.isValid(item: nil))
    }
}
