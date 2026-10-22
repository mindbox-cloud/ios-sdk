//
//  EmbeddedBlockWebViewProvider+PageRequests.swift
//  Mindbox
//
//  Created by Sergei Semko on 14.10.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

extension EmbeddedBlockWebViewProvider {

    func showInapp(id inappId: String, params: [String: JSONValue], askedFrom page: EmbeddedBlockPageHosting?, completion: @escaping (Result<Void, BridgeErrorCode>) -> Void) {
        guard isShowing(page) else {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': refused a show request from a block that is not shown",
                          category: .embeddedBlocks)
            completion(.failure(.notVisible))
            return
        }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': page asks to show in-app \(inappId) with \(params.count) param(s)",
                      category: .embeddedBlocks)

        inappService.showInapp(id: inappId, params: params, proceedIf: { [weak self, weak page] in self?.isShowing(page) ?? false }, completion: completion)
    }

    private func isShowing(_ page: EmbeddedBlockPageHosting?) -> Bool {
        isStarted && isAttemptAlive && !isCoveredForTheSession && page != nil && self.page === page
    }

    func answerShowableQuestion(_ ids: [String], askedFrom page: EmbeddedBlockPageHosting?, completion: @escaping ([String]) -> Void) {
        guard let content, page != nil, self.page === page else { return }

        inappService.showableInappIds(among: ids, askedBy: content.inAppId) { [weak self, weak page] answer in
            guard let self, page != nil, self.page === page else { return }

            completion(answer)
        }
    }
}
