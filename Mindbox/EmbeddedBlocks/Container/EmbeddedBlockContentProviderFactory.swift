//
//  EmbeddedBlockContentProviderFactory.swift
//  Mindbox
//
//  Created by vailence on 06.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

/// Builds a content provider for a specific block.
///
/// A provider belongs to one container, so it is created anew for every block — this is what
/// makes blocks with the same id independent.
protocol EmbeddedBlockContentProviderMaking {
    func makeProvider(placeSystemName: String) -> EmbeddedBlockWebViewProvider
}

final class EmbeddedBlockContentProviderFactory: EmbeddedBlockContentProviderMaking {

    private let registry: EmbeddedBlockPlaceRegistering
    private let inappService: EmbeddedBlockInappServing
    private let failureManager: InappShowFailureManagerProtocol
    private let accounting: InappShowAccounting

    init(registry: EmbeddedBlockPlaceRegistering,
         inappService: EmbeddedBlockInappServing,
         failureManager: InappShowFailureManagerProtocol,
         accounting: InappShowAccounting) {
        self.registry = registry
        self.inappService = inappService
        self.failureManager = failureManager
        self.accounting = accounting
    }

    func makeProvider(placeSystemName: String) -> EmbeddedBlockWebViewProvider {
        EmbeddedBlockWebViewProvider(placeSystemName: placeSystemName,
                                     registry: registry,
                                     inappService: inappService,
                                     makePage: { EmbeddedBlockWebViewPage(content: $0) },
                                     accounting: accounting,
                                     reportFailure: { [failureManager] content, reason, details in
                                         // Captured, not read through the factory: a provider outliving it
                                         // would otherwise drop the failure it is reporting.
                                         Self.report(failure: reason, details: details, for: content, to: failureManager)
                                     },
                                     reportUnansweredWait: { [failureManager] in
                                         failureManager.sendUnattributedFailure()
                                     })
    }

    /// Past the buffer: it keeps one failure per in-app id and would drop this one whenever a
    /// selection pass had already buffered another.
    static func report(failure reason: InAppShowFailureReason,
                       details: String,
                       for content: EmbeddedBlockWebContent,
                       to manager: InappShowFailureManagerProtocol) {
        manager.sendFailure(inappId: content.inAppId,
                            reason: reason,
                            details: details,
                            tags: content.tags)
    }
}
