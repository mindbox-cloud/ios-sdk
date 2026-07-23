//
//  URLValidator.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 02.02.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation

/// Validates a bare hostname (e.g. `api.mindbox.ru`, `localhost`, `192.168.1.1`)
/// using RFC 1123 label structure. No TLD allow-list — new TLDs (`.app`, `.dev`, …)
/// are accepted automatically. Analogous to Android's `PatternsCompat.DOMAIN_NAME`,
/// including its IPv4 octet-range enforcement.
enum URLValidator {

    /// RFC 1035: full hostname max 253 chars.
    private static let maxHostLength = 253

    /// RFC 1035: each label 1..63 chars.
    private static let maxLabelLength = 63

    /// Path-prefix rule for `isValidHostWithOptionalPath`: zero or more non-empty
    /// segments of unreserved URL characters. Query, fragment and empty segments
    /// do not match.
    private static let pathPrefixPattern = "^(?:/[A-Za-z0-9._~%-]+)*$"

    /// Validates `host` or `host/path-prefix` (scheme must already be stripped,
    /// e.g. via `HostNormalizer.extractHost`). Used for `operationsDomain`, which
    /// may carry a path prefix (e.g. `domain.com/api/v2`) — operation endpoints
    /// are appended after it. Path segments must be non-empty; query and fragment
    /// are rejected.
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

        // Four pure-digit labels = IPv4 literal — enforce octet ranges so
        // `999.999.999.999` is rejected (matches Android's PatternsCompat).
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
