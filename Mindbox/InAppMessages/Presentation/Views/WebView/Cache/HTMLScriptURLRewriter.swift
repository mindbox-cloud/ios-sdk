//
//  HTMLScriptURLRewriter.swift
//  Mindbox
//
//  Created by Mindbox on 13.04.2026.
//

import Foundation
import MindboxLogger

/// Rewrites `<script src="https://...">` tags in HTML to use the `mindbox-cache://` scheme,
/// and extracts the original script URLs for pre-downloading.
///
/// Example:
/// ```
/// <script src="https://cdn.example.com/tracker.js">
/// → <script src="mindbox-cache://cdn.example.com/tracker.js">
/// ```
enum HTMLScriptURLRewriter {

    /// Result of rewriting HTML: the modified HTML string and the list of original script URLs found.
    struct Result {
        let html: String
        let scriptURLs: [String]
    }

    /// Rewrites all `<script src="https://...">` in the given HTML to use `mindbox-cache://`.
    /// Returns the modified HTML and a list of original HTTPS URLs that were replaced.
    static func rewrite(_ html: String) -> Result {
        // Match <script ... src="https://..." ...>
        // Captures the full https:// URL inside src attribute (both single and double quotes).
        let pattern = #"(<script\b[^>]*\bsrc\s*=\s*["'])(https://)(.*?)(["'][^>]*>)"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            Logger.common(
                message: "[HTMLRewriter] Failed to create regex",
                level: .error,
                category: .webViewInAppMessages
            )
            return Result(html: html, scriptURLs: [])
        }

        let range = NSRange(html.startIndex..., in: html)
        var scriptURLs: [String] = []

        let rewritten = regex.stringByReplacingMatches(
            in: html,
            options: [],
            range: range,
            withTemplate: "$1\(MindboxCacheSchemeHandler.scheme)://$3$4"
        )

        // Extract original URLs for pre-downloading
        regex.enumerateMatches(in: html, options: [], range: range) { match, _, _ in
            guard let match,
                  let schemeRange = Range(match.range(at: 2), in: html),
                  let pathRange = Range(match.range(at: 3), in: html) else { return }

            let originalURL = String(html[schemeRange]) + String(html[pathRange])
            scriptURLs.append(originalURL)
        }

        if !scriptURLs.isEmpty {
            Logger.common(
                message: "[HTMLRewriter] Rewrote \(scriptURLs.count) script URL(s): \(scriptURLs)",
                category: .webViewInAppMessages
            )
        }

        return Result(html: rewritten, scriptURLs: scriptURLs)
    }
}
