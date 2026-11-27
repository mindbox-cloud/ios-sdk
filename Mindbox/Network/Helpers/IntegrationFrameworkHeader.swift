//
//  IntegrationFrameworkHeader.swift
//  Mindbox
//

import Foundation

enum IntegrationFrameworkHeader {

    static let name = "Mindbox-Integration-Framework"

    private static let nativeValue = "native"
    private static let invalidValue = "invalid"
    private static let unknownVersion = "unknown"
    private static let maxLength = 128
    private static let allowedCharacters = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 ._+/;-"
    )

    static func value(
        wrapperValue: String?,
        xcodeVersion: String = xcodeVersion(fromDTXcode: Bundle.main.object(forInfoDictionaryKey: "DTXcode"))
    ) -> String {
        let value = normalize(wrapperValue)
        return value == nativeValue ? "\(nativeValue); xcode/\(xcodeVersion)" : value
    }

    static func normalize(_ wrapperValue: String?) -> String {
        guard let wrapperValue = wrapperValue,
              !wrapperValue.unicodeScalars.allSatisfy({ $0 == " " }) else {
            return nativeValue
        }
        let isInFormat = wrapperValue.utf16.count <= maxLength
            && wrapperValue.unicodeScalars.allSatisfy(allowedCharacters.contains)
        return isInFormat ? wrapperValue : invalidValue
    }

    static func xcodeVersion(fromDTXcode rawValue: Any?) -> String {
        guard let digits = rawValue as? String,
              digits.count >= 3,
              digits.allSatisfy({ $0.isASCII && $0.isNumber }),
              let major = Int(digits.dropLast(2)) else {
            return unknownVersion
        }
        let minor = digits[digits.index(digits.endIndex, offsetBy: -2)]
        let patch = digits[digits.index(before: digits.endIndex)]
        return "\(major).\(minor).\(patch)"
    }
}
