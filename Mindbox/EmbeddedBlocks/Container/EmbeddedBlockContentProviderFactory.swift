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

    init(registry: EmbeddedBlockPlaceRegistering,
         feed: EmbeddedBlockFeedServing) {
        self.registry = registry
        self.feed = feed
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
                                     reportFailure: { content, reason, details in
                                         // Sent right away rather than buffered: a block's failure does not
                                         // belong to a selection pass, and nothing else will flush it.
                                         let manager = DI.injectOrFail(InappShowFailureManagerProtocol.self)
                                         manager.addFailure(inappId: content.inAppId,
                                                            reason: reason,
                                                            details: details,
                                                            tags: content.tags)
                                         manager.sendFailures()
                                     })
    }
}
