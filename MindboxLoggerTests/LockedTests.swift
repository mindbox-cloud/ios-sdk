//
//  LockedTests.swift
//  MindboxLoggerTests
//
//  Created by Sergei Semko on 18.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
@testable import MindboxLogger

@Suite("Locked property wrapper", .tags(.concurrency))
struct LockedTests {

    @Locked private var flag = false
    @Locked private var counter = 0

    @Test("Reads back what was written")
    func readsBackWrites() {
        flag = true
        #expect(flag == true)

        counter = 42
        #expect(counter == 42)
    }

    @Test("exchange returns the old value and stores the new one")
    func exchangeSwapsAtomically() {
        flag = true

        #expect($flag.exchange(false) == true)
        #expect(flag == false)
        #expect($flag.exchange(false) == false)
    }

    @Test("mutate keeps every concurrent insert, where mutating through the value loses some")
    func mutateKeepsEveryConcurrentInsert() {
        let inserts = 500
        let set = Locked(wrappedValue: Set<Int>())

        DispatchQueue.concurrentPerform(iterations: inserts) { index in
            set.mutate { (value: inout Set<Int>) -> Void in
                value.insert(index)
            }
        }

        #expect(set.wrappedValue.count == inserts)
    }

    // Real threads behind a start gate: a read-then-write `exchange` only misbehaves with two
    // callers inside it at once, and one raised flag makes each round a single race — hence rounds.
    @Test("A raised flag is consumed by exactly one of the racing threads")
    func exchangeHandsTheFlagToExactlyOneTaker() {
        let racers = max(4, ProcessInfo.processInfo.activeProcessorCount * 2)

        for _ in 0..<100 {
            let raised = Locked(wrappedValue: true)
            let takes = TakeCounter()
            let openGate = DispatchTime.now() + .milliseconds(1)

            DispatchQueue.concurrentPerform(iterations: racers) { _ in
                while DispatchTime.now() < openGate { }

                if raised.exchange(false) {
                    takes.record()
                }
            }

            #expect(takes.total == 1)
        }
    }
}

/// Counts with its own lock: counting through `Locked` is a locked read then a locked write, which
/// would swallow the very races this test is looking for.
private final class TakeCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var takes = 0

    func record() {
        lock.lock()
        takes += 1
        lock.unlock()
    }

    var total: Int {
        lock.lock()
        defer { lock.unlock() }
        return takes
    }
}
