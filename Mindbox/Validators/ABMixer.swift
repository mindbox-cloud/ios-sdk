//
//  ABMixer.swift
//  Mindbox
//
//  Created by vailence on 26.05.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import CommonCrypto
import Foundation

class CustomerAbMixer {
    private let sha256 = SHA256()

    func modulusGuidHash(identifier: UUID, salt: String) -> Int {
        let saltUpper = salt.uppercased()
        return stringModulusHash(identifier: identifier.uuidString.uppercased(), saltUpper: saltUpper)
    }
    
    private func stringModulusHash(identifier: String, saltUpper: String) -> Int {
        let saltedId = identifier + saltUpper
        guard let saltedData = saltedId.data(using: .utf8) else { return 0 }
        
        let hash = sha256.hash(data: saltedData)
        guard hash.count >= 32 else { return 0 }

        let bigEndianLastBytesAsInt =
            (Int(hash[28]) << 24)
            | (Int(hash[29]) << 16)
            | (Int(hash[30]) << 8)
            | Int(hash[31])
        
        let unsigned = UInt(bitPattern: bigEndianLastBytesAsInt)
        return Int(unsigned % 100)
    }
}

struct SHA256 {
    func hash(data: Data) -> Data {
        var hashData = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { (messageBytes) in
            hashData.withUnsafeMutableBytes { (hashBytes) in
                _ = CC_SHA256(messageBytes.baseAddress, CC_LONG(data.count), hashBytes.bindMemory(to: UInt8.self).baseAddress)
            }
        }
        return hashData
    }
}
