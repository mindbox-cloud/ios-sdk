//
//  ContentBackgroundLayerSourceValidatorTests.swift
//  MindboxTests
//
//  Created by vailence on 07.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

final class ContentBackgroundLayerSourceValidatorTests: XCTestCase {
    
    var validator: ContentBackgroundLayerSourceValidator!
    var model: ContentBackgroundLayerSource!

    override func setUpWithError() throws {
        validator = ContentBackgroundLayerSourceValidator()
    }

    override func tearDownWithError() throws {
        validator = nil
        model = nil
    }

    func test_valid_returnTrue() throws {
        let model = ContentBackgroundLayerSource(type: .url, value: "someValue")
        XCTAssertTrue(validator.isValid(item: model))
    }
    
    func test_url_noValue_returnFalse() throws {
        let model = ContentBackgroundLayerSource(type: .url)
        XCTAssertFalse(validator.isValid(item: model))
    }
    
    func test_unknownCase_returnFalse() throws {
        let model = ContentBackgroundLayerSource(type: .unknown, value: "someValue")
        XCTAssertFalse(validator.isValid(item: model))
    }

    func testPerformanceExample() throws {
        let model = ContentBackgroundLayerSource(type: .url, value: "someValue")
        self.measure {
            for _ in 0..<10000 {
                _ = validator.isValid(item: model)
            }
        }
    }
}
