//
//  EmbeddedBlockContentProviderFactory.swift
//  Mindbox
//
//  Created by vailence on 06.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

/// Builds a content provider for a specific block.
///
/// A provider belongs to one container, so it is created anew for every block — this is what
/// makes blocks with the same id independent.
protocol EmbeddedBlockContentProviderMaking {
    func makeProvider(id: String) -> EmbeddedBlockWebViewProvider
}

final class EmbeddedBlockContentProviderFactory: EmbeddedBlockContentProviderMaking {

    private let resolver: EmbeddedBlockResolving
    private let actionHandler: EmbeddedBlockActionHandling

    init(resolver: EmbeddedBlockResolving,
         actionHandler: EmbeddedBlockActionHandling) {
        self.resolver = resolver
        self.actionHandler = actionHandler
    }

    func makeProvider(id: String) -> EmbeddedBlockWebViewProvider {
        EmbeddedBlockWebViewProvider(id: id,
                                     resolver: resolver,
                                     actionHandler: actionHandler,
                                     makePage: { EmbeddedBlockWebViewPage(content: $0) })
    }
}
