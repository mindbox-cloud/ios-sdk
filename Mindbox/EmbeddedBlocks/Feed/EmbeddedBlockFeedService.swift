//
//  EmbeddedBlockFeedService.swift
//  Mindbox
//
//  Created by Sergei Semko on 8/13/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

/// The answer to a page's question about which in-apps it may draw.
///
/// The ids and the `Inapp.Targeting` behind them are deliberately apart: an answer the page never
/// receives has offered nothing, so the event belongs to the moment the answer reaches the page, not
/// to the moment the selection computed it.
struct FeedAnswer {

    /// Nothing allowed and nothing to vouch for — the answer when there is no config or no question.
    static let nothing = FeedAnswer(inappIds: [], vouch: {})

    /// The allowed ids: a subset of what the page asked about, in priority order.
    let inappIds: [String]

    /// Sends `Inapp.Targeting` for exactly those ids. Called once, by whoever delivered the answer.
    let vouch: () -> Void
}

/// Answers the questions a feed page cannot answer for itself.
///
/// A feed draws a list of in-apps, and which of them it is allowed to draw depends on targeting and
/// on the A/B pool — neither of which the page can see.
protocol EmbeddedBlockFeedServing: AnyObject {

    /// Which of `ids` may be drawn. Answered from what the session has already fetched, never from
    /// the network — an id whose targeting cannot be checked without one is cut (fail closed, the
    /// wire contract shared with Android).
    func renderableInappIds(among ids: [String], completion: @escaping (FeedAnswer) -> Void)

    /// Shows the in-app behind `id`, with `params` merged into its start payload.
    ///
    /// Nothing is checked on the way: display conditions and the history of shows belong to deciding
    /// whether to offer the in-app, and that was decided when the page drew it.
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

    /// Answers as soon as the selection queue gets to the question — there is no network on this
    /// path, so the page's three-second deadline is never in real danger. The page still owns its own
    /// patience, and what to do about a late answer is its call, not ours to pre-empt.
    func renderableInappIds(among ids: [String], completion: @escaping (FeedAnswer) -> Void) {
        guard !ids.isEmpty else {
            completion(.nothing)
            return
        }

        ask(ids) { answer in
            // The selection answers off the main thread and the page has to be written to from the
            // main thread, so the hop belongs here rather than in the caller. An answer already on
            // main is delivered as is — a needless runloop hop would only delay the page.
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
