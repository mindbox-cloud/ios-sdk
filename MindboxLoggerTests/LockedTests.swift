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

@Suite("Locked property wrapper", .tags(.storage))
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

    @Test("A raised flag is consumed by exactly one of the racing threads")
    func exchangeHandsTheFlagToExactlyOneTaker() async {
        let raised = Locked(wrappedValue: true)

        let winners = await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<32 {
                group.addTask { raised.exchange(false) }
            }
            return await group.reduce(into: 0) { $0 += $1 ? 1 : 0 }
        }

        #expect(winners == 1)
    }
}
