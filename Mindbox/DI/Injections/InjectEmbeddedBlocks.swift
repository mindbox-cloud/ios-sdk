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
        // The resolver is shared: its per-id cache and its queue of waiting blocks are what make
        // several blocks with the same id resolve through a single load of the data. The action
        // router is shared because it is stateless. Providers, in contrast, are made per block by
        // the factory, so blocks stay independent of each other.
        register(EmbeddedBlockResolving.self) {
            EmbeddedBlockResolver()
        }

        register(EmbeddedBlockActionHandling.self) {
            EmbeddedBlockActionRouter()
        }

        register(EmbeddedBlockContentProviderMaking.self) {
            EmbeddedBlockContentProviderFactory(resolver: DI.injectOrFail(EmbeddedBlockResolving.self),
                                                actionHandler: DI.injectOrFail(EmbeddedBlockActionHandling.self))
        }

        return self
    }
}
