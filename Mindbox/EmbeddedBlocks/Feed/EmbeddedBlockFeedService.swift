//
//  EmbeddedBlockFeedService.swift
//  Mindbox
//
//  Created by Sergei Semko on 8/13/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

/// The ids and the `Inapp.Targeting` behind them are deliberately apart: an answer the page never
/// receives has offered nothing, so the event belongs to the moment the answer reaches the page.
struct FeedAnswer {

    static let nothing = FeedAnswer(inappIds: [], vouch: {})

    /// The allowed ids: a subset of what the page asked about, in priority order.
    let inappIds: [String]

    /// Sends `Inapp.Targeting` for exactly those ids. Called once, by whoever delivered the answer.
    let vouch: () -> Void
}

protocol EmbeddedBlockFeedServing: AnyObject {

    /// Answered from what the session already fetched, never the network — an id whose targeting
    /// cannot be checked without one is cut: fail closed, in sync with Android.
    func renderableInappIds(among ids: [String], completion: @escaping (FeedAnswer) -> Void)

    /// Deliberately unchecked: whether to offer the in-app was decided when the page drew it.
    func showInapp(id: String, params: [String: JSONValue])
}

final class EmbeddedBlockFeedService: EmbeddedBlockFeedServing {

    private let ask: (_ ids: [String], _ completion: @escaping (FeedAnswer) -> Void) -> Void

    init(ask: ((_ ids: [String], _ completion: @escaping (FeedAnswer) -> Void) -> Void)? = nil) {
        self.ask = ask ?? { ids, completion in
            DI.injectOrFail(InAppConfigurationManagerProtocol.self).getRenderableInappIds(ids, completion)
        }
    }

    func showInapp(id: String, params: [String: JSONValue]) {
        DI.injectOrFail(InAppConfigurationManagerProtocol.self).getInAppToShowById(id, params: params) { formData in
            guard let formData = formData else {
                Logger.common(message: "[EmbeddedBlock] Nothing to show for in-app \(id)",
                              level: .error, category: .embeddedBlocks)
                return
            }

            DI.injectOrFail(InappScheduleManagerProtocol.self).showInAppNow(formData)
        }
    }

    func renderableInappIds(among ids: [String], completion: @escaping (FeedAnswer) -> Void) {
        guard !ids.isEmpty else {
            completion(.nothing)
            return
        }

        ask(ids) { answer in
            // The selection answers off the main thread; the page is written to from it.
            guard Thread.isMainThread else {
                DispatchQueue.main.async {
                    completion(answer)
                }
                return
            }

            completion(answer)
        }
    }
}
