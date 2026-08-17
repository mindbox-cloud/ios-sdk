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
        // several blocks with the same id resolve through a single load of the data. Providers,
        // in contrast, are made per block by the factory, so blocks stay independent of each
        // other — and so does the bridge session each of their pages runs.
        register(EmbeddedBlockResolving.self) {
            EmbeddedBlockResolver()
        }

        register(EmbeddedBlockContentProviderMaking.self) {
            EmbeddedBlockContentProviderFactory(resolver: DI.injectOrFail(EmbeddedBlockResolving.self))
        }

        return self
    }
}
