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

    /// Strips scheme (case-insensitive), whitespace, and trailing slashes.
    static func extractHost(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.lowercased().hasPrefix("https://") {
            value = String(value.dropFirst("https://".count))
        } else if value.lowercased().hasPrefix("http://") {
            value = String(value.dropFirst("http://".count))
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
        let lower = value.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
            return value
        }
        return "https://" + value
    }

    /// Validates the extracted host. The `https://` prefix is required by
    /// `URLValidator`'s full-URL regex — to be folded into URLValidator on rewrite.
    static func isValidHost(_ raw: String) -> Bool {
        let host = extractHost(raw)
        guard !host.isEmpty,
              let url = URL(string: "https://" + host) else { return false }
        return URLValidator(url: url).evaluate()
    }
}
