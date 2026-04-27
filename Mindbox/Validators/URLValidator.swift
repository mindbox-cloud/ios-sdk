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
/// are accepted automatically. Analogous to Android's `PatternsCompat.DOMAIN_NAME`.
enum URLValidator {

    /// RFC 1035: full hostname max 253 chars.
    private static let maxHostLength = 253

    /// RFC 1035: each label 1..63 chars.
    private static let maxLabelLength = 63

    static func isValidHost(_ host: String) -> Bool {
        guard !host.isEmpty, host.count <= maxHostLength else { return false }
        return host
            .split(separator: ".", omittingEmptySubsequences: false)
            .allSatisfy(isValidLabel)
    }

    private static func isValidLabel(_ label: Substring) -> Bool {
        guard (1...maxLabelLength).contains(label.count),
              label.first != "-",
              label.last != "-"
        else { return false }
        return label.unicodeScalars.allSatisfy(isAlnumOrHyphen)
    }

    private static func isAlnumOrHyphen(_ scalar: Unicode.Scalar) -> Bool {
        ("a"..."z").contains(scalar)
            || ("A"..."Z").contains(scalar)
            || ("0"..."9").contains(scalar)
            || scalar == "-"
    }
}
