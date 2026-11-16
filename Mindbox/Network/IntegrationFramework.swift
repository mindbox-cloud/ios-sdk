//
//  IntegrationFramework.swift
//  Mindbox
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

enum IntegrationFramework {

    static let headerName = "Mindbox-Integration-Framework"

    private static let nativeValue = "native"
    private static let invalidValue = "invalid"
    private static let maxLength = 128
    private static let allowedPunctuation: Set<UInt8> = Set(" ._+-/;".utf8)

    /// nil -> "native"; matches the format -> value unchanged; otherwise "invalid"
    static func headerValue(for rawValue: String?) -> String {
        guard let rawValue else { return nativeValue }
        let bytes = Array(rawValue.utf8)
        guard (1...maxLength).contains(bytes.count), bytes.allSatisfy(isAllowed) else {
            return invalidValue
        }
        return rawValue
    }

    private static func isAllowed(_ byte: UInt8) -> Bool {
        switch byte {
        case UInt8(ascii: "A")...UInt8(ascii: "Z"),
             UInt8(ascii: "a")...UInt8(ascii: "z"),
             UInt8(ascii: "0")...UInt8(ascii: "9"):
            return true
        default:
            return allowedPunctuation.contains(byte)
        }
    }
}
