//
//  EmbeddedBlockWebViewProvider+ContentProcessLoss.swift
//  Mindbox
//
//  Created by Andrey Emtsov on 28.10.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

extension EmbeddedBlockWebViewProvider {

    var isAttemptOnALostPage: Bool { isAttemptAlive && page?.isContentProcessLost == true }

    func handleContentProcessTerminated() {
        guard content != nil, let pageShow, isAttemptAlive else { return }

        guard isStarted else {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': the page lost its web content process off screen — dropping it, a new attempt starts when the block is back",
                          level: .error, category: .embeddedBlocks)
            dropPage()
            return
        }

        guard !deferred.isHoldingPlaceAnswer else {
            landHeldCollapse(because: "the page held over an answer without content lost its web content process")
            return
        }

        guard appPresence.isPresent else {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': the page lost its web content process while the user cannot see it — rebuilding it once they can",
                          level: .error, category: .embeddedBlocks)
            return
        }

        guard !pageShow.isRebuildOfALostPage || isReady else {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': the rebuilt page lost its web content process before drawing — failing",
                          level: .error, category: .embeddedBlocks)
            handleLoadFailure("Web content process terminated")
            return
        }

        rebuildLostPage()
    }

    func rebuildLostPageIfDue() -> Bool {
        guard isAttemptOnALostPage else { return false }

        if deferred.isHoldingPlaceAnswer {
            landHeldCollapse(because: "the page held over an answer without content lost its web content process")
        } else {
            rebuildLostPage()
        }
        return true
    }

    func failSilentPageUnlessLost() {
        guard !isAttemptOnALostPage else {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': the page lost its web content process — not failing it by its timer, it is rebuilt once the user can see it",
                          category: .embeddedBlocks)
            return
        }

        failSilentPage()
    }

    private func rebuildLostPage() {
        guard let content, let pageShow else { return }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': the page lost its web content process — rebuilding it",
                      level: .error, category: .embeddedBlocks)
        buildPage(with: content, sessionEpoch: pageShow.confirmedEpoch, processingDuration: pageShow.processingDurationOfALostPage, isRebuildOfALostPage: true)
    }

    func processingDuration(ofARebuildFor answer: EmbeddedBlockPlaceAnswer) -> TimeInterval {
        guard isAttemptOnALostPage, let pageShow, let content, answer.sessionEpoch == pageShow.confirmedEpoch,
              answer.resolution.content?.isSamePage(as: content) == true else { return answer.processingDuration }

        return pageShow.processingDurationOfALostPage
    }
}
