//
//  MBLoggerUtilitiesFetcherTests.swift
//  MindboxLoggerTests
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
@testable import MindboxLogger

@Suite("MBLoggerUtilitiesFetcher App Group resolution")
struct MBLoggerUtilitiesFetcherTests {

    @Test
    func resolvesWithoutTrapping() {
        let id = MBLoggerUtilitiesFetcher().applicationGroupIdentifier
        if let id {
            #expect(id.hasPrefix("group.cloud.Mindbox."))
        }
    }
}
