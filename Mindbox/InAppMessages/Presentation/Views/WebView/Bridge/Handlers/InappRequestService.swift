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

    var hasConfig: Bool { get }

    func showableInappIds(among ids: [String], askedBy requesterInappId: String, completion: @escaping ([String]) -> Void)

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

    private let ask: (_ ids: [String], _ requesterInappId: String, _ completion: @escaping ([String]) -> Void) -> Void
    private let fetchInappToShow: (_ id: String, _ params: [String: JSONValue], _ completion: @escaping (InAppFormData?) -> Void) -> Void
    private let showNow: ShowNow
    private let configIsKnown: () -> Bool
    private let now: () -> TimeInterval

    var hasConfig: Bool { configIsKnown() }

    init(ask: ((_ ids: [String], _ requesterInappId: String, _ completion: @escaping ([String]) -> Void) -> Void)? = nil,
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

    func showableInappIds(among ids: [String], askedBy requesterInappId: String, completion: @escaping ([String]) -> Void) {
        guard !ids.isEmpty else {
            completion([])
            return
        }

        ask(ids, requesterInappId, Self.onTheMainThread(completion))
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
