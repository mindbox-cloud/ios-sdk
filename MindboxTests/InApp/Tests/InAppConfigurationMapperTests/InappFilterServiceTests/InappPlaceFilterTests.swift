//
//  InappPlaceFilterTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import Testing
@testable import Mindbox

@Suite("Place path filters", .tags(.embeddedBlocks))
struct InappPlaceFilterTests {

    private let sut = DI.injectOrFail(InappFilterProtocol.self) as? InappsFilterService

    private let place = "stories-list-container"

    private func content() -> InappFormVariantContent {
        InappFormVariantContent(
            background: ContentBackground(layers: [
                .webview(WebviewContentBackgroundLayer(
                    baseUrl: "https://inapp.local/stories",
                    contentUrl: "https://mobile-static-staging.mindbox.ru/inapps/webview/content/stories.html",
                    params: [:]
                ))
            ]),
            elements: nil
        )
    }

    private func modal() -> MindboxFormVariant { .modal(ModalFormVariant(content: content())) }

    private func embedded(place: String) -> MindboxFormVariant {
        .embedded(EmbeddedFormVariant(content: content(), placeSystemName: place))
    }

    private func inapp(id: String,
                       variants: [MindboxFormVariant],
                       isPriority: Bool = false,
                       frequency: InappFrequency = .unlimited,
                       displayConditions: DisplayConditions = .unrestricted,
                       delayTime: String? = nil) -> InApp {
        InApp(id: id,
              isPriority: isPriority,
              delayTime: delayTime,
              sdkVersion: SdkVersion(min: 13, max: nil),
              targeting: .true(TrueTargeting()),
              frequency: frequency,
              displayConditions: displayConditions,
              form: InAppForm(variants: variants),
              tags: nil)
    }

    private func ids(_ inapps: [InApp]) -> [String] { inapps.map { $0.id } }

    private func candidates(_ inapps: [InApp]) -> ConfigCandidates { ConfigCandidates(renderable: inapps, inPool: inapps) }

    // MARK: - Addressing

    @Test("An in-app set up for the place is a candidate")
    func keepsInappForPlace() throws {
        let sut = try #require(sut)
        let inapps = sut.filter(place: place, in: candidates([inapp(id: "1", variants: [embedded(place: place)])]))
        #expect(ids(inapps) == ["1"])
    }

    @Test("An in-app set up for another place is not")
    func dropsInappForAnotherPlace() throws {
        let sut = try #require(sut)
        let inapps = sut.filter(place: place, in: candidates([inapp(id: "1", variants: [embedded(place: "other-place")])]))
        #expect(inapps.isEmpty)
    }

    @Test("Place names are case-sensitive")
    func placeNamesAreCaseSensitive() throws {
        let sut = try #require(sut)
        let inapps = sut.filter(place: place, in: candidates([inapp(id: "1", variants: [embedded(place: "Stories-List-Container")])]))
        #expect(inapps.isEmpty)
    }

    @Test("A modal in-app is never a candidate for a place")
    func dropsOverlayInapp() throws {
        let sut = try #require(sut)
        let inapps = sut.filter(place: place, in: candidates([inapp(id: "1", variants: [modal()])]))
        #expect(inapps.isEmpty)
    }

    // MARK: - The shared part of the chain

    @Test("Direct call keeps the block empty on this path too")
    func dropsDirectCallInapp() throws {
        let sut = try #require(sut)
        let inapps = sut.filter(place: place, in: candidates([inapp(id: "1", variants: [embedded(place: place)], displayConditions: .directCall)]))
        #expect(inapps.isEmpty)
    }

    @Test("A restrictive frequency still passes for a block that was never shown", arguments: [
        InappFrequency.unlimited,
        .once(OnceFrequency(kind: .lifetime)),
        .once(OnceFrequency(kind: .session))
    ])
    func frequencyPassesForUnshownBlock(frequency: InappFrequency) throws {
        let sut = try #require(sut)
        let inapps = sut.filter(place: place, in: candidates([inapp(id: "unshown-block-id", variants: [embedded(place: place)], frequency: frequency)]))
        #expect(ids(inapps) == ["unshown-block-id"])
    }

    /// Blocks arrive `unlimited` by contract — pinned because Android behaves the same way and the two must not drift.
    @Test("A block whose show was already recorded is no longer a candidate", arguments: [
        InappFrequency.once(OnceFrequency(kind: .lifetime)),
        .once(OnceFrequency(kind: .session)),
        .periodic(PeriodicFrequency(unit: .days, value: 1))
    ])
    func spentFrequencyDropsBlock(frequency: InappFrequency) throws {
        let sut = try #require(sut)
        let storage = DI.injectOrFail(PersistenceStorage.self)
        let shownDates = storage.shownDatesByInApp
        let shownInSession = SessionTemporaryStorage.shared.sessionShownInApps
        defer {
            storage.shownDatesByInApp = shownDates
            SessionTemporaryStorage.shared.sessionShownInApps = shownInSession
        }

        storage.shownDatesByInApp = ["shown-block-id": [Date()]]
        SessionTemporaryStorage.shared.sessionShownInApps = ["shown-block-id"]

        let inapps = sut.filter(place: place, in: candidates([inapp(id: "shown-block-id", variants: [embedded(place: place)], frequency: frequency)]))
        #expect(inapps.isEmpty)
    }

    @Test("Two candidates for one place come back with the priority one first")
    func sortsCandidatesByPriority() throws {
        let sut = try #require(sut)
        let inapps = sut.filter(place: place, in: candidates([
            inapp(id: "regular", variants: [embedded(place: place)]),
            inapp(id: "priority", variants: [embedded(place: place)], isPriority: true)
        ]))

        #expect(ids(inapps) == ["priority", "regular"])
    }

    // MARK: - Targeting picks the variant for the place

    @Test("The transition data carries the variant addressed to the place")
    func picksVariantForPlace() throws {
        let sut = try #require(sut)
        let inapp = inapp(id: "1", variants: [embedded(place: "other-place"), embedded(place: place)])

        let checker = DI.injectOrFail(InAppTargetingCheckerProtocol.self)
        checker.prepare(id: "1", targeting: .true(TrueTargeting()))

        let transitions = sut.filterInappsByTargeting(inapps: [inapp], targetingChecker: checker) { candidate in
            candidate.form.variants.first { $0.placeSystemName == self.place }
        }

        #expect(transitions.count == 1)
        #expect(transitions.first?.content.placeSystemName == place)
    }
}
