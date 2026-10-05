//
//  InappRequestService.swift
//  Mindbox
//
//  Created by Sergei Semko on 8/13/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import QuartzCore
import MindboxLogger

protocol InappRequestServing: AnyObject {

    /// Whether a config is in hand — what a never-answered block reports it was waiting on.
    var hasConfig: Bool { get }

    /// Which of `ids` the page of in-app `askerInappId` may draw, targeting checked and fetched like a place
    /// resolve; vouches for every targeted id as it answers. The answer mirrors the question — order and duplicates kept.
    /// Answers on the main thread.
    func showableInappIds(among ids: [String], askedBy askerInappId: String, completion: @escaping ([String]) -> Void)

    /// Deliberately unchecked: the page decided when it drew the in-app. Answers once, on the main thread.
    func showInapp(id: String,
                   params: [String: JSONValue],
                   proceedIf askerIsAlive: @escaping () -> Bool,
                   completion: @escaping (Result<Void, BridgeErrorCode>) -> Void)
}

final class InappRequestService: InappRequestServing {

    typealias ShowNow = (InAppFormData,
                         _ processingDuration: TimeInterval,
                         _ askerIsAlive: @escaping () -> Bool,
                         _ completion: @escaping (Result<Void, InappShowNowError>) -> Void) -> Void

    private let ask: (_ ids: [String], _ askerInappId: String, _ completion: @escaping ([String]) -> Void) -> Void
    private let fetchInappToShow: (_ id: String, _ params: [String: JSONValue], _ completion: @escaping (InAppFormData?) -> Void) -> Void
    private let showNow: ShowNow
    private let configIsKnown: () -> Bool
    private let now: () -> TimeInterval

    var hasConfig: Bool { configIsKnown() }

    init(ask: ((_ ids: [String], _ askerInappId: String, _ completion: @escaping ([String]) -> Void) -> Void)? = nil,
         fetchInappToShow: ((_ id: String, _ params: [String: JSONValue], _ completion: @escaping (InAppFormData?) -> Void) -> Void)? = nil,
         showNow: ShowNow? = nil,
         hasConfig: (() -> Bool)? = nil,
         now: @escaping () -> TimeInterval = { CACurrentMediaTime() }) {
        self.now = now
        self.configIsKnown = hasConfig ?? {
            DI.injectOrFail(InAppConfigurationManagerProtocol.self).hasConfig
        }
        self.ask = ask ?? { ids, askerInappId, completion in
            DI.injectOrFail(InAppConfigurationManagerProtocol.self).getShowableInappIds(ids, askedBy: askerInappId, completion)
        }
        self.fetchInappToShow = fetchInappToShow ?? { id, params, completion in
            DI.injectOrFail(InAppConfigurationManagerProtocol.self).getInAppToShowById(id, params: params, completion)
        }
        self.showNow = showNow ?? { formData, processingDuration, askerIsAlive, completion in
            DI.injectOrFail(InappScheduleManagerProtocol.self).showInAppNow(formData,
                                                                            processingDuration: processingDuration,
                                                                            proceedIf: askerIsAlive,
                                                                            completion: completion)
        }
    }

    func showInapp(id: String,
                   params: [String: JSONValue],
                   proceedIf askerIsAlive: @escaping () -> Bool,
                   completion: @escaping (Result<Void, BridgeErrorCode>) -> Void) {
        // The tap is the trigger: the fetch and the form build count into timeToDisplay, on the overlay pass's clock.
        let tappedAt = now()
        let answer = Self.onTheMainThread(completion)
        fetchInappToShow(id, params) { [showNow, now] formData in
            let processingDuration = now() - tappedAt

            guard let formData = formData else {
                Logger.common(message: "[InappRequestService] Nothing to show for in-app \(id)",
                              level: .error, category: .inAppMessages)
                answer(.failure(.unknownInapp))
                return
            }

            showNow(formData, processingDuration, askerIsAlive) { outcome in
                answer(outcome.mapError(\.bridgeErrorCode))
            }
        }
    }

    func showableInappIds(among ids: [String], askedBy askerInappId: String, completion: @escaping ([String]) -> Void) {
        guard !ids.isEmpty else {
            completion([])
            return
        }

        ask(ids, askerInappId, Self.onTheMainThread(completion))
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

private extension InappShowNowError {
    var bridgeErrorCode: BridgeErrorCode {
        switch self {
        case .askerLeft:
            return .notVisible
        case .presentationFailed:
            return .showFailed
        }
    }
}
