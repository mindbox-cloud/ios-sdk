//
//  EmbeddedBlockActionRouter.swift
//  Mindbox
//
//  Created by vailence on 06.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit
import MindboxLogger

protocol EmbeddedBlockActionHandling: AnyObject {
    func handle(_ action: EmbeddedBlockPageAction)
}

final class EmbeddedBlockActionRouter: EmbeddedBlockActionHandling {

    private enum ActionType {
        static let openUrl = "openUrl"
    }

    func handle(_ action: EmbeddedBlockPageAction) {
        switch action.type {
        case ActionType.openUrl:
                // TODO(MOBILE-328): open the url once blocks move to the shared in-app bridge.
                Logger.common(message: "[EmbeddedBlock] openUrl is not handled yet, ignoring: \(action.type)",
                              category: .embeddedBlocks)
        default:
            Logger.common(message: "[EmbeddedBlock] Unknown page action: \(action.type)",
                          category: .embeddedBlocks)
        }
    }

    // TODO: - Will reuse webView route logic from inapps
}
