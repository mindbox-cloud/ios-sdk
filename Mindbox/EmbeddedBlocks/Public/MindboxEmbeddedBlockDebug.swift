//
//  MindboxEmbeddedBlockDebug.swift
//  Mindbox
//
//  Created by Sergei Semko on 17.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

/// Debug control over embedded block content — for the test app and acceptance testing.
///
/// Overrides the answer to "what stands behind this place system name", that is, it takes exactly
/// the place of the admin panel config. Everything below — the provider, the page, the container's
/// waiting budget, the show accounting — works unchanged, so acceptance testing exercises the
/// production path rather than a separate test mode.
///
/// Not part of the public API: available only via `@_spi(Internal) import Mindbox`. Deliberately
/// not stripped from release builds — QA checks exactly what ships to clients — which is why every
/// override that gets set is written to the log.
@_spi(Internal)
public enum MindboxEmbeddedBlockDebug {

    /// What to replace the block content with.
    public enum Content {

        /// A page url. This is how scenarios are run against the real network — including a
        /// knowingly unreachable address, to get a load failure.
        case url(URL)

        /// Ready-made markup. This is how scenarios that do not exist on the network are set up: a
        /// page reporting "empty", a silent page, a page with a broken report.
        case html(String)

        /// Nothing is attached to the place: the block is turned off in the admin panel or the
        /// place system name is unknown.
        case empty
    }

    /// Overrides the content of the block in this place. Applies to blocks that start loading after
    /// the call: a block that is already shown has to be reloaded or its screen reopened.
    public static func setContent(_ content: Content, for placeSystemName: String) {
        Logger.common(message: "[EmbeddedBlock] Debug override set for place '\(placeSystemName)'",
                      category: .embeddedBlocks)
        EmbeddedBlockDebugOverrides.shared.set(content.resolution, for: placeSystemName)
    }

    /// Gives the block its usual content back.
    public static func removeContent(for placeSystemName: String) {
        Logger.common(message: "[EmbeddedBlock] Debug override removed for place '\(placeSystemName)'",
                      category: .embeddedBlocks)
        EmbeddedBlockDebugOverrides.shared.remove(for: placeSystemName)
    }

    /// Drops every override at once.
    public static func removeAllContent() {
        Logger.common(message: "[EmbeddedBlock] All debug overrides removed", category: .embeddedBlocks)
        EmbeddedBlockDebugOverrides.shared.removeAll()
    }
}

extension MindboxEmbeddedBlockDebug.Content {

    /// Markup travels as a `data:` url so the production fetch path stays exercised. The identity
    /// fields are knowingly fake and greppable: events for an overridden block must be tellable
    /// from a real in-app at a glance.
    var resolution: EmbeddedBlockResolution {
        switch self {
        case .url(let url):
            return .content(debugContent(contentUrl: url.absoluteString))
        case .html(let html):
            let dataUrl = "data:text/html;charset=utf-8;base64," + Data(html.utf8).base64EncodedString()
            return .content(debugContent(contentUrl: dataUrl))
        case .empty:
            return .empty
        }
    }

    /// `unlimited` on purpose: nothing is written into the local show history, so an override never
    /// leaves a trace the frequency of a real in-app would later read.
    private func debugContent(contentUrl: String) -> EmbeddedBlockWebContent {
        EmbeddedBlockWebContent(inAppId: "qa-debug-override",
                                baseUrl: "https://inapp.local/qa-debug",
                                contentUrl: contentUrl,
                                frequency: .unlimited,
                                tags: nil,
                                params: [:])
    }
}

/// The store behind ``MindboxEmbeddedBlockDebug``, read by the resolver on every resolve.
///
/// Locked rather than main-confined: the debug API is public surface and makes no promise about the
/// caller's thread.
final class EmbeddedBlockDebugOverrides {

    static let shared = EmbeddedBlockDebugOverrides()

    private let lock = NSLock()
    private var resolutions: [String: EmbeddedBlockResolution] = [:]

    func set(_ resolution: EmbeddedBlockResolution, for place: String) {
        lock.lock()
        defer { lock.unlock() }
        resolutions[place] = resolution
    }

    func remove(for place: String) {
        lock.lock()
        defer { lock.unlock() }
        resolutions.removeValue(forKey: place)
    }

    func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        resolutions.removeAll()
    }

    func resolution(for place: String) -> EmbeddedBlockResolution? {
        lock.lock()
        defer { lock.unlock() }
        return resolutions[place]
    }
}
