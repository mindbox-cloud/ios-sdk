//
//  PollUntil.swift
//  MindboxTests
//
//  Created by Sergei Semko on 11.06.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

/// Polls `value` every `pollInterval` until `condition` accepts it or `deadline`
/// passes, and returns the last polled value either way: on timeout the caller's
/// own assertion fails with the real final state instead of hanging the test.
/// The deadline is only an upper bound for the genuine-failure case, sized for
/// slow CI machines - a passing test returns on the first satisfied poll.
/// Task cancellation also ends the poll: a cancelled `Task.sleep` throws
/// immediately, so without the explicit check the loop would busy-spin.
func pollUntil<T>(
    deadline: TimeInterval = 10,
    pollInterval: TimeInterval = 0.02,
    value: () throws -> T,
    condition: (T) -> Bool
) async rethrows -> T {
    let start = Date()
    while true {
        let current = try value()
        if condition(current) { return current }
        if Date().timeIntervalSince(start) > deadline { return current }
        try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        if Task.isCancelled { return current }
    }
}
