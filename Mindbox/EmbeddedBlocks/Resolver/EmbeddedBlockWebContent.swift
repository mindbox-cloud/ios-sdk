//
//  EmbeddedBlockWebContent.swift
//  Mindbox
//
//  Created by vailence on 06.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

/// `params` travel untouched: the SDK does not know what a particular mechanic puts in them and
/// does not rebuild them, so a page can gain fields without an SDK release.
struct EmbeddedBlockWebContent: Equatable {

    /// Goes into the page's handshake, and it is what a tap inside the block reports back.
    let inAppId: String

    /// The document origin the markup is committed under, not where it is downloaded from: the page
    /// resolves parts of itself against its own location, so it must be the address the backend set.
    let baseUrl: String

    let contentUrl: String

    let frequency: InappFrequency?

    let isPriority: Bool

    let tags: [String: String]?

    let params: [String: JSONValue]

    /// The config's delay before the content may be shown; the place registry holds the answer for it.
    let delayTime: String?

    init(inAppId: String,
         baseUrl: String,
         contentUrl: String,
         frequency: InappFrequency?,
         isPriority: Bool = false,
         tags: [String: String]?,
         params: [String: JSONValue],
         delayTime: String? = nil) {
        self.inAppId = inAppId
        self.baseUrl = baseUrl
        self.contentUrl = contentUrl
        self.frequency = frequency
        self.isPriority = isPriority
        self.tags = tags
        self.params = params
        self.delayTime = delayTime
    }

    /// The in-app id counts as the page's identity, not as its data: it goes into the start payload,
    /// so handing a page new params under a different in-app would describe something it is not.
    func isSamePage(as other: EmbeddedBlockWebContent) -> Bool {
        inAppId == other.inAppId && baseUrl == other.baseUrl && contentUrl == other.contentUrl
    }
}
