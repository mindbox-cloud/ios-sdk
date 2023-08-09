//
//  ContentBackgroundLayerActionValidatorTests.swift
//  MindboxTests
//
//  Created by vailence on 07.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

final class ContentBackgroundLayerActionValidatorTests: XCTestCase {
    
    var validator: ContentBackgroundLayerActionValidator!
    var model: ContentBackgroundLayerAction!

    override func setUpWithError() throws {
        validator = ContentBackgroundLayerActionValidator()
    }

    override func tearDownWithError() throws {
        validator = nil
        model = nil
    }

    func test_valid_returnTrue() throws {
        let model = ContentBackgroundLayerAction(type: .redirectUrl, intentPayload: "payload", value: "value")
        XCTAssertTrue(validator.isValid(item: model))
    }
    
    func test_url_noValue_returnFalse() throws {
        let model = ContentBackgroundLayerAction(type: .redirectUrl, intentPayload: "payload")
        XCTAssertFalse(validator.isValid(item: model))
    }
    
    func test_url_noPayload_returnFalse() throws {
        let model = ContentBackgroundLayerAction(type: .redirectUrl, value: "value")
        XCTAssertFalse(validator.isValid(item: model))
    }
    
    func test_unknownCase_returnFalse() throws {
        let model = ContentBackgroundLayerAction(type: .unknown, intentPayload: "payload", value: "value")
        XCTAssertFalse(validator.isValid(item: model))
    }

    func testPerformanceExample() throws {
        let model = ContentBackgroundLayerAction(type: .redirectUrl, intentPayload: "payload", value: "value")
        self.measure {
            for _ in 0..<10000 {
                _ = validator.isValid(item: model)
            }
        }
    }
}
