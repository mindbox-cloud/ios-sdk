//
//  FileManagerStoreURLTests.swift
//  MindboxLoggerTests
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
import CoreData
@testable import MindboxLogger

@Suite("FileManager.storeURL App Group resolution", .tags(.storage, .storageState))
struct FileManagerStoreURLTests {

    @Test("storeURL throws .containerUnavailable instead of crashing when the container is unavailable")
    func throwsWhenContainerUnavailable() {
        #expect(throws: FileManager.StoreURLError.containerUnavailable(appGroup: "")) {
            try FileManager.storeURL(for: "", databaseName: "CDLogMessage")
        }
    }

    @Test("Thrown error carries a localized, actionable description naming the group")
    func errorDescriptionNamesTheGroup() throws {
        let group = "group.cloud.Mindbox.NonExistent.AppGroup.For.Repro"
        let error = FileManager.StoreURLError.containerUnavailable(appGroup: group)

        let description = try #require(error.errorDescription)
        #expect(description.contains(group))
        #expect(description.localizedCaseInsensitiveContains("unavailable"))
    }

    @Test("Loader falls back to local storage and stays enabled when no App Group is available")
    func loaderFallsBackToLocalStorageWhenNoAppGroup() throws {
        let config = LoggerDatabaseLoaderConfig(
            modelName: "CDLogMessage",
            applicationGroupId: nil,
            storeURL: nil,
            descriptions: nil
        )
        let loader = LoggerDatabaseLoader(config)
        let (container, _) = try loader.loadContainer()

        let stores = container.persistentStoreCoordinator.persistentStores
        #expect(!stores.isEmpty)

        let storeURL = try #require(stores.first?.url)
        #expect(storeURL.lastPathComponent == "CDLogMessage.sqlite")
        #expect(storeURL.path.contains("Caches"))
    }
}
