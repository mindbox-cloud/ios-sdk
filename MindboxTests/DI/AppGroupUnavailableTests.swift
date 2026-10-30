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

@Suite("App Group unavailable — core SDK fallback", .serialized)
struct AppGroupUnavailableTests {

    private struct EmptyAppGroupUtilitiesFetcher: UtilitiesFetcher {
        var appVerson: String? { "1.0.0" }
        var sdkVersion: String? { "test" }
        var hostApplicationName: String? { "cloud.Mindbox.MindboxTests" }
        var applicationGroupIdentifier: String { "" }
        func getDeviceUUID(completion: @escaping (String) -> Void) { completion(UUID().uuidString) }
    }

    @Test
    func coreFetcherResolvesWithoutTrapping() {
        let id = MBUtilitiesFetcher().applicationGroupIdentifier
        #expect(id.isEmpty || id.hasPrefix("group.cloud.Mindbox."))
    }

    @Test
    func persistenceStorageFallsBackToStandardWhenAppGroupEmpty() {
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

    @Test(arguments: [nil, ""] as [String?])
    func eventsStoreFallsBackToLocalDirectory(groupId: String?) {
        let saved = MBPersistentContainer.applicationGroupIdentifier
        defer { MBPersistentContainer.applicationGroupIdentifier = saved }

        MBPersistentContainer.applicationGroupIdentifier = groupId
        #expect(MBPersistentContainer.defaultDirectoryURL() == NSPersistentContainer.defaultDirectoryURL())
    }
}

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

    @Test("Reports only when install state is in BOTH stores, on every call rather than once, and never mutates either store",
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
        #expect(MBPersistenceStorage.isInstalled(in: localStore) == local)
        #expect(MBPersistenceStorage.isInstalled(in: activeStore) == active)
        #expect(reporter.reportIfNeeded() == expectReport)
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
        UserDefaults.standard.set("23.05.2026 10:00:00", forKey: key)

        #expect(MBPersistenceStorage.isInstalled(in: .standard) == true)
        #expect(MBPersistenceStorage.isInstalled(in: suite) == false)
    }
}
