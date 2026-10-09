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

    /// Nothing changes on screen until the user leaves, and the collapse waits for their return.
    private(set) var held: EmbeddedBlockPlaceAnswer?

    /// Reported when it arrived: its return only changes the state.
    private var parked: EmbeddedBlockPlaceAnswer?

    /// The block came on screen between a return and the end of that return's session check: it starts
    /// once the check ends, so its parked answer and its first ask meet the session the check leaves.
    var isStartAwaitingSessionCheck = false

    var isHolding: Bool { held != nil }

    var parksContent: Bool { parked?.resolution.content != nil }

    mutating func hold(_ answer: EmbeddedBlockPlaceAnswer) {
        held = answer
    }

    mutating func lift() {
        held = nil
    }

    mutating func park(_ answer: EmbeddedBlockPlaceAnswer) {
        parked = answer
    }

    /// The user left: a held collapse waits for the return, its analytics already told.
    mutating func parkHeld() -> Bool {
        guard let held else { return false }

        parked = held
        self.held = nil
        return true
    }

    /// The parked answer for the return, unless its session has ended since: the session answers anew.
    mutating func takeParked(unlessEndedIn ledger: InappSessionLedger) -> EmbeddedBlockPlaceAnswer? {
        defer { parked = nil }

        guard let parked, !ledger.hasEnded(parked.sessionEpoch) else { return nil }

        return parked
    }

    /// The attempt is over: nothing parked, no start pending.
    mutating func reset() {
        parked = nil
        isStartAwaitingSessionCheck = false
    }
}
