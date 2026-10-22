//
//  EmbeddedBlockWebViewProvider+SessionRenewal.swift
//  Mindbox
//
//  Created by Sergei Semko on 22.10.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit
import MindboxLogger

extension EmbeddedBlockWebViewProvider {

    var isAwaitingAnswer: Bool { page == nil || isAwaitingTheSessionsAnswer }

    var isCoveredForTheSession: Bool { shownPageShow?.isRenewingSession == true || isAwaitingTheSessionsAnswer }

    var owesItsPageTheSessionsData: Bool {
        guard let shownPageShow, shownPageShow.isRenewingSession, shownPageShow.isRefreshDue else { return false }

        return !isAwaitingTheSessionsAnswer
    }

    var coveredPageView: UIView? { isCoveredForTheSession ? page?.view : nil }

    var isAwaitingDelayedContent: Bool { delayedInSession.map { !SessionTemporaryStorage.shared.ledger.hasEnded($0) } == true }

    private var isAwaitingTheSessionsAnswer: Bool {
        guard let shownPageShow else { return false }

        return SessionTemporaryStorage.shared.ledger.hasEnded(shownPageShow.confirmedEpoch)
    }

    private var shownPageShow: EmbeddedBlockPageShow? { isReady && page != nil ? pageShow : nil }

    func sessionChecked(startedAt: TimeInterval?, startsNewSession: Bool) {
        guard startsNewSession, isCoveredForTheSession else { return }
        guard isStarted else {
            onContentDelayed?()
            return
        }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': a new session began — the placeholder covers its content until the session's content is drawn",
                      category: .embeddedBlocks)
        cover()
    }

    func keepsTheCoverOverAnEmptyDraw() -> Bool {
        guard isAwaitingTheSessionsAnswer || owesItsPageTheSessionsData else { return false }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': the page drew nothing for a session that has ended — the placeholder stays until the new session's content is drawn",
                      category: .embeddedBlocks)
        return true
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
