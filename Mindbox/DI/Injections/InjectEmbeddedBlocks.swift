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
        // One resolver and one registry per container: blocks of one place share a single resolve.
        register(EmbeddedBlockResolving.self) {
            EmbeddedBlockResolver()
        }

        register(EmbeddedBlockPlaceRegistering.self) {
            EmbeddedBlockPlaceRegistry(resolver: DI.injectOrFail(EmbeddedBlockResolving.self),
                                       budget: DI.injectOrFail(InappShowBudgeting.self))
        }

        register(EmbeddedBlockInappServing.self) {
            EmbeddedBlockInappService()
        }

        register(EmbeddedBlockContentProviderMaking.self) {
            EmbeddedBlockContentProviderFactory(registry: DI.injectOrFail(EmbeddedBlockPlaceRegistering.self),
                                                inappService: DI.injectOrFail(EmbeddedBlockInappServing.self),
                                                failureManager: DI.injectOrFail(InappShowFailureManagerProtocol.self),
                                                accounting: DI.injectOrFail(InappShowAccounting.self))
        }

        return self
    }
}
