//
//  EmbeddedBlockResolver.swift
//  Mindbox
//
//  Created by vailence on 06.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

struct EmbeddedBlockResolutionFailure: Equatable {

    let inAppId: String

    let tags: [String: String]?

    let reason: InAppShowFailureReason

    let details: String
}

enum EmbeddedBlockResolution: Equatable {

    case content(EmbeddedBlockWebContent)

    case empty

    case failure(EmbeddedBlockResolutionFailure)

    case configUnavailable

    var content: EmbeddedBlockWebContent? {
        if case .content(let content) = self { return content }
        return nil
    }
}

/// Works on the main thread — that is where the container waits for the answer — while the selection
/// underneath runs on the in-app queue.
protocol EmbeddedBlockResolving: AnyObject {

    /// - Parameters:
    ///   - trigger: The operation that caused this resolve, if any. Targeting runs in its context —
    ///     that is what lets an operation-targeted in-app reach the place.
    ///   - completion: The answer and how long it took from this call, the wait for a config included.
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

        configurationManager.selectInappForPlace(place, trigger: trigger) { selection, processingDuration in
            completion(resolution(from: selection, place: place), processingDuration)
        }
    }

    static func resolution(from selection: EmbeddedPlaceSelection, place: String) -> EmbeddedBlockResolution {
        switch selection {
        case .decided(let inapp):
            return resolution(from: inapp, place: place)
        case .configUnavailable:
            return .configUnavailable
        }
    }

    /// No winner is an empty place. A winner that is not an embedded block, or one without a webview
    /// layer, is a broken config: the block fails instead of pretending there is nothing here. Whether
    /// there is anything to draw is the page's own call, reported back as `contentRendered`, in sync
    /// with Android.
    static func resolution(from inapp: InAppTransitionData?, place: String) -> EmbeddedBlockResolution {
        guard let inapp = inapp else {
            Logger.common(message: "[EmbeddedBlock] Nothing to show at place '\(place)'", category: .embeddedBlocks)
            return .empty
        }

        guard case .embedded(let embedded) = inapp.content else {
            return broken(inapp, "In-app \(inapp.inAppId) won place '\(place)' but is not an embedded block")
        }

        guard case .webview(let layer)? = embedded.content.background.layers.first else {
            return broken(inapp, "Embedded in-app \(inapp.inAppId) at place '\(place)' has no webview layer")
        }

        Logger.common(message: "[EmbeddedBlock] Place '\(place)' resolved to in-app \(inapp.inAppId)",
                      category: .embeddedBlocks)

        return .content(EmbeddedBlockWebContent(inAppId: inapp.inAppId,
                                                baseUrl: layer.baseUrl,
                                                contentUrl: layer.contentUrl,
                                                frequency: inapp.frequency,
                                                isPriority: inapp.isPriority,
                                                tags: inapp.tags,
                                                params: layer.params,
                                                delayTime: inapp.delayTime))
    }

    private static func broken(_ inapp: InAppTransitionData, _ details: String) -> EmbeddedBlockResolution {
        Logger.common(message: "[EmbeddedBlock] \(details) — failing the block", level: .error, category: .embeddedBlocks)

        return .failure(EmbeddedBlockResolutionFailure(inAppId: inapp.inAppId,
                                                       tags: inapp.tags,
                                                       reason: .unknownError,
                                                       details: details))
    }
}
