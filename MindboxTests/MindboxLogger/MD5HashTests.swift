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

private let md5VectorsSharedWithAndroidAndServer: [MD5HashTests.Vector] = [
    .init(name: "lowercase deviceUUID", deviceUUID: "216e6225-3170-4089-a6f0-3d1ed8f64153", expectedHex: "334db432a8f72f64a89664682f7bc032"),
    .init(name: "uppercase deviceUUID hashes like its lowercase form", deviceUUID: "216E6225-3170-4089-A6F0-3D1ED8F64153", expectedHex: "334db432a8f72f64a89664682f7bc032"),
    .init(name: "another deviceUUID", deviceUUID: "126e6225-3170-4089-a6f0-3d1ed8f64153", expectedHex: "248eccb79da2bbca61c133c59e4a1516"),
    .init(name: "hash with leading zeros keeps its hex padding", deviceUUID: "7e570ddf-8270-40a8-a369-b584ff5e9ff0", expectedHex: "000baa91b37b3c201e3f8604c7845201"),
    .init(name: "empty input hashes to the well-known MD5 of zero bytes", deviceUUID: "", expectedHex: "d41d8cd98f00b204e9800998ecf8427e")
]

@Suite("MD5Hash")
struct MD5HashTests {

    struct Vector: CustomTestStringConvertible, Sendable {
        let name: String
        let deviceUUID: String
        let expectedHex: String

        var testDescription: String { name }
    }

    @Test(arguments: md5VectorsSharedWithAndroidAndServer)
    func matchesSharedDeviceUUIDVectors(vector: Vector) {
        #expect(MD5Hash(deviceUUID: vector.deviceUUID) == MD5Hash(hex: vector.expectedHex))
    }

    @Test
    func normalizesHexCaseForComparison() {
        #expect(MD5Hash(hex: "334DB432A8F72F64A89664682F7BC032") == MD5Hash(hex: "334db432a8f72f64a89664682f7bc032"))
    }

    @Test
    func differentUUIDsProduceDifferentHashes() {
        #expect(MD5Hash(deviceUUID: "216e6225-3170-4089-a6f0-3d1ed8f64153") != MD5Hash(deviceUUID: "126e6225-3170-4089-a6f0-3d1ed8f64153"))
    }

    @available(iOS, introduced: 12.0, deprecated: 13.0, message: "Exercises the iOS 12 CC_MD5 fallback")
    @Test(arguments: md5VectorsSharedWithAndroidAndServer)
    func commonCryptoFallbackMatchesSharedVectors(vector: Vector) {
        let digest = MD5Hash.commonCryptoMD5(Data(vector.deviceUUID.lowercased().utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        #expect(hex == vector.expectedHex)
    }
}
