//
//  EmbeddedBlockInappService.swift
//  Mindbox
//
//  Created by Sergei Semko on 8/13/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import QuartzCore
import MindboxLogger

protocol EmbeddedBlockInappServing: AnyObject {

    /// Whether the SDK has a config to answer blocks from — a block the SDK never answered reports
    /// which of the two it was waiting on.
    var hasConfig: Bool { get }

    /// Which of `ids` the page of in-app `blockInappId` may draw: the SDK checks each one's targeting,
    /// fetching what that needs like a place resolve, and vouches for the allowed ones as it answers.
    /// The answer mirrors the question — order and duplicates kept.
    func showableInappIds(among ids: [String], askedBy blockInappId: String, completion: @escaping ([String]) -> Void)

    /// Deliberately unchecked: whether to offer the in-app was decided when the page drew it.
    func showInapp(id: String, params: [String: JSONValue])
}

final class EmbeddedBlockInappService: EmbeddedBlockInappServing {

    private let ask: (_ ids: [String], _ blockInappId: String, _ completion: @escaping ([String]) -> Void) -> Void
    private let fetchInappToShow: (_ id: String, _ params: [String: JSONValue], _ completion: @escaping (InAppFormData?) -> Void) -> Void
    private let showNow: (InAppFormData, _ processingDuration: TimeInterval) -> Void
    private let configIsKnown: () -> Bool

    var hasConfig: Bool { configIsKnown() }

    init(ask: ((_ ids: [String], _ blockInappId: String, _ completion: @escaping ([String]) -> Void) -> Void)? = nil,
         fetchInappToShow: ((_ id: String, _ params: [String: JSONValue], _ completion: @escaping (InAppFormData?) -> Void) -> Void)? = nil,
         showNow: ((InAppFormData, _ processingDuration: TimeInterval) -> Void)? = nil,
         hasConfig: (() -> Bool)? = nil) {
        self.configIsKnown = hasConfig ?? {
            DI.injectOrFail(InAppConfigurationManagerProtocol.self).hasConfig
        }
        self.ask = ask ?? { ids, blockInappId, completion in
            DI.injectOrFail(InAppConfigurationManagerProtocol.self).getShowableInappIds(ids, askedBy: blockInappId, completion)
        }
        self.fetchInappToShow = fetchInappToShow ?? { id, params, completion in
            DI.injectOrFail(InAppConfigurationManagerProtocol.self).getInAppToShowById(id, params: params, completion)
        }
        self.showNow = showNow ?? { formData, processingDuration in
            DI.injectOrFail(InappScheduleManagerProtocol.self).showInAppNow(formData, processingDuration: processingDuration)
        }
    }

    func showInapp(id: String, params: [String: JSONValue]) {
        // The tap is the trigger: the fetch and the form build count into timeToDisplay, on the overlay pass's clock.
        let tappedAt = CACurrentMediaTime()
        fetchInappToShow(id, params) { [showNow] formData in
            let processingDuration = CACurrentMediaTime() - tappedAt

            guard let formData = formData else {
                Logger.common(message: "[EmbeddedBlock] Nothing to show for in-app \(id)",
                              level: .error, category: .embeddedBlocks)
                return
            }

            showNow(formData, processingDuration)
        }
    }

    func showableInappIds(among ids: [String], askedBy blockInappId: String, completion: @escaping ([String]) -> Void) {
        guard !ids.isEmpty else {
            completion([])
            return
        }

        ask(ids, blockInappId) { allowed in
            // The selection answers off the main thread; the page is written to from it.
            guard Thread.isMainThread else {
                DispatchQueue.main.async {
                    completion(allowed)
                }
                return
            }

            completion(allowed)
        }
    }
}
