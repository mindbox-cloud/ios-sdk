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
        validator = DI.injectOrFail(SDKVersionValidator.self)
        validator.sdkVersionNumeric = 6
    }

    override func tearDown() {
        validator = nil
        super.tearDown()
    }

    func test_whenMinVersionIsTooHigh_returnsFalse() {
        let sdkVersion = SdkVersion(min: 10, max: nil)
        XCTAssertFalse(validator.isValid(item: sdkVersion))
    }

    func testValidator_whenMaxVersionIsTooLow_returnsFalse() {
        let sdkVersion = SdkVersion(min: nil, max: 5)
        XCTAssertFalse(validator.isValid(item: sdkVersion))
    }

    func testValidator_whenVersionIsWithinBounds_returnsTrue() {
        let sdkVersion = SdkVersion(min: 5, max: 7)
        XCTAssertTrue(validator.isValid(item: sdkVersion))
    }

    func testValidator_whenMinAndMaxAreNil_returnsTrue() {
        let sdkVersion = SdkVersion(min: nil, max: nil)
        XCTAssertFalse(validator.isValid(item: sdkVersion))
    }

    func testValidator_whenVersionIsNull_returnsFalse() {
        XCTAssertFalse(validator.isValid(item: nil))
    }
}
