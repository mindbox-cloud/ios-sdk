//
//  ContentElementValidatorTests.swift
//  MindboxTests
//
//  Created by vailence on 07.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

final class ContentElementValidatorTests: XCTestCase {
    
    var validator: ContentElementValidator!
    var model: ContentElement!

    override func setUpWithError() throws {
        validator = ContentElementValidator()
    }

    override func tearDownWithError() throws {
        validator = nil
        model = nil
    }

    func test_unknownCase_returnFalse() throws {
        let model = ContentElement(type: .unknown)
        XCTAssertFalse(validator.isValid(item: model))
    }
}
