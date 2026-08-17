//
//  MindboxEmbeddedBlockDebug.swift
//  Mindbox
//
//  Created by vailence on 06.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

/// Debug control over embedded block content — for the test app and acceptance testing.
///
/// Overrides the answer to "what stands behind this place system name", that is, it takes exactly the place of the
/// admin panel config. Everything below — the resolver, the provider, the page, the container's
/// waiting budget — works unchanged, so acceptance testing exercises the production path rather
/// than a separate test mode.
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
        /// page reporting "empty", a silent page, a page that answers after the timeout.
        case html(String)

        /// Nothing is attached to the place: the block is turned off in the admin panel or the
        /// place system name is unknown.
        case empty
    }

    /// Overrides the content of the block in this place. Applies to blocks that start loading after
    /// the call: a block that is already shown has to be reloaded or its screen reopened.
    public static func setContent(_ content: Content, for placeSystemName: String) {
        EmbeddedBlockContentOverrides.shared.set(content.resolution, for: placeSystemName)
    }

    /// Gives the block its usual content back.
    public static func removeContent(for placeSystemName: String) {
        EmbeddedBlockContentOverrides.shared.remove(for: placeSystemName)
    }

    /// Drops every override at once.
    public static func removeAllContent() {
        EmbeddedBlockContentOverrides.shared.removeAll()
    }

    /// Show the block as soon as the document has loaded, without waiting for `ready` from the page.
    ///
    /// Needed for exactly one scenario: seeing how the block looks and behaves inside the host
    /// layout while the web contract is not implemented on the page yet. Under the usual rule such
    /// a page stays silent, which means it collapses on the container timeout and there is nothing
    /// to see in the block.
    ///
    /// Off by default and set once at app startup. Keeping it on for longer than the UI check is a
    /// bad idea: with the flag on, a broken page looks like a working one. The flag does not cancel
    /// `ready` from the page — it only adds a second reason to show the block, so a page that does
    /// implement the contract behaves the same with it and without it.
    public static var treatsLoadedPageAsReady: Bool {
        get { EmbeddedBlockReadinessOverrides.shared.treatsLoadedPageAsReady }
        set { EmbeddedBlockReadinessOverrides.shared.setTreatsLoadedPageAsReady(newValue) }
    }
}

@_spi(Internal)
extension MindboxEmbeddedBlockDebug.Content {

    var resolution: EmbeddedBlockResolution {
        switch self {
        case .url(let url):
            return .content(EmbeddedBlockWebContent(url: url))
        case .html(let html):
            return .content(EmbeddedBlockWebContent(html: html))
        case .empty:
            return .empty
        }
    }
}
