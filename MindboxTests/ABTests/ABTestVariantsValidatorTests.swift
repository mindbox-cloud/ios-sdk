//
//  ABTestVariantsValidatorTests.swift
//  MindboxTests
//
//  Created by vailence on 15.06.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox
//
//class ABTestVariantsValidatorTests: XCTestCase {
//    var variantValidator: ABTestVariantsValidator!
//    
//    struct TestCase {
//        let variant: ABTest.ABTestVariant?
//        let isValid: Bool
//    }
//    
//    var testCases: [TestCase] = []
//    
//    override func setUp() {
//        super.setUp()
//        
//        // TODO: - Divide to few different unit tests.
//        
//        let object1 = ABTest.ABTestVariant.ABTestObject(type: .inapps, kind: .all, inapps: ["inapp1"])
//        let object2 = ABTest.ABTestVariant.ABTestObject(type: .inapps, kind: .all, inapps: ["inapp2"])
//        testCases = [
//            TestCase(variant: createVariant(objects: [object1]), isValid: true), // valid case
//            TestCase(variant: createVariant(id: "", objects: [object1]), isValid: false), // invalid id
//            TestCase(variant: createVariant(lower: 101, objects: [object1]), isValid: false), // invalid lower bound
//            TestCase(variant: createVariant(upper: -1, objects: [object1]), isValid: false), // invalid upper bound
//            TestCase(variant: createVariant(lower: 50, upper: 50), isValid: false), // lower bound is equal to upper bound
//            TestCase(variant: createVariant(lower: 100, upper: 0, objects: [object1]), isValid: false), // lower bound is greater than upper bound
//            TestCase(variant: createVariant(objects: []), isValid: false), // no objects
//            TestCase(variant: createVariant(objects: [object1, object2]), isValid: false), // more than one object
//            TestCase(variant: nil, isValid: false) // variant is nil
//        ]
//        
//        variantValidator = ABTestVariantsValidator()
//    }
//    
//    override func tearDown() {
//        variantValidator = nil
//        testCases = []
//        super.tearDown()
//    }
//    
//    func testVariantIsValid() {
//        for testCase in testCases {
//            let result = variantValidator.isValid(item: testCase.variant)
//            XCTAssertEqual(result, testCase.isValid, "Expected \(testCase.isValid) for variant \(String(describing: testCase.variant)), but got \(result)")
//        }
//    }
//    
//    private func createVariant(id: String = "Test",
//                               lower: Int = 0,
//                               upper: Int = 100,
//                               objects: [ABTest.ABTestVariant.ABTestObject]? = nil) -> ABTest.ABTestVariant {
//        return .init(id: id,
//                     modulus: .init(lower: lower, upper: upper),
//                     objects: objects)
//    }
//}
