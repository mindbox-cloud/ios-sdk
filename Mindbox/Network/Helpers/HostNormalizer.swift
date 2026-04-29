//
//  HostNormalizer.swift
//  Mindbox
//
//  Created by Sergei Semko on 4/27/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

/// Scheme-aware normalization for `domain` / `operationsDomain` inputs.
/// Accepts `host`, `https://host`, `http://host`, with or without trailing slash.
enum HostNormalizer {

    private static let httpsPrefix = "https://"
    private static let httpPrefix = "http://"

    /// Strips scheme (case-insensitive), whitespace, and trailing slashes.
    static func extractHost(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.range(of: httpsPrefix, options: [.caseInsensitive, .anchored]) != nil {
            value = String(value.dropFirst(httpsPrefix.count))
        } else if value.range(of: httpPrefix, options: [.caseInsensitive, .anchored]) != nil {
            value = String(value.dropFirst(httpPrefix.count))
        }
        while value.hasSuffix("/") {
            value.removeLast()
        }
        return value
    }

    /// Preserves an existing scheme, otherwise prepends `https://`.
    static func toBaseURLString(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while value.hasSuffix("/") { value.removeLast() }
        if hasSchemePrefix(value) {
            return value
        }
        return httpsPrefix + value
    }

    private static func hasSchemePrefix(_ value: String) -> Bool {
        let options: String.CompareOptions = [.caseInsensitive, .anchored]
        return value.range(of: httpsPrefix, options: options) != nil
            || value.range(of: httpPrefix, options: options) != nil
    }
}
