//
//  MD5Hash.swift
//  Mindbox
//
//  Created by Sergei Semko on 8/3/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import CommonCrypto
import CryptoKit
import Foundation

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

    @available(iOS, introduced: 12.0, deprecated: 13.0, message: "CC_MD5 fallback; delete when the deployment target reaches iOS 13")
    static func commonCryptoMD5(_ data: Data) -> [UInt8] {
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        data.withUnsafeBytes { bytes in
            _ = CC_MD5(bytes.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest
    }
}
