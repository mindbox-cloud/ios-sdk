//
//  PollUntil.swift
//  MindboxTests
//
//  Created by Sergei Semko on 11.06.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

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
