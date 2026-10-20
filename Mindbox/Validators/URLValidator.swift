//
//  URLValidator.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 02.02.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation

enum URLValidator {

    private static let maxHostLength = 253

    private static let maxLabelLength = 63

    private static let pathPrefixPattern = "^(?:/(?:[A-Za-z0-9._~-]|%[0-9A-Fa-f]{2})+)*$"

    static func isValidHostWithOptionalPath(_ value: String) -> Bool {
        guard let slashIndex = value.firstIndex(of: "/") else { return isValidHost(value) }
        let host = String(value[..<slashIndex])
        let path = String(value[slashIndex...])
        return isValidHost(host)
            && path.range(of: pathPrefixPattern, options: .regularExpression) != nil
    }

    static func isValidHost(_ host: String) -> Bool {
        guard !host.isEmpty, host.count <= maxHostLength else { return false }

        let labels = host.split(separator: ".", omittingEmptySubsequences: false)

        if labels.count == 4, labels.allSatisfy({ $0.allSatisfy(\.isASCII) && $0.allSatisfy(\.isNumber) }) {
            return labels.allSatisfy(isValidIPv4Octet)
        }

        return labels.allSatisfy(isValidLabel)
    }

    private static func isValidLabel(_ label: Substring) -> Bool {
        guard (1...maxLabelLength).contains(label.count),
              label.first != "-",
              label.last != "-"
        else { return false }
        return label.unicodeScalars.allSatisfy(isAlnumOrHyphen)
    }

    private static func isValidIPv4Octet(_ label: Substring) -> Bool {
        guard (1...3).contains(label.count), let value = Int(label) else { return false }
        return (0...255).contains(value)
    }

    private static func isAlnumOrHyphen(_ scalar: Unicode.Scalar) -> Bool {
        ("a"..."z").contains(scalar)
            || ("A"..."Z").contains(scalar)
            || ("0"..."9").contains(scalar)
            || scalar == "-"
    }
}
