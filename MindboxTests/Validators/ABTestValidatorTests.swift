//
//  ABTestValidatorTests.swift
//  MindboxTests
//
//  Created by vailence on 15.06.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

class ABTestValidatorTests: XCTestCase {
    
    let sdkVersionValidator = SDKVersionValidator(sdkVersionNumeric: Constants.Versions.sdkVersionNumeric)
    var validator: ABTestValidator!
    
    struct TestCase {
        let abTest: InAppConfigResponse.ABTest
        let isValid: Bool
    }
    
    var testCases: [TestCase] = []
    
    override func setUp() {
        super.setUp()
        validator = ABTestValidator(sdkVersionValidator: sdkVersionValidator)
        
        let modulus = InAppConfigResponse.ABTest.ABTestVariant.Modulus(lower: 0, upper: 100)
        let abObject = InAppConfigResponse.ABTest.ABTestVariant.ABTestObject(type: .inapps, kind: .all, inapps: ["inapp1"])
        let variant1 = InAppConfigResponse.ABTest.ABTestVariant(id: "1", modulus: modulus, objects: [abObject])
        
        let abtest = InAppConfigResponse.ABTest(id: "123", sdkVersion: SdkVersion(min: 4, max: nil), salt: "salt", variants: [
            createVariant(lower: 0, upper: 50, objects: [abObject]),
            createVariant(lower: 50, upper: 100, objects: [abObject])
        ])
        
        testCases = [
            // Valid cases
            TestCase(abTest: abtest, isValid: true),
            TestCase(abTest: createAbTest(id: "sdfkj-sdfds-213123-dsew", sdkVersion: SdkVersion(min: 4, max: nil), salt: abtest.salt, variants: abtest.variants), isValid: true),
            TestCase(abTest: createAbTest(id: abtest.id, sdkVersion: SdkVersion(min: 4, max: nil), salt: "sdfsdf-sdfsd", variants: abtest.variants), isValid: true),
            
            // Invalid cases: No variants provided
            TestCase(abTest: createAbTest(id: abtest.id, sdkVersion: SdkVersion(min: 4, max: nil), salt: abtest.salt, variants: []), isValid: false),
            
            // Invalid cases: Only one variant provided
            TestCase(abTest: createAbTest(id: abtest.id, sdkVersion: SdkVersion(min: 4, max: nil), salt: abtest.salt, variants: [variant1]), isValid: false),
            
            // Invalid cases: Incorrect modulus values
            TestCase(abTest: createAbTest(id: abtest.id, sdkVersion: SdkVersion(min: 4, max: nil), salt: abtest.salt, variants: [
                createVariant(lower: -1, upper: 50, objects: [abObject]),
                createVariant(lower: 50, upper: 100, objects: [abObject])
            ]), isValid: false),
            TestCase(abTest: createAbTest(id: abtest.id, sdkVersion: SdkVersion(min: 4, max: nil), salt: abtest.salt, variants: [
                variant1,
                createVariant(lower: 101, upper: 100, objects: [abObject])
            ]), isValid: false),
            
            // Invalid cases: Modulus values do not span from 0 to 100
            TestCase(abTest: createAbTest(id: abtest.id, sdkVersion: SdkVersion(min: 4, max: nil), salt: abtest.salt, variants: [
                createVariant(lower: 1, upper: 50, objects: [abObject]),
                createVariant(lower: 50, upper: 100, objects: [abObject])
            ]), isValid: false),
            
            
            // Invalid cases: Incorrect modulus values
            TestCase(abTest: createAbTest(id: abtest.id, sdkVersion: SdkVersion(min: 4, max: nil), salt: abtest.salt, variants: [
                createVariant(lower: 50, upper: 98, objects: [abObject]),
                variant1
            ]), isValid: false),
            
            TestCase(abTest: createAbTest(id: abtest.id, sdkVersion: SdkVersion(min: 4, max: nil), salt: abtest.salt, variants: [
                createVariant(lower: 60, upper: 100, objects: [abObject]),
                variant1
            ]), isValid: false),
            
            TestCase(abTest: createAbTest(id: abtest.id, sdkVersion: SdkVersion(min: 4, max: nil), salt: abtest.salt, variants: [
                createVariant(lower: 40, upper: 100, objects: [abObject]),
                variant1
            ]), isValid: false),
            
            TestCase(abTest: createAbTest(id: abtest.id, sdkVersion: SdkVersion(min: 4, max: nil), salt: abtest.salt, variants: [
                createVariant(lower: 0, upper: 50, objects: [abObject]),
                createVariant(lower: 50, upper: 50, objects: [abObject]),
                createVariant(lower: 50, upper: 100, objects: [abObject])
            ]), isValid: false),
            
            TestCase(abTest: createAbTest(id: abtest.id, sdkVersion: SdkVersion(min: 4, max: nil), salt: abtest.salt, variants: [
                createVariant(lower: 0, upper: 60, objects: [abObject]),
                createVariant(lower: 40, upper: 60, objects: [abObject]),
                createVariant(lower: 60, upper: 100, objects: [abObject])
            ]), isValid: false),
            
            TestCase(abTest: createAbTest(id: abtest.id, sdkVersion: SdkVersion(min: 4, max: nil), salt: abtest.salt, variants: [
                createVariant(lower: 0, upper: 60, objects: [abObject]),
                createVariant(lower: 40, upper: 100, objects: [abObject]),
                createVariant(lower: 60, upper: 40, objects: [abObject])
            ]), isValid: false),
            
            // Invalid cases: Empty or null values
            TestCase(abTest: createAbTest(id: abtest.id, sdkVersion: SdkVersion(min: 4, max: nil), salt: nil, variants: abtest.variants), isValid: false),
            TestCase(abTest: createAbTest(id: abtest.id, sdkVersion: SdkVersion(min: 4, max: nil), salt: "", variants: abtest.variants), isValid: false),
            
            // Invalid cases: Empty id
            TestCase(abTest: createAbTest(id: "", sdkVersion: SdkVersion(min: 4, max: nil), salt: abtest.salt, variants: [variant1, variant1]), isValid: false),
            
            // Invalid cases: Null sdkVersion
            TestCase(abTest: createAbTest(id: abtest.id, sdkVersion: nil, salt: abtest.salt, variants: [variant1, variant1]), isValid: false)
        ]
    }
    
    override func tearDown() {
        validator = nil
        testCases = []
        super.tearDown()
    }
    
    func testVariantIsValid() {
        for testCase in testCases {
            let result = validator.isValid(item: testCase.abTest)
            XCTAssertEqual(result, testCase.isValid, "Expected \(testCase.isValid) for variant \(String(describing: testCase.abTest)), but got \(result)")
        }
    }
    
    private func createVariant(id: String = "Test",
                               lower: Int = 0,
                               upper: Int = 100,
                               objects: [InAppConfigResponse.ABTest.ABTestVariant.ABTestObject]? = nil) -> InAppConfigResponse.ABTest.ABTestVariant {
        return .init(id: id,
                     modulus: .init(lower: lower, upper: upper),
                     objects: objects)
    }
    
    private func createAbTest(id: String,
                              sdkVersion: SdkVersion?,
                              salt: String?,
                              variants: [InAppConfigResponse.ABTest.ABTestVariant]?) -> InAppConfigResponse.ABTest {
        return .init(id: id, sdkVersion: sdkVersion, salt: salt, variants: variants)
    }
}
