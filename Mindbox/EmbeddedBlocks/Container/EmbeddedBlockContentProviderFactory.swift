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
    private let feed: EmbeddedBlockFeedServing
    private let failureManager: InappShowFailureManagerProtocol

    init(registry: EmbeddedBlockPlaceRegistering,
         feed: EmbeddedBlockFeedServing,
         failureManager: InappShowFailureManagerProtocol) {
        self.registry = registry
        self.feed = feed
        self.failureManager = failureManager
    }

    func makeProvider(placeSystemName: String) -> EmbeddedBlockWebViewProvider {
        EmbeddedBlockWebViewProvider(placeSystemName: placeSystemName,
                                     registry: registry,
                                     feed: feed,
                                     makePage: { EmbeddedBlockWebViewPage(content: $0) },
                                     recordShow: { DI.injectOrFail(InAppTrackingServiceProtocol.self).trackInAppShown(id: $0) },
                                     reportShow: { content, timeToDisplay in
                                         do {
                                             try DI.injectOrFail(InAppMessagesTracker.self)
                                                 .trackView(id: content.inAppId,
                                                            timeToDisplay: timeToDisplay,
                                                            tags: content.tags)
                                         } catch {
                                             Logger.common(message: "[EmbeddedBlock] Failed to track a show of in-app \(content.inAppId): \(error)",
                                                           level: .error, category: .embeddedBlocks)
                                         }
                                     },
                                     reportFailure: { [failureManager] content, reason, details in
                                         // Captured, not read through the factory: a provider outliving it
                                         // would otherwise drop the failure it is reporting.
                                         Self.report(failure: reason, details: details, for: content, to: failureManager)
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
