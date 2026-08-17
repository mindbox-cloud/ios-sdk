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

    /// - Parameter trigger: The operation that caused this resolve, if any. Targeting runs in its
    ///   context — that is what lets an operation-targeted in-app reach the place.
    func resolve(_ place: String,
                 trigger: ApplicationEvent?,
                 completion: @escaping (EmbeddedBlockResolution) -> Void)
}

typealias EmbeddedBlockContentLoading = (String, ApplicationEvent?, @escaping (EmbeddedBlockResolution) -> Void) -> Void

final class EmbeddedBlockResolver: EmbeddedBlockResolving {

    private let load: EmbeddedBlockContentLoading

    init(load: @escaping EmbeddedBlockContentLoading = EmbeddedBlockResolver.loadFromConfig) {
        self.load = load
    }

    /// Answers are deliberately not cached. The config arrives after the app starts, so a remembered
    /// "nothing to show" would outlive the reason for it and leave the block empty until a restart.
    func resolve(_ place: String,
                 trigger: ApplicationEvent?,
                 completion: @escaping (EmbeddedBlockResolution) -> Void) {
        if let overridden = EmbeddedBlockDebugOverrides.shared.resolution(for: place) {
            Logger.common(message: "[EmbeddedBlock] Place '\(place)' answered from a debug override",
                          category: .embeddedBlocks)
            deliverOnMain(overridden, completion)
            return
        }

        load(place, trigger) { resolution in
            self.deliverOnMain(resolution, completion)
        }
    }

    private func deliverOnMain(_ resolution: EmbeddedBlockResolution,
                               _ completion: @escaping (EmbeddedBlockResolution) -> Void) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                completion(resolution)
            }
            return
        }

        completion(resolution)
    }

    static func loadFromConfig(_ place: String,
                               trigger: ApplicationEvent?,
                               completion: @escaping (EmbeddedBlockResolution) -> Void) {
        guard let configurationManager = DI.inject(InAppConfigurationManagerProtocol.self) else {
            Logger.common(message: "[EmbeddedBlock] No configuration manager, place '\(place)' resolves as empty",
                          level: .error, category: .embeddedBlocks)
            completion(.empty)
            return
        }

        configurationManager.selectInappForPlace(place, trigger: trigger) { inapp in
            completion(resolution(from: inapp, place: place))
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
                                                params: layer.params))
    }
}
