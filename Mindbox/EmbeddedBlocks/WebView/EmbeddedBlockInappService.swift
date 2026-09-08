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

    /// Whether a config is in hand — what a never-answered block reports it was waiting on.
    var hasConfig: Bool { get }

    /// Which of `ids` the page of in-app `blockInappId` may draw, targeting checked and fetched like a place
    /// resolve; vouches for every targeted id as it answers. The answer mirrors the question — order and duplicates kept.
    /// Answers on the main thread.
    func showableInappIds(among ids: [String], askedBy blockInappId: String, completion: @escaping ([String]) -> Void)

    /// Deliberately unchecked: the page decided when it drew the in-app. Answers once, on the main thread.
    func showInapp(id: String, params: [String: JSONValue], completion: @escaping (Result<Void, ShowInAppRefusal>) -> Void)
}

final class EmbeddedBlockInappService: EmbeddedBlockInappServing {

    private let ask: (_ ids: [String], _ blockInappId: String, _ completion: @escaping ([String]) -> Void) -> Void
    private let fetchInappToShow: (_ id: String, _ params: [String: JSONValue], _ completion: @escaping (InAppFormData?) -> Void) -> Void
    private let showNow: (InAppFormData, _ processingDuration: TimeInterval, _ completion: @escaping (Result<Void, InAppPresentationError>) -> Void) -> Void
    private let configIsKnown: () -> Bool
    private let now: () -> TimeInterval

    var hasConfig: Bool { configIsKnown() }

    init(ask: ((_ ids: [String], _ blockInappId: String, _ completion: @escaping ([String]) -> Void) -> Void)? = nil,
         fetchInappToShow: ((_ id: String, _ params: [String: JSONValue], _ completion: @escaping (InAppFormData?) -> Void) -> Void)? = nil,
         showNow: ((InAppFormData, _ processingDuration: TimeInterval, _ completion: @escaping (Result<Void, InAppPresentationError>) -> Void) -> Void)? = nil,
         hasConfig: (() -> Bool)? = nil,
         now: @escaping () -> TimeInterval = { CACurrentMediaTime() }) {
        self.now = now
        self.configIsKnown = hasConfig ?? {
            DI.injectOrFail(InAppConfigurationManagerProtocol.self).hasConfig
        }
        self.ask = ask ?? { ids, blockInappId, completion in
            DI.injectOrFail(InAppConfigurationManagerProtocol.self).getShowableInappIds(ids, askedBy: blockInappId, completion)
        }
        self.fetchInappToShow = fetchInappToShow ?? { id, params, completion in
            DI.injectOrFail(InAppConfigurationManagerProtocol.self).getInAppToShowById(id, params: params, completion)
        }
        self.showNow = showNow ?? { formData, processingDuration, completion in
            DI.injectOrFail(InappScheduleManagerProtocol.self).showInAppNow(formData, processingDuration: processingDuration, completion: completion)
        }
    }

    func showInapp(id: String, params: [String: JSONValue], completion: @escaping (Result<Void, ShowInAppRefusal>) -> Void) {
        // The tap is the trigger: the fetch and the form build count into timeToDisplay, on the overlay pass's clock.
        let tappedAt = now()
        let answer = Self.onTheMainThread(completion)
        fetchInappToShow(id, params) { [showNow, now] formData in
            let processingDuration = now() - tappedAt

            guard let formData = formData else {
                Logger.common(message: "[EmbeddedBlock] Nothing to show for in-app \(id)",
                              level: .error, category: .embeddedBlocks)
                answer(.failure(.unknownInapp))
                return
            }

            showNow(formData, processingDuration) { outcome in
                answer(outcome.mapError { _ in .showFailed })
            }
        }
    }

    func showableInappIds(among ids: [String], askedBy blockInappId: String, completion: @escaping ([String]) -> Void) {
        guard !ids.isEmpty else {
            completion([])
            return
        }

        ask(ids, blockInappId, Self.onTheMainThread(completion))
    }

    private static func onTheMainThread<Answer>(_ deliver: @escaping (Answer) -> Void) -> (Answer) -> Void {
        { answer in
            guard Thread.isMainThread else {
                DispatchQueue.main.async { deliver(answer) }
                return
            }

            deliver(answer)
        }
    }
}
