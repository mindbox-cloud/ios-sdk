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

/// Regression coverage for issue #705 on the **core SDK** path: when the App Group
/// container is unavailable the SDK must degrade to local storage instead of crashing
/// the host — in Debug and Release alike. Covers the previously-untested fallback branches:
///  - `MBUtilitiesFetcher.applicationGroupIdentifier` resolves without trapping (it used to
///    `fatalError` on an unavailable container),
///  - the DI `PersistenceStorage` factory falls back to `UserDefaults.standard` on an empty group, and
///  - the events store's `MBPersistentContainer` resolves to the app-local directory on an empty group.
///
/// Serialized because the cases mutate global state (`MBInject`, `MBPersistenceStorage.defaults`,
/// `MBPersistentContainer.applicationGroupIdentifier`).
@Suite("App Group unavailable — core SDK fallback", .serialized)
struct AppGroupUnavailableTests {

    /// Stub fetcher reporting an unavailable App Group (empty identifier). Lets the DI fallback
    /// be driven deterministically, independent of the simulator's container behavior.
    private struct EmptyAppGroupUtilitiesFetcher: UtilitiesFetcher {
        var appVerson: String? { "1.0.0" }
        var sdkVersion: String? { "test" }
        var hostApplicationName: String? { "cloud.Mindbox.MindboxTests" }
        var applicationGroupIdentifier: String { "" }
        func getDeviceUUID(completion: @escaping (String) -> Void) { completion(UUID().uuidString) }
    }

    // MARK: - The core fetcher no longer traps (issue #705 device crash site)

    /// #705 core invariant: the getter must resolve WITHOUT trapping. It used to `fatalError`
    /// on an unavailable container; a `fatalError` would tear down the runner, so reaching the
    /// assertion at all proves the trap is gone.
    @Test
    func coreFetcherResolvesWithoutTrapping() {
        let id = MBUtilitiesFetcher().applicationGroupIdentifier
        #expect(id.isEmpty || id.hasPrefix("group.cloud.Mindbox."))
    }

    // MARK: - DI falls back to UserDefaults.standard on an empty App Group

    /// With an empty App Group the `PersistenceStorage` DI factory must back the storage with
    /// `UserDefaults.standard` — not crash, not a nil suite. Drives the real factory with a stub
    /// fetcher reporting `""`.
    @Test
    func persistenceStorageFallsBackToStandardWhenAppGroupEmpty() {
        // `buildTestContainer` and `mode` are global; restore both so this minimal
        // container can't leak into later `.test`-mode tests that expect the full stub builder.
        let savedBuilder = MBInject.buildTestContainer
        let savedMode = MBInject.mode
        defer {
            MBInject.buildTestContainer = savedBuilder
            MBInject.mode = savedMode
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

    // MARK: - Events Core Data store falls back to a local directory on an empty App Group

    /// The events store's container must resolve to the app-local default directory — not a
    /// shared container — when the App Group is unavailable, so events keep persisting locally
    /// instead of crashing. The core fetcher reports `""` in that case, and `containerURL("")`
    /// is nil, so `defaultDirectoryURL()` must fall through to `super`'s app-local directory.
    @Test
    func eventsStoreFallsBackToLocalDirectoryWhenAppGroupEmpty() {
        let saved = MBPersistentContainer.applicationGroupIdentifier
        defer { MBPersistentContainer.applicationGroupIdentifier = saved }

        MBPersistentContainer.applicationGroupIdentifier = ""
        #expect(MBPersistentContainer.defaultDirectoryURL() == NSPersistentContainer.defaultDirectoryURL())
    }
}

/// Coverage for the storage-transition reporter (issue #705 follow-up): it reports only when
/// install state is in BOTH stores and is read-only. Uses isolated per-case `UserDefaults`.
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
        // Read-only: neither store is modified, regardless of whether we reported.
        #expect(MBPersistenceStorage.isInstalled(in: localStore) == local)
        #expect(MBPersistenceStorage.isInstalled(in: activeStore) == active)
        // Not one-shot: while the fingerprint persists it reports again on the next call.
        #expect(reporter.reportIfNeeded() == expectReport)
    }

    @Test("No report in local fallback (App Group unavailable → active store IS the local store)")
    func noReportInFallback() {
        let name = "test.appgroup.fallback"
        let store = makeStore(name, installed: true)
        defer { store.removePersistentDomain(forName: name) }

        // In fallback the active store and the local store are the same instance.
        let didReport = AppGroupStorageTransitionReporter(activeDefaults: store, localDefaults: store)
            .reportIfNeeded()

        #expect(didReport == false)
        #expect(MBPersistenceStorage.isInstalled(in: store) == true)
    }
}
