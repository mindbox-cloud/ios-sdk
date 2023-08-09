//
//  InappFormVariantValidatorTests.swift
//  MindboxTests
//
//  Created by vailence on 07.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

final class InappFormVariantValidatorTests: XCTestCase {
    
    var validator: InappFormVariantValidator!
    var model: InappFormVariant!

    override func setUpWithError() throws {
        validator = InappFormVariantValidator()
    }

    override func tearDownWithError() throws {
        validator = nil
        model = nil
    }

    func test_unknownCase_returnFalse() throws {
        let model = InappFormVariant(type: .unknown)
        XCTAssertFalse(validator.isValid(item: model))
    }
    
    func test_modal_noContent_returnFalse() throws {
        let model =  InappFormVariant(type: .modal)
        XCTAssertFalse(validator.isValid(item: model))
    }
    
    func test_snackbar_noContent_returnTrue() throws {
        let model = InappFormVariant(type: .snackbar)
        XCTAssertTrue(validator.isValid(item: model))
    }
}
