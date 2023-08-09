//
//  ContentBackgroundLayerTests.swift
//  MindboxTests
//
//  Created by vailence on 07.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

final class ContentBackgroundLayerTests: XCTestCase {
    
    var validator: ContentBackgroundLayerValidator!
    var model: ContentBackgroundLayer!

    override func setUpWithError() throws {
        validator = ContentBackgroundLayerValidator()
    }

    override func tearDownWithError() throws {
        validator = nil
        model = nil
    }

    func test_valid_returnTrue() throws {
        let actionModel = ContentBackgroundLayerAction(type: .redirectUrl, intentPayload: "payload", value: "value")
        let sourceModel = ContentBackgroundLayerSource(type: .url, value: "someValue")
        let model = ContentBackgroundLayer(type: .image, action: actionModel, source: sourceModel)
        XCTAssertTrue(validator.isValid(item: model))
    }

    func test_image_noAction_returnFalse() throws {
        let sourceModel = ContentBackgroundLayerSource(type: .url, value: "someValue")
        let model = ContentBackgroundLayer(type: .image, source: sourceModel)
        XCTAssertFalse(validator.isValid(item: model))
    }

    func test_image_noSource_returnFalse() throws {
        let actionModel = ContentBackgroundLayerAction(type: .redirectUrl, intentPayload: "payload", value: "value")
        let model = ContentBackgroundLayer(type: .image, action: actionModel)
        XCTAssertFalse(validator.isValid(item: model))
    }

    func test_unknownCase_returnFalse() throws {
        let model = ContentBackgroundLayer(type: .unknown)
        XCTAssertFalse(validator.isValid(item: model))
    }
}
