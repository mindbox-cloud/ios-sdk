//
//  EmbeddedBlockDeferredAnswers.swift
//  Mindbox
//
//  Created by Sergei Semko on 08.10.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

/// What a block keeps instead of applying it as it comes: a parked answer, a held collapse and a start waiting for the
/// return's session check. Main thread only, like the provider that owns it.
struct EmbeddedBlockDeferredAnswers {

    /// A collapse of a block that shows content: nothing changes on screen until the user leaves, and it lands then.
    enum HeldCollapse {

        /// The place answered nothing; what it tells the analytics went when it arrived.
        case placeAnswer(EmbeddedBlockPlaceAnswer)

        /// The page reported it draws nothing.
        case emptyPage

        var state: EmbeddedBlockState? {
            guard case .placeAnswer(let answer) = self else { return .empty }

            return answer.resolution.collapse?.state
        }
    }

    /// Lifted by content from the place.
    private var heldAnswer: EmbeddedBlockPlaceAnswer?

    /// Lifted only by the page drawing something: an answer naming the same page tells the page nothing new.
    private var isPageEmpty = false

    /// Reported when it arrived: its return only changes the state.
    private var parked: EmbeddedBlockPlaceAnswer?

    /// The block came on screen between a return and the end of that return's session check: it starts
    /// once the check ends, so its parked content and its first ask meet the session the check leaves.
    var isStartAwaitingSessionCheck = false

    /// No show goes while either holds.
    var isHolding: Bool { heldAnswer != nil || isPageEmpty }

    /// No data goes to a page its place no longer shows; a page that drew nothing still takes new data.
    var isHoldingPlaceAnswer: Bool { heldAnswer != nil }

    /// The place's answer over the page's report: its failure, if any, is what the block lands in.
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

    /// The page is gone or the block failed: no collapse is left to land.
    mutating func lift() {
        heldAnswer = nil
        isPageEmpty = false
    }

    /// The user left: the collapse lands now.
    mutating func takeHeld() -> HeldCollapse? {
        defer { lift() }

        return held
    }

    mutating func park(_ answer: EmbeddedBlockPlaceAnswer) {
        parked = answer
    }

    /// The parked answer for the return, unless its session has ended since: the session answers anew.
    mutating func takeParked(unlessEndedIn ledger: InappSessionLedger) -> EmbeddedBlockPlaceAnswer? {
        defer { parked = nil }

        guard let parked, !ledger.hasEnded(parked.sessionEpoch) else { return nil }

        return parked
    }

    /// A parked answer without content of a session that has not ended, left parked: it lands before the first frame
    /// while the start waits for the session check, and that start still decides by it.
    func parkedCollapse(unlessEndedIn ledger: InappSessionLedger) -> EmbeddedBlockPlaceAnswer? {
        guard let parked, parked.resolution.content == nil, !ledger.hasEnded(parked.sessionEpoch) else { return nil }

        return parked
    }

    /// The attempt is over: nothing parked, no start pending.
    mutating func reset() {
        parked = nil
        isStartAwaitingSessionCheck = false
    }
}
