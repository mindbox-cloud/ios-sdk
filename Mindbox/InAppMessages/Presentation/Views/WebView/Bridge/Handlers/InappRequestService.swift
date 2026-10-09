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

    /// Which of `ids` the page of in-app `requesterInappId` may draw, targeting checked and fetched like a place
    /// resolve; vouches for every targeted id as it answers. The answer mirrors the question — order and duplicates kept.
    /// With no config to answer from, the question is refused with `internalError`. Answers on the main thread.
    func showableInappIds(among ids: [String], askedBy requesterInappId: String, completion: @escaping (Result<[String], BridgeErrorCode>) -> Void)

    /// Deliberately unchecked: the page decided when it drew the in-app. Answers once, on the main thread.
    func showInapp(id: String,
                   params: [String: JSONValue],
                   proceedIf requesterIsActive: @escaping () -> Bool,
                   completion: @escaping (Result<Void, BridgeErrorCode>) -> Void)
}

final class InappRequestService: InappRequestServing {

    typealias ShowNow = (InAppFormData,
                         _ processingDuration: TimeInterval,
                         _ requesterIsActive: @escaping () -> Bool,
                         _ completion: @escaping (Result<Void, InappShowNowError>) -> Void) -> Void

    private let ask: (_ ids: [String], _ requesterInappId: String, _ completion: @escaping ([String]?) -> Void) -> Void
    private let fetchInappToShow: (_ id: String, _ params: [String: JSONValue], _ completion: @escaping (InAppFormData?) -> Void) -> Void
    private let showNow: ShowNow
    private let configIsKnown: () -> Bool
    private let now: () -> TimeInterval

    var hasConfig: Bool { configIsKnown() }

    init(ask: ((_ ids: [String], _ requesterInappId: String, _ completion: @escaping ([String]?) -> Void) -> Void)? = nil,
         fetchInappToShow: ((_ id: String, _ params: [String: JSONValue], _ completion: @escaping (InAppFormData?) -> Void) -> Void)? = nil,
         showNow: ShowNow? = nil,
         hasConfig: (() -> Bool)? = nil,
         now: @escaping () -> TimeInterval = { CACurrentMediaTime() }) {
        self.now = now
        self.configIsKnown = hasConfig ?? {
            DI.injectOrFail(InAppConfigurationManagerProtocol.self).hasConfig
        }
        self.ask = ask ?? { ids, requesterInappId, completion in
            DI.injectOrFail(InAppConfigurationManagerProtocol.self).getShowableInappIds(ids, askedBy: requesterInappId, completion)
        }
        self.fetchInappToShow = fetchInappToShow ?? { id, params, completion in
            DI.injectOrFail(InAppConfigurationManagerProtocol.self).getInAppToShowById(id, params: params, completion)
        }
        self.showNow = showNow ?? { formData, processingDuration, requesterIsActive, completion in
            DI.injectOrFail(InappScheduleManagerProtocol.self).showInAppNow(formData,
                                                                            processingDuration: processingDuration,
                                                                            proceedIf: requesterIsActive,
                                                                            completion: completion)
        }
    }

    func showInapp(id: String,
                   params: [String: JSONValue],
                   proceedIf requesterIsActive: @escaping () -> Bool,
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

            showNow(formData, processingDuration, requesterIsActive) { outcome in
                answer(outcome.mapError(\.bridgeErrorCode))
            }
        }
    }

    func showableInappIds(among ids: [String], askedBy requesterInappId: String, completion: @escaping (Result<[String], BridgeErrorCode>) -> Void) {
        guard !ids.isEmpty else {
            completion(.success([]))
            return
        }

        let answer = Self.onTheMainThread(completion)
        ask(ids, requesterInappId) { allowed in
            guard let allowed else {
                Logger.common(message: "[InappRequestService] No config to answer the page of in-app \(requesterInappId) from — refusing its question",
                              level: .error, category: .inAppMessages)
                answer(.failure(.internalError))
                return
            }

            answer(.success(allowed))
        }
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
        case .requesterGone:
            return .notVisible
        case .appInBackground, .presentationFailed:
            return .showFailed
        }
    }
}
