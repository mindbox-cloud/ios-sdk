//
//  EmbeddedBlockResolver.swift
//  Mindbox
//
//  Created by vailence on 06.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

/// What a block resolves into.
enum EmbeddedBlockResolution: Equatable {

    /// There is an in-app for this block — the block loads its page.
    case content(EmbeddedBlockWebContent)

    /// Nothing to show: no in-app is set up for this place, the candidates were filtered out, or the
    /// config has not arrived yet. Not an error.
    case empty
}

/// Answers a single question: what does this block show.
///
/// Works on the main thread — that is where the container waits for the answer — while the selection
/// underneath runs on the in-app queue.
protocol EmbeddedBlockResolving: AnyObject {

    /// - Parameter trigger: The operation that caused this resolve, or `nil` when the registry asked
    ///   for other reasons. Targeting runs in the operation's context, which is what lets an
    ///   operation-targeted in-app reach the place.
    func resolve(_ place: String,
                 trigger: ApplicationEvent?,
                 completion: @escaping (EmbeddedBlockResolution) -> Void)
}

extension EmbeddedBlockResolving {

    func resolve(_ place: String, completion: @escaping (EmbeddedBlockResolution) -> Void) {
        resolve(place, trigger: nil, completion: completion)
    }
}

/// Where a block learns what it shows.
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
        // Checked on every resolve, not once: a debug override set while the screen is open must win
        // the next pull the same way the admin config it stands in for would.
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

    /// The in-app selected for this place, reduced to the webview layer the page needs.
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

    /// Turns the selection's answer into what the block does with it. The variants filter has already
    /// guaranteed the embedded variant carries exactly one webview layer.
    ///
    /// The params are not read — not even `stories`. Whether there is anything to draw is the page's
    /// own call, reported back as `contentRendered`, in sync with Android.
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
