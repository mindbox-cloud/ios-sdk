//
//  NSManagedObjectContextExtensionTests.swift
//  MindboxLoggerTests
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
import CoreData
@testable import MindboxLogger

@Suite("NSManagedObjectContext perform helpers", .tags(.storage))
struct NSManagedObjectContextExtensionTests {

    private struct TestError: Error {}

    private func makeContext() -> NSManagedObjectContext {
        NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
    }

    @Test("executePerformAndWait returns the block result")
    func executeReturnsValue() {
        let context = makeContext()
        let result = context.executePerformAndWait { 21 + 21 }
        #expect(result == 42)
    }

    @Test("executePerformAndWait rethrows the block error")
    func executeRethrows() {
        let context = makeContext()
        #expect(throws: TestError.self) {
            try context.executePerformAndWait { throw TestError() }
        }
    }

    @Test("mindboxPerformAndWait returns the block result through the helper")
    func mindboxReturnsValue() {
        let context = makeContext()
        let result = context.mindboxPerformAndWait { "ok" }
        #expect(result == "ok")
    }

    @Test("mindboxPerformAndWait rethrows the block error through the rescue path")
    func mindboxRethrows() {
        let context = makeContext()
        #expect(throws: TestError.self) {
            try context.mindboxPerformAndWait { throw TestError() }
        }
    }
}
