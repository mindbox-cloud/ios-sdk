//
//  ValidatorsTestCase.swift
//  MindboxTests
//
//  Created by Maksim Kazachkov on 02.02.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

class ValidatorsTestCase: XCTestCase {

    func testUDIDValidator() {
        XCTAssertFalse(UDIDValidator(udid: "00000000-0000-0000-0000-000000000000").evaluate())
        XCTAssertFalse(UDIDValidator(udid: "00000000-0000-0000-0000").evaluate())
        XCTAssertTrue(UDIDValidator(udid: "00000000-0000-0000-0000-000000000001").evaluate())
        (0...100)
            .map { _ in UUID().uuidString }
            .forEach { XCTAssertTrue(UDIDValidator(udid: $0).evaluate()) }
    }
}
