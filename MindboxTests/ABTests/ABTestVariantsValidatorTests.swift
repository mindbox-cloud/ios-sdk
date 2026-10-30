//
//  ABTestVariantsValidatorTests.swift
//  MindboxTests
//
//  Created by vailence on 15.06.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

class ABTestVariantsValidatorTests: XCTestCase {
    var variantValidator: ABTestVariantsValidator!

    struct TestCase {
        let variant: ABTest.ABTestVariant?
        let isValid: Bool
    }

    var testCases: [TestCase] = []

    override func setUp() {
        super.setUp()
        variantValidator = DI.injectOrFail(ABTestVariantsValidator.self)

        let object1 = ABTest.ABTestVariant.ABTestObject(type: .inapps, kind: .all, inapps: ["inapp1"])
        let object2 = ABTest.ABTestVariant.ABTestObject(type: .inapps, kind: .all, inapps: ["inapp2"])
        testCases = [
            TestCase(variant: createVariant(objects: [object1]), isValid: true),
            TestCase(variant: createVariant(id: "", objects: [object1]), isValid: false),
            TestCase(variant: createVariant(lower: 101, objects: [object1]), isValid: false),
            TestCase(variant: createVariant(upper: -1, objects: [object1]), isValid: false),
            TestCase(variant: createVariant(lower: 50, upper: 50), isValid: false),
            TestCase(variant: createVariant(lower: 100, upper: 0, objects: [object1]), isValid: false),
            TestCase(variant: createVariant(objects: []), isValid: false),
            TestCase(variant: createVariant(objects: [object1, object2]), isValid: false),
            TestCase(variant: nil, isValid: false)
        ]
    }

    override func tearDown() {
        variantValidator = nil
        testCases = []
        super.tearDown()
    }

    func testVariantIsValid() {
        for testCase in testCases {
            let result = variantValidator.isValid(item: testCase.variant)
            XCTAssertEqual(result, testCase.isValid, "Expected \(testCase.isValid) for variant \(String(describing: testCase.variant)), but got \(result)")
        }
    }

    private func createVariant(id: String = "Test",
                               lower: Int = 0,
                               upper: Int = 100,
                               objects: [ABTest.ABTestVariant.ABTestObject]? = nil) -> ABTest.ABTestVariant {
        return .init(id: id,
                     modulus: .init(lower: lower, upper: upper),
                     objects: objects)
    }
}
