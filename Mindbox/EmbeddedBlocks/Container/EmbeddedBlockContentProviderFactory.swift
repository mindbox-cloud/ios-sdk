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
                                     reportFailure: { [failureManager] inAppId, tags, reason, details in
                                         // Captured, not read through the factory: a provider outliving it
                                         // would otherwise drop the failure it is reporting.
                                         Self.report(failure: reason, details: details, inAppId: inAppId, tags: tags, to: failureManager)
                                     },
                                     reportUnansweredWait: { [failureManager, inappService] waited in
                                         failureManager.sendWaitBudgetExceeded(place: placeSystemName,
                                                                               waited: waited,
                                                                               phase: inappService.hasConfig ? .resolvePending : .configMissing)
                                     })
    }

    /// Past the buffer: it keeps one failure per in-app id and would drop this one whenever a
    /// selection pass had already buffered another.
    static func report(failure reason: InAppShowFailureReason,
                       details: String,
                       inAppId: String,
                       tags: [String: String]?,
                       to manager: InappShowFailureManagerProtocol) {
        manager.sendBlockFailure(inappId: inAppId,
                                 reason: reason,
                                 details: details,
                                 tags: tags)
    }
}
