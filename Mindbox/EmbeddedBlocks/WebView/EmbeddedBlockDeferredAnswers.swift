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

    var isStartAwaitingSessionCheck = false

    var isHolding: Bool { heldAnswer != nil || isPageEmpty }

    var held: HeldCollapse? { heldAnswer.map { .placeAnswer($0) } ?? (isPageEmpty ? .emptyPage : nil) }

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
    }

    mutating func takeHeld() -> HeldCollapse? {
        defer { lift() }

        return held
    }

    mutating func park(_ answer: EmbeddedBlockPlaceAnswer) {
        parked = answer
    }

    mutating func dropParked() {
        parked = nil
    }

    mutating func takeParked(unlessEndedIn ledger: InappSessionLedger) -> EmbeddedBlockPlaceAnswer? {
        defer { parked = nil }

        guard let parked, !ledger.hasEnded(parked.sessionEpoch) else { return nil }

        return parked
    }

    func parkedCollapse(unlessEndedIn ledger: InappSessionLedger) -> EmbeddedBlockPlaceAnswer? {
        guard let parked, parked.resolution.content == nil, !ledger.hasEnded(parked.sessionEpoch) else { return nil }

        return parked
    }

    mutating func reset() {
        parked = nil
        isStartAwaitingSessionCheck = false
    }
}
