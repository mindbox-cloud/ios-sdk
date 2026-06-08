//
//  MBPersistenceStorageDateTests.swift
//  MindboxTests
//
//  Created by Mindbox on 08.06.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
@testable import Mindbox

// MARK: - Real MBPersistenceStorage: installed state + date round-trips

@Suite(.serialized)
struct MBPersistenceStorageDateTests {

    private let storage: PersistenceStorage

    init() {
        storage = DI.injectOrFail(PersistenceStorage.self)
        storage.reset()
    }

    // MARK: - isInstalled

    @Test("isInstalled is false when no installation-date string is stored")
    func isInstalledFalseWithoutString() {
        #expect(storage.installationDate == nil)
        #expect(storage.isInstalled == false, "isInstalled must be false when nothing is persisted.")
    }

    @Test("isInstalled becomes true once an installationDate is stored, false again after clearing")
    func isInstalledTracksStringPresence() {
        storage.installationDate = Date(timeIntervalSince1970: 1_700_000_000)
        #expect(storage.isInstalled, "isInstalled must be true once an installationDate is persisted.")

        storage.installationDate = nil
        #expect(storage.isInstalled == false, "isInstalled must be false after the installationDate is cleared.")
    }

    // MARK: - Round-trip for all six UTC-backed date properties

    @Test("All six UTC date properties round-trip setter → getter at second precision")
    func allDatesRoundTrip() {
        // (name, setter, getter) for every Date property backed by a `.utc` string in production.
        let cases: [(name: String, set: (Date?) -> Void, get: () -> Date?)] = [
            ("installationDate",
             { storage.installationDate = $0 }, { storage.installationDate }),
            ("firstInitializationDateTime",
             { storage.firstInitializationDateTime = $0 }, { storage.firstInitializationDateTime }),
            ("apnsTokenSaveDate",
             { storage.apnsTokenSaveDate = $0 }, { storage.apnsTokenSaveDate }),
            ("lastInfoUpdateDate",
             { storage.lastInfoUpdateDate = $0 }, { storage.lastInfoUpdateDate }),
            ("deprecatedEventsRemoveDate",
             { storage.deprecatedEventsRemoveDate = $0 }, { storage.deprecatedEventsRemoveDate }),
            ("configDownloadDate",
             { storage.configDownloadDate = $0 }, { storage.configDownloadDate }),
        ]

        // Whole-second timestamp: the `.utc` format ("yyyy-MM-dd'T'HH:mm:ss'Z'") has no sub-second
        // component, so a round-trip is exact only at second precision.
        let expectedEpoch = 1_700_000_000

        for testCase in cases {
            testCase.set(Date(timeIntervalSince1970: TimeInterval(expectedEpoch)))
            let readBack = testCase.get()

            let epoch = readBack.map { Int($0.timeIntervalSince1970) }
            #expect(
                epoch == expectedEpoch,
                "\(testCase.name) must round-trip through storage. Expected \(expectedEpoch), got \(String(describing: epoch))."
            )

            testCase.set(nil)
            #expect(
                testCase.get() == nil,
                "\(testCase.name) must be nil after being cleared."
            )
        }
    }
}
