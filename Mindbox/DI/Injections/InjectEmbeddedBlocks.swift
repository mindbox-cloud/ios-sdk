//
//  InjectEmbeddedBlocks.swift
//  Mindbox
//
//  Created by vailence on 03.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

extension MBContainer {
    func registerEmbeddedBlocks() -> Self {
        // Container-scoped: one resolver and one registry per container, which is why several
        // blocks of one place share a single resolve.
        register(EmbeddedBlockResolving.self) {
            EmbeddedBlockResolver()
        }

        register(EmbeddedBlockPlaceRegistering.self) {
            EmbeddedBlockPlaceRegistry(resolver: DI.injectOrFail(EmbeddedBlockResolving.self))
        }

        register(EmbeddedBlockFeedServing.self) {
            EmbeddedBlockFeedService()
        }

        register(EmbeddedBlockContentProviderMaking.self) {
            EmbeddedBlockContentProviderFactory(registry: DI.injectOrFail(EmbeddedBlockPlaceRegistering.self),
                                                feed: DI.injectOrFail(EmbeddedBlockFeedServing.self))
        }

        return self
    }
}
