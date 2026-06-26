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

        // Setters actually persist the value: flip to a distinct value, assert, restore.
        let originalState = manager.debugStorageState
        manager.debugStorageState = .disabled
        #expect(manager.debugStorageState == .disabled)
        manager.debugStorageState = originalState
        #expect(manager.debugStorageState == originalState)

        let originalContext = manager.debugContext
        manager.debugContext = nil
        #expect(manager.debugContext == nil)
        manager.debugContext = originalContext
        #expect(manager.debugContext === originalContext)

        manager.debugWriteBufferToCD()
        MBLoggerCoreDataManager.drainQueue(manager)
    }
    #endif
}
