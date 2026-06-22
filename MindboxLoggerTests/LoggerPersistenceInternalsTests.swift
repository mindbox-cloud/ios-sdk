//
//  LoggerPersistenceInternalsTests.swift
//  MindboxLoggerTests
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
import CoreData
@testable import MindboxLogger

@Suite("Logger persistence internals", .tags(.storage, .storageState))
struct LoggerPersistenceInternalsTests {

    @Test("LoggerDatabaseLoaderError.modelNotFound has an actionable description")
    func loaderErrorDescription() throws {
        let error = LoggerDatabaseLoaderError.modelNotFound(modelName: "CDLogMessage")
        let description = try #require(error.errorDescription)
        #expect(description.contains("CDLogMessage.momd"))
        #expect(description.localizedCaseInsensitiveContains("not found"))
    }

    #if DEBUG
    @Test("MBLoggerCoreDataManager debug introspection hooks are wired")
    func debugIntrospection() {
        let manager = MBLoggerCoreDataManager.makeIsolated()
        MBLoggerCoreDataManager.waitUntilReady(manager)

        #expect(manager.debugStorageState == .enabled)
        #expect(manager.debugLogBufferCount == 0)
        #expect(manager.debugLogBufferCapacity >= manager.debugBatchSize)

        // getter/setter round-trips
        let context = manager.debugContext
        manager.debugContext = context
        let state = manager.debugStorageState
        manager.debugStorageState = state
        #expect(manager.debugStorageState == state)

        manager.debugWriteBufferToCD()
        MBLoggerCoreDataManager.drainQueue(manager)
    }
    #endif
}
