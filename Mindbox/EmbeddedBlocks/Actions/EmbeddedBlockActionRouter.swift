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
                print("embeddedBlock action")
                // TODO: - Add action here later
//            openUrl(from: action)
        default:
            Logger.common(message: "[EmbeddedBlock] Unknown page action: \(action.type)",
                          category: .embeddedBlocks)
        }
    }

    // TODO: - Will reuse webView route logic from inapps
}
