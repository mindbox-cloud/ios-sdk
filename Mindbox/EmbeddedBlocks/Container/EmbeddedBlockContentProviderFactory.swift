//
//  EmbeddedBlockContentProviderFactory.swift
//  Mindbox
//
//  Created by vailence on 06.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

/// Собирает провайдер контента под конкретный блок.
///
/// Провайдер принадлежит одному контейнеру, поэтому создаётся на каждый блок заново — это и
/// делает блоки с одинаковым id независимыми.
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
