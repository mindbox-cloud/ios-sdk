//
//  ABTestStubs.swift
//  MindboxTests
//
//  Created by vailence on 03.12.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
@testable import Mindbox

struct ABTestsStub {
    func getABTest(
        id: String = "9999999",
        sdkVersion: SdkVersion = SdkVersion(min: 6, max: nil),
        salt: String = "BBBC2BA1-0B5B-4C9E-AB0E-95C54775B4F1",
        variants: [ABTest.ABTestVariant]
    ) -> ABTest {
        return ABTest(
            id: id,
            sdkVersion: sdkVersion,
            salt: salt,
            variants: variants
        )
    }

    func getVariantConcrete(id: String = "1", lower: Int, upper: Int, inapps: [String] = []) -> ABTest.ABTestVariant {
        ABTest.ABTestVariant(
            id: id,
            modulus: ABTest.ABTestVariant.Modulus(lower: lower, upper: upper),
            objects: [
                ABTest.ABTestVariant.ABTestObject(
                    type: .inapps,
                    kind: .concrete,
                    inapps: inapps
                )
            ]
        )
    }

    func getVariantAll(id: String = "99", lower: Int, upper: Int) -> ABTest.ABTestVariant {
        ABTest.ABTestVariant(
            id: id,
            modulus: ABTest.ABTestVariant.Modulus(lower: lower, upper: upper),
            objects: [
                ABTest.ABTestVariant.ABTestObject(
                    type: .inapps,
                    kind: .all,
                    inapps: nil
                )
            ]
        )
    }
}
