//
//  EmbeddedBlockWebViewProvider+SessionRenewal.swift
//  Mindbox
//
//  Created by Sergei Semko on 22.10.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

extension EmbeddedBlockWebViewProvider {

    var isAwaitingAnswer: Bool { page == nil || isAwaitingTheSessionsAnswer }

    var isCoveredForTheSession: Bool { shownPageShow?.isRenewingSession == true || isAwaitingTheSessionsAnswer }

    private var isAwaitingTheSessionsAnswer: Bool {
        guard let shownPageShow else { return false }

        return SessionTemporaryStorage.shared.ledger.hasEnded(shownPageShow.confirmedEpoch)
    }

    private var shownPageShow: EmbeddedBlockPageShow? { isReady && page != nil ? pageShow : nil }

    func sessionChecked(startedAt: TimeInterval?, startsNewSession: Bool) {
        guard startsNewSession, isStarted, isCoveredForTheSession else { return }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': a new session began — the placeholder covers its content until the session's content is drawn",
                      category: .embeddedBlocks)
        cover()
    }

    func report(_ state: EmbeddedBlockState) {
        guard isCoveredForTheSession else {
            onStateChange?(state)
            return
        }

        cover()
    }

    private func cover() {
        onStateChange?(.loading)
        onContentArrived?()
    }
}
