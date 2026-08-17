//
//  LocalStoriesConfigOverrideTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 17.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
@testable import Mindbox

/// The fixture is assembled from a template and generated scene places, and the config decoder is
/// failsafe — a typo in the generated JSON would not fail the parse, it would silently drop the
/// broken in-app and leave a QA scene inexplicably empty. So the suite pins the full outcome: every
/// place the QA kit knows is present and decodes into a real embedded variant.
///
/// Dies together with `LocalStoriesConfigOverride` — delete both before the PR.
@Suite("Local stories config fixture", .tags(.embeddedBlocks))
struct LocalStoriesConfigOverrideTests {

    private static let qaScenePlaces = [
        "qa-layout-error-view", "qa-layout-collapsing", "qa-layout-constrained",
        "qa-scroll", "qa-pager", "qa-list", "qa-lazy-list",
        "qa-place-first", "qa-place-second",
        "qa-states", "qa-late-delegate",
        "qa-customization", "qa-customization-collapsing", "qa-customization-late-error",
        "qa-customization-uikit", "qa-rtl", "qa-duplicate"
    ]

    @Test("Fixture decodes into embedded variants for every QA place")
    func fixtureAddressesEveryQAPlace() throws {
        let data = try #require(LocalStoriesConfigOverride.data)
        let config = try JSONDecoder().decode(ConfigResponse.self, from: data)
        let inapps = try #require(config.inapps?.elements)

        var placesInConfig: Set<String> = []
        for inapp in inapps {
            for variant in inapp.form.variants ?? [] {
                guard case .embedded(let embedded) = variant else { continue }

                let place = try #require(embedded.placeSystemName)
                #expect(placesInConfig.insert(place).inserted, "place '\(place)' is declared twice")

                let layers = try #require(embedded.content?.background?.layers)
                #expect(layers.count == 1, "place '\(place)' must carry exactly one webview layer")
            }
        }

        #expect(placesInConfig == Set(Self.qaScenePlaces + ["stories-list-container"]))
    }

    /// The sixteen stories are what every scene's feed refers to — a broken story in-app would decode
    /// away silently and its circles would open nothing in every feed at once.
    @Test("Fixture keeps the sixteen story in-apps the feeds refer to")
    func fixtureKeepsTheStories() throws {
        let data = try #require(LocalStoriesConfigOverride.data)
        let config = try JSONDecoder().decode(ConfigResponse.self, from: data)
        let ids = Set(try #require(config.inapps?.elements).map(\.id))

        #expect(ids.isSuperset(of: [
            "11111111-1111-1111-1111-111111111111",
            "22222222-2222-2222-2222-222222222222",
            "33333333-3333-3333-3333-333333333333",
            "44444444-4444-4444-4444-444444444444",
            "55555555-5555-5555-5555-555555555555",
            "66666666-6666-6666-6666-666666666666",
            "77777777-7777-7777-7777-777777777777",
            "88888888-8888-8888-8888-888888888888",
            "99999999-9999-9999-9999-999999999999",
            "aaaaaaaa-1111-4111-8111-111111111111",
            "bbbbbbbb-2222-4222-8222-222222222222",
            "cccccccc-3333-4333-8333-333333333333",
            "dddddddd-4444-4444-8444-444444444444",
            "eeeeeeee-5555-4555-8555-555555555555",
            "ffffffff-6666-4666-8666-666666666666",
            "12121212-1212-4212-8212-121212121212"
        ]))
    }
}
