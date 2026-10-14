//
//  EmbeddedBlockDeferredAnswers.swift
//  Mindbox
//
//  Created by Sergei Semko on 08.10.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

struct EmbeddedBlockDeferredAnswers {

    enum HeldCollapse {

        case placeAnswer(EmbeddedBlockPlaceAnswer)

        case emptyPage

        var state: EmbeddedBlockState? {
            guard case .placeAnswer(let answer) = self else { return .empty }

            return answer.resolution.collapse?.state
        }
    }

    private var heldAnswer: EmbeddedBlockPlaceAnswer?

    private var isPageEmpty = false

    private var parked: EmbeddedBlockPlaceAnswer?

    private var parkedTimeOnScreen: ForegroundStopwatch?

    var contentAwaitingTheUser: EmbeddedBlockPlaceAnswer?

    var isStartAwaitingSessionCheck = false {
        didSet {
            if isStartAwaitingSessionCheck {
                parkedTimeOnScreen?.resume()
            } else {
                parkedTimeOnScreen?.suspend()
            }
        }
    }

    var isHolding: Bool { heldAnswer != nil || isPageEmpty }

    var isHoldingPlaceAnswer: Bool { heldAnswer != nil }

    var held: HeldCollapse? {
        heldAnswer.map { .placeAnswer($0) } ?? (isPageEmpty && contentAwaitingTheUser == nil && !parksContent ? .emptyPage : nil)
    }

    var parksContent: Bool { parked?.resolution.content != nil }

    mutating func hold(_ answer: EmbeddedBlockPlaceAnswer) {
        heldAnswer = answer
    }

    mutating func holdEmptyPage() {
        isPageEmpty = true
    }

    mutating func liftPlaceAnswer() {
        heldAnswer = nil
    }

    mutating func liftEmptyPage() {
        isPageEmpty = false
    }

    mutating func lift() {
        heldAnswer = nil
        isPageEmpty = false
        contentAwaitingTheUser = nil
    }

    mutating func takeHeld() -> HeldCollapse? {
        guard let held else { return nil }

        lift()
        return held
    }

    mutating func parkContentAwaitingTheUser(ifAlive isAttemptAlive: Bool, timedBy makeStopwatch: () -> ForegroundStopwatch) -> EmbeddedBlockPlaceAnswer? {
        defer { contentAwaitingTheUser = nil }

        guard isAttemptAlive, let unseen = contentAwaitingTheUser else { return nil }

        park(unseen.landedOffScreen(), overPageOf: nil, timedBy: makeStopwatch)
        return unseen
    }

    mutating func park(_ answer: EmbeddedBlockPlaceAnswer, overPageOf pageSession: Int?, timedBy makeStopwatch: () -> ForegroundStopwatch) {
        if let earlier = parked, let pageSession, answer.sessionEpoch > pageSession, earlier.sessionEpoch == answer.sessionEpoch,
           let inAppId = answer.resolution.content?.inAppId, earlier.resolution.content?.inAppId == inAppId {
            parked = answer.replacing(earlier)
            return
        }

        parked = answer
        parkedTimeOnScreen = makeStopwatch()
        if !isStartAwaitingSessionCheck {
            parkedTimeOnScreen?.suspend()
        }
    }

    mutating func dropParked() {
        parked = nil
        parkedTimeOnScreen = nil
    }

    mutating func takeParked(unlessEndedIn ledger: InappSessionLedger) -> EmbeddedBlockPlaceAnswer? {
        defer { dropParked() }

        guard let parked, !ledger.hasEnded(parked.sessionEpoch) else { return nil }

        return parked.with(processingDuration: parked.processingDuration + (parkedTimeOnScreen?.elapsed ?? 0))
    }

    var parkedCollapse: EmbeddedBlockPlaceAnswer? { parked?.resolution.content == nil ? parked : nil }

    mutating func reset() {
        dropParked()
        isStartAwaitingSessionCheck = false
    }
}
