//
//  MD5Hash.swift
//  Mindbox
//
//  Created by Sergei Semko on 8/3/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import CommonCrypto
// CryptoKit is auto-weak-linked (deployment target < iOS 13, LC_LOAD_WEAK_DYLIB
// in the linked binary), so this import cannot break iOS 12 startup; the
// #available guard below keeps its symbols untouched there.
import CryptoKit
import Foundation

/// Match token for monitoring log requests (MOBILE-340): MD5 hex of the lowercased
/// deviceUUID. Both the hash input and the hex are lowercased, so comparison is
/// case-insensitive. Must stay in sync with the server contract and Android's
/// `Md5Hash` (android-sdk #749).
struct MD5Hash: Equatable {
    let hex: String

    init(hex: String) {
        self.hex = hex.lowercased()
    }

    init(deviceUUID: String) {
        self.hex = Self.md5HexDigest(of: deviceUUID.lowercased())
    }

    private static func md5HexDigest(of string: String) -> String {
        let data = Data(string.utf8)
        let digest: [UInt8]
        if #available(iOS 13.0, *) {
            digest = Array(Insecure.MD5.hash(data: data))
        } else {
            digest = commonCryptoMD5(data)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // Internal, not private: no iOS 12 simulator exists on modern Xcode, so tests
    // call this fallback directly — CC_MD5 is the same C API on every OS version.
    @available(iOS, introduced: 12.0, deprecated: 13.0, message: "CC_MD5 fallback; delete when the deployment target reaches iOS 13")
    static func commonCryptoMD5(_ data: Data) -> [UInt8] {
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        data.withUnsafeBytes { bytes in
            _ = CC_MD5(bytes.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest
    }
}
