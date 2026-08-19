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

/// Regression coverage for App Group store-URL resolution.
///
/// Previously `FileManager.storeURL(for:databaseName:)` called `fatalError` when
/// the shared container was unavailable, which crashed the host straight through
/// the logger's `do/catch`. Now:
///  - `storeURL` *throws* for an unresolvable explicit group (defensive), and
///  - when no App Group is available `MBLoggerUtilitiesFetcher` returns `nil`, so
///    `LoggerDatabaseLoader` falls back to the app's local (caches) store and the
///    logger keeps working — just not in the shared container — instead of
///    crashing or disabling.
///
/// Note on the empty-string trigger: on the iOS Simulator
/// `containerURL(forSecurityApplicationGroupIdentifier:)` vends a container for any
/// *non-empty* identifier, so only the empty string deterministically yields a
/// `nil` container in a unit test.
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
        // Production path when MBLoggerUtilitiesFetcher reports no shared container
        // (returns nil): the loader must resolve a local store and keep the logger
        // working — not throw, not disable.
        let config = LoggerDatabaseLoaderConfig(
            modelName: "CDLogMessage",
            applicationGroupId: nil,
            storeURL: nil,
            descriptions: nil
        )
        let loader = LoggerDatabaseLoader(config)
        // No teardown: this resolves to the real Caches store that
        // `MBLoggerCoreDataManager.shared` uses, so destroying it would race sibling suites.
        let (container, _) = try loader.loadContainer()

        let stores = container.persistentStoreCoordinator.persistentStores
        #expect(!stores.isEmpty)

        let storeURL = try #require(stores.first?.url)
        #expect(storeURL.lastPathComponent == "CDLogMessage.sqlite")
        #expect(storeURL.path.contains("Caches"))
    }
}
