//
//  ContentElementPositionMarginValidatorTests.swift
//  MindboxTests
//
//  Created by vailence on 07.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

final class ContentElementPositionMarginValidatorTests: XCTestCase {
    
    var validator: ContentElementPositionMarginValidator!
    var model: ContentElementPositionMargin!

    override func setUpWithError() throws {
        validator = ContentElementPositionMarginValidator()
    }

    override func tearDownWithError() throws {
        validator = nil
        model = nil
    }

    func test_unknownCase_returnFalse() throws {
        let model = ContentElementPositionMargin(kind: .unknown)
        XCTAssertFalse(validator.isValid(item: model))
    }
}
