//
//  EmbeddedBlockWebContent.swift
//  Mindbox
//
//  Created by vailence on 06.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

/// What a block was told to show: the page's identity and params, plus the two in-app facts the block
/// needs for bookkeeping rather than for drawing.
///
/// `params` travel untouched: the SDK does not know what a particular mechanic puts in them and does
/// not rebuild them, so a page can gain fields without an SDK release.
struct EmbeddedBlockWebContent: Equatable {

    /// The in-app the content came from. The page asks for it in the handshake, and it is what a tap
    /// inside the block reports back.
    let inAppId: String

    /// The document origin the markup is committed under, not where it is downloaded from. The page
    /// resolves parts of itself against its own location, so this has to be the address the backend
    /// set rather than the file's real host.
    let baseUrl: String

    let contentUrl: String

    /// How often this in-app may be shown. Carried along because a block that draws its page has shown
    /// it, and the frequency is what decides whether that show is written down.
    let frequency: InappFrequency?

    /// The in-app's tags from the config, as they are. They travel with the content because the show
    /// and the failures reported from here carry them, and that is what lets metrics tell a block apart
    /// from an overlay.
    let tags: [String: String]?

    let params: [String: JSONValue]

    /// Whether this is the same page as `other`, differing at most in the data it carries.
    ///
    /// The in-app id counts as part of the page's identity, not as data: it goes into the start payload,
    /// so handing a page new params under a different in-app would describe something it is not.
    func isSamePage(as other: EmbeddedBlockWebContent) -> Bool {
        inAppId == other.inAppId && baseUrl == other.baseUrl && contentUrl == other.contentUrl
    }
}
