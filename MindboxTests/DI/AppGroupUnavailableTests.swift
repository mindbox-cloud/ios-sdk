//
//  AppGroupUnavailableTests.swift
//  MindboxTests
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
import CoreData
import MindboxLogger
@testable import Mindbox

/// Core-SDK fallback: an unavailable App Group must degrade to local storage, not crash.
/// Serialized — the cases mutate global `MBInject` / `MBPersistenceStorage.defaults` / `MBPersistentContainer`.
@Suite("App Group unavailable — core SDK fallback", .serialized)
struct AppGroupUnavailableTests {

    /// Stub fetcher reporting an unavailable App Group (`""`), independent of the simulator's containers.
    private struct EmptyAppGroupUtilitiesFetcher: UtilitiesFetcher {
        var appVerson: String? { "1.0.0" }
        var sdkVersion: String? { "test" }
        var hostApplicationName: String? { "cloud.Mindbox.MindboxTests" }
        var applicationGroupIdentifier: String { "" }
        func getDeviceUUID(completion: @escaping (String) -> Void) { completion(UUID().uuidString) }
    }

    /// The getter used to `fatalError` on an unavailable container — a trap would tear down
    /// the runner, so simply reaching the assertion proves it's gone.
    @Test
    func coreFetcherResolvesWithoutTrapping() {
        let id = MBUtilitiesFetcher().applicationGroupIdentifier
        #expect(id.isEmpty || id.hasPrefix("group.cloud.Mindbox."))
    }

    @Test
    func persistenceStorageFallsBackToStandardWhenAppGroupEmpty() {
        // All three are global (and `MBPersistenceStorage(defaults:)` writes the static `.defaults`);
        // save/restore so this minimal container can't leak into later `.test`-mode tests.
        let savedBuilder = MBInject.buildTestContainer
        let savedMode = MBInject.mode
        let savedDefaults = MBPersistenceStorage.defaults
        defer {
            MBInject.buildTestContainer = savedBuilder
            MBInject.mode = savedMode
            MBPersistenceStorage.defaults = savedDefaults
        }

        MBInject.buildTestContainer = {
            let container = MBContainer()
            container.register(UtilitiesFetcher.self) { EmptyAppGroupUtilitiesFetcher() }
            return container.registerReplaceableUtilities()
        }
        MBInject.mode = .test

        let storage = DI.injectOrFail(PersistenceStorage.self)
        #expect(storage is MBPersistenceStorage)
        #expect(MBPersistenceStorage.defaults === UserDefaults.standard)
    }

    /// Unavailable App Group (nil id from the logger path, "" from the core fetcher) → the events
    /// store's directory must fall through to the app-local default rather than crash. Covers both
    /// `MBPersistentContainer.defaultDirectoryURL()` fallbacks: the nil guard and `containerURL("") ?? super`.
    @Test(arguments: [nil, ""] as [String?])
    func eventsStoreFallsBackToLocalDirectory(groupId: String?) {
        let saved = MBPersistentContainer.applicationGroupIdentifier
        defer { MBPersistentContainer.applicationGroupIdentifier = saved }

        MBPersistentContainer.applicationGroupIdentifier = groupId
        #expect(MBPersistentContainer.defaultDirectoryURL() == NSPersistentContainer.defaultDirectoryURL())
    }
}

/// Storage-transition reporter: reports only when install state is in BOTH stores; read-only.
@Suite("App Group storage-transition reporter")
struct AppGroupStorageTransitionReporterTests {

    private func makeStore(_ name: String, installed: Bool) -> UserDefaults {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        if installed {
            defaults.set("23.05.2026 10:00:00", forKey: MBPersistenceStorage.installationDataKey)
        }
        return defaults
    }

    @Test("Reports only when install state is in BOTH stores, and never mutates either store",
          arguments: [
            (active: true,  local: true,  expectReport: true),
            (active: false, local: true,  expectReport: false),
            (active: true,  local: false, expectReport: false),
            (active: false, local: false, expectReport: false),
          ])
    func reportsOnlyWhenInstalledInBothStores(active: Bool, local: Bool, expectReport: Bool) {
        let activeName = "test.appgroup.active.\(active).\(local)"
        let localName = "test.appgroup.local.\(active).\(local)"
        let activeStore = makeStore(activeName, installed: active)
        let localStore = makeStore(localName, installed: local)
        defer {
            activeStore.removePersistentDomain(forName: activeName)
            localStore.removePersistentDomain(forName: localName)
        }

        let reporter = AppGroupStorageTransitionReporter(activeDefaults: activeStore, localDefaults: localStore)

        #expect(reporter.reportIfNeeded() == expectReport)
        #expect(MBPersistenceStorage.isInstalled(in: localStore) == local)   // read-only: stores unchanged
        #expect(MBPersistenceStorage.isInstalled(in: activeStore) == active)
        #expect(reporter.reportIfNeeded() == expectReport)                   // not one-shot: re-fires while the fingerprint persists
    }

    @Test("No report in local fallback (App Group unavailable → active store IS the local store)")
    func noReportInFallback() {
        let name = "test.appgroup.fallback"
        let store = makeStore(name, installed: true)
        defer { store.removePersistentDomain(forName: name) }

        let didReport = AppGroupStorageTransitionReporter(activeDefaults: store, localDefaults: store)
            .reportIfNeeded()

        #expect(didReport == false)
        #expect(MBPersistenceStorage.isInstalled(in: store) == true)
    }

    /// The reporter relies on the App Group suite NOT reading through to `.standard`; otherwise
    /// `isInstalled(in: suite)` would be true whenever `.standard` holds the marker and it would
    /// mis-fire. A separately-registered suite is its own read domain, so this holds — the real
    /// provisioned-App-Group case was confirmed on device; the runner exercises the same isolation.
    @Test("A separate UserDefaults suite does not read through to .standard's install marker")
    func suiteDoesNotReadThroughToStandard() {
        let key = MBPersistenceStorage.installationDataKey
        let group = "group.cloud.Mindbox.ReadThroughProbe"
        let suite = UserDefaults(suiteName: group)!

        let savedStandard = UserDefaults.standard.object(forKey: key)
        defer {
            if let savedStandard { UserDefaults.standard.set(savedStandard, forKey: key) }
            else { UserDefaults.standard.removeObject(forKey: key) }
            suite.removePersistentDomain(forName: group)
        }

        suite.removePersistentDomain(forName: group)
        UserDefaults.standard.set("23.05.2026 10:00:00", forKey: key)  // marker only in .standard

        #expect(MBPersistenceStorage.isInstalled(in: .standard) == true)
        #expect(MBPersistenceStorage.isInstalled(in: suite) == false)
    }
}
