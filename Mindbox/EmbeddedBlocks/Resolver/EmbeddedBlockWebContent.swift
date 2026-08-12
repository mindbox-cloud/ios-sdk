//
//  EmbeddedBlockWebContent.swift
//  Mindbox
//
//  Created by vailence on 06.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

struct EmbeddedBlockWebContent: Equatable {

    enum Source: Equatable {
        case url(URL)

        /// Markup instead of an address. Needed by the debug content override: acceptance
        /// scenarios — an empty page, a silent page, an answer that comes after the timeout — are
        /// not published to the network.
        /// TODO: - Remove this once we parse the url from the config
        case html(String)
    }

    let source: Source

    init(url: URL) {
        source = .url(url)
    }

    init(html: String) {
        source = .html(html)
    }
}
