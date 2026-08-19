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
    func showableInappIds(among ids: [String], completion: @escaping (FeedAnswer) -> Void)

    /// Deliberately unchecked: whether to offer the in-app was decided when the page drew it.
    func showInapp(id: String, params: [String: JSONValue])
}

final class EmbeddedBlockFeedService: EmbeddedBlockFeedServing {

    private let ask: (_ ids: [String], _ completion: @escaping (FeedAnswer) -> Void) -> Void
    private let fetchInappToShow: (_ id: String, _ params: [String: JSONValue], _ completion: @escaping (InAppFormData?) -> Void) -> Void
    private let showNow: (InAppFormData) -> Void

    init(ask: ((_ ids: [String], _ completion: @escaping (FeedAnswer) -> Void) -> Void)? = nil,
         fetchInappToShow: ((_ id: String, _ params: [String: JSONValue], _ completion: @escaping (InAppFormData?) -> Void) -> Void)? = nil,
         showNow: ((InAppFormData) -> Void)? = nil) {
        self.ask = ask ?? { ids, completion in
            DI.injectOrFail(InAppConfigurationManagerProtocol.self).getShowableInappIds(ids, completion)
        }
        self.fetchInappToShow = fetchInappToShow ?? { id, params, completion in
            DI.injectOrFail(InAppConfigurationManagerProtocol.self).getInAppToShowById(id, params: params, completion)
        }
        self.showNow = showNow ?? { formData in
            DI.injectOrFail(InappScheduleManagerProtocol.self).showInAppNow(formData)
        }
    }

    func showInapp(id: String, params: [String: JSONValue]) {
        fetchInappToShow(id, params) { [showNow] formData in
            guard let formData = formData else {
                Logger.common(message: "[EmbeddedBlock] Nothing to show for in-app \(id)",
                              level: .error, category: .embeddedBlocks)
                return
            }

            showNow(formData)
        }
    }

    func showableInappIds(among ids: [String], completion: @escaping (FeedAnswer) -> Void) {
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
