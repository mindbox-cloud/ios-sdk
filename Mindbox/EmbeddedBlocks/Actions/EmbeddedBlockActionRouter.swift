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

protocol EmbeddedBlockURLOpening {
    func canOpen(_ url: URL) -> Bool
    func open(_ url: URL)
}

final class EmbeddedBlockSystemURLOpener: EmbeddedBlockURLOpening {
    func canOpen(_ url: URL) -> Bool {
        UIApplication.shared.canOpenURL(url)
    }

    func open(_ url: URL) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}

final class EmbeddedBlockActionRouter: EmbeddedBlockActionHandling {

    private enum ActionType {
        static let openUrl = "openUrl"
    }

    /// Веб-адрес — это переход по контенту, и его странице позволено открывать всегда.
    private enum WebScheme {
        static let all: Set<String> = ["https"]
    }

    private let urlOpener: EmbeddedBlockURLOpening

    init(urlOpener: EmbeddedBlockURLOpening = EmbeddedBlockSystemURLOpener()) {
        self.urlOpener = urlOpener
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
