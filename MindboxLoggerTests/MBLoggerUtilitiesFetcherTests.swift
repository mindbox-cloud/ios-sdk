//
//  MBLoggerUtilitiesFetcherTests.swift
//  MindboxLoggerTests
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
@testable import MindboxLogger

/// Regression coverage for issue #705: `MBLoggerUtilitiesFetcher.applicationGroupIdentifier`
/// must NEVER trap. It used to `fatalError` when the shared container was unavailable; it now
/// returns `nil` so `LoggerDatabaseLoader` falls back to the app's local store.
@Suite("MBLoggerUtilitiesFetcher App Group resolution")
struct MBLoggerUtilitiesFetcherTests {

    /// #705 core invariant: the getter must resolve WITHOUT trapping. It used to `fatalError`
    /// when the shared container was unavailable; a `fatalError` would tear down the test
    /// runner, so this test reaching its assertion at all proves the trap is gone.
    @Test
    func resolvesWithoutTrapping() {
        let id = MBLoggerUtilitiesFetcher().applicationGroupIdentifier
        if let id {
            #expect(id.hasPrefix("group.cloud.Mindbox."))
        }
    }
}
