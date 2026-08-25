//
//  EmbeddedBlockResolver.swift
//  Mindbox
//
//  Created by vailence on 06.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

enum EmbeddedBlockResolution: Equatable {

    case content(EmbeddedBlockWebContent)

    case empty
}

/// Works on the main thread — that is where the container waits for the answer — while the selection
/// underneath runs on the in-app queue.
protocol EmbeddedBlockResolving: AnyObject {

    /// - Parameters:
    ///   - trigger: The operation that caused this resolve, if any. Targeting runs in its context —
    ///     that is what lets an operation-targeted in-app reach the place.
    ///   - completion: The answer, with how long the selection worked on it once the config was there.
    ///     The block's `timeToDisplay` starts from that, like the overlay's from its pass.
    func resolve(_ place: String,
                 trigger: ApplicationEvent?,
                 completion: @escaping (EmbeddedBlockResolution, _ processingDuration: TimeInterval) -> Void)
}

typealias EmbeddedBlockContentLoading = (String, ApplicationEvent?, @escaping (EmbeddedBlockResolution, TimeInterval) -> Void) -> Void

final class EmbeddedBlockResolver: EmbeddedBlockResolving {

    private let load: EmbeddedBlockContentLoading

    init(load: @escaping EmbeddedBlockContentLoading = EmbeddedBlockResolver.loadFromConfig) {
        self.load = load
    }

    /// Answers are deliberately not cached. The config arrives after the app starts, so a remembered
    /// "nothing to show" would outlive the reason for it and leave the block empty until a restart.
    func resolve(_ place: String,
                 trigger: ApplicationEvent?,
                 completion: @escaping (EmbeddedBlockResolution, _ processingDuration: TimeInterval) -> Void) {
        load(place, trigger) { resolution, processingDuration in
            self.deliverOnMain(resolution, processingDuration, completion)
        }
    }

    private func deliverOnMain(_ resolution: EmbeddedBlockResolution,
                               _ processingDuration: TimeInterval,
                               _ completion: @escaping (EmbeddedBlockResolution, TimeInterval) -> Void) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                completion(resolution, processingDuration)
            }
            return
        }

        completion(resolution, processingDuration)
    }

    static func loadFromConfig(_ place: String,
                               trigger: ApplicationEvent?,
                               completion: @escaping (EmbeddedBlockResolution, TimeInterval) -> Void) {
        guard let configurationManager = DI.inject(InAppConfigurationManagerProtocol.self) else {
            Logger.common(message: "[EmbeddedBlock] No configuration manager, place '\(place)' resolves as empty",
                          level: .error, category: .embeddedBlocks)
            completion(.empty, 0)
            return
        }

        configurationManager.selectInappForPlace(place, trigger: trigger) { inapp, processingDuration in
            completion(resolution(from: inapp, place: place), processingDuration)
        }
    }

    /// The variants filter has already guaranteed exactly one webview layer. Whether there is anything
    /// to draw is the page's own call, reported back as `contentRendered`, in sync with Android.
    static func resolution(from inapp: InAppTransitionData?, place: String) -> EmbeddedBlockResolution {
        guard let inapp = inapp,
              case .embedded(let embedded) = inapp.content,
              case .webview(let layer)? = embedded.content.background.layers.first else {
            Logger.common(message: "[EmbeddedBlock] Nothing to show at place '\(place)'", category: .embeddedBlocks)
            return .empty
        }

        Logger.common(message: "[EmbeddedBlock] Place '\(place)' resolved to in-app \(inapp.inAppId)",
                      category: .embeddedBlocks)

        return .content(EmbeddedBlockWebContent(inAppId: inapp.inAppId,
                                                baseUrl: layer.baseUrl,
                                                contentUrl: layer.contentUrl,
                                                frequency: inapp.frequency,
                                                tags: inapp.tags,
                                                params: layer.params,
                                                delayTime: inapp.delayTime))
    }
}
