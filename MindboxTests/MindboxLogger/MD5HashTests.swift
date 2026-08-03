//
//  MD5HashTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 8/3/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import Testing
@testable import Mindbox

// Shared vectors from android-sdk PR #749 (MOBILE-281): the same deviceUUID must
// produce the same target on iOS, Android and the server.
private let sharedMD5Vectors: [(String, String)] = [
    ("216e6225-3170-4089-a6f0-3d1ed8f64153", "334db432a8f72f64a89664682f7bc032"),
    // the same uuid uppercased → the same hash: MD5Hash lowercases the input before hashing
    // (raw md5 of the UPPERCASE string itself would be 2a482810731225da19199c17a956a560)
    ("216E6225-3170-4089-A6F0-3D1ED8F64153", "334db432a8f72f64a89664682f7bc032"),
    ("126e6225-3170-4089-a6f0-3d1ed8f64153", "248eccb79da2bbca61c133c59e4a1516"),
    // hash with leading zeros — catches broken hex padding
    ("7e570ddf-8270-40a8-a369-b584ff5e9ff0", "000baa91b37b3c201e3f8604c7845201"),
    // md5 of zero bytes — the well-known constant
    ("", "d41d8cd98f00b204e9800998ecf8427e")
]

@Suite("MD5Hash")
struct MD5HashTests {

    @Test(arguments: sharedMD5Vectors)
    func matchesSharedDeviceUUIDVectors(deviceUUID: String, expectedHex: String) {
        #expect(MD5Hash(deviceUUID: deviceUUID) == MD5Hash(hex: expectedHex))
    }

    @Test
    func normalizesHexCaseForComparison() {
        #expect(MD5Hash(hex: "334DB432A8F72F64A89664682F7BC032") == MD5Hash(hex: "334db432a8f72f64a89664682f7bc032"))
    }

    @Test
    func differentUUIDsProduceDifferentHashes() {
        #expect(MD5Hash(deviceUUID: "216e6225-3170-4089-a6f0-3d1ed8f64153") != MD5Hash(deviceUUID: "126e6225-3170-4089-a6f0-3d1ed8f64153"))
    }

    // Deprecated-annotated so the CC_MD5 fallback call compiles without a warning.
    @available(iOS, introduced: 12.0, deprecated: 13.0, message: "Exercises the iOS 12 CC_MD5 fallback")
    @Test(arguments: sharedMD5Vectors)
    func commonCryptoFallbackMatchesSharedVectors(deviceUUID: String, expectedHex: String) {
        let digest = MD5Hash.commonCryptoMD5(Data(deviceUUID.lowercased().utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        #expect(hex == expectedHex)
    }
}
