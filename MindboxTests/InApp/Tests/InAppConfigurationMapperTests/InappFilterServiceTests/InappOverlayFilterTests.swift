//
//  InappOverlayFilterTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import Testing
@testable import Mindbox

@Suite("Overlay path filters", .tags(.embeddedBlocks))
struct InappOverlayFilterTests {

    private let sut = DI.injectOrFail(InappFilterProtocol.self) as? InappsFilterService

    private func webviewLayer() -> ContentBackgroundLayer {
        .webview(WebviewContentBackgroundLayer(
            baseUrl: "https://inapp.local/stories",
            contentUrl: "https://mobile-static-staging.mindbox.ru/inapps/webview/content/stories.html",
            params: [:]
        ))
    }

    private func content() -> InappFormVariantContent {
        InappFormVariantContent(background: ContentBackground(layers: [webviewLayer()]), elements: nil)
    }

    private func inapp(id: String,
                       variants: [MindboxFormVariant],
                       displayConditions: DisplayConditions = .unrestricted,
                       delayTime: String? = nil) -> InApp {
        InApp(id: id,
              isPriority: false,
              delayTime: delayTime,
              sdkVersion: SdkVersion(min: 13, max: nil),
              targeting: .true(TrueTargeting()),
              frequency: .unlimited,
              displayConditions: displayConditions,
              form: InAppForm(variants: variants),
              tags: nil)
    }

    private func modal() -> MindboxFormVariant { .modal(ModalFormVariant(content: content())) }

    private func embedded() -> MindboxFormVariant {
        .embedded(EmbeddedFormVariant(content: content(), placeSystemName: "stories-list-container"))
    }

    // MARK: - Nothing to show over the screen

    @Test("A block-only in-app never reaches the overlay path")
    func dropsEmbeddedOnlyInapp() throws {
        let sut = try #require(sut)
        #expect(sut.filterOutNonOverlayInapps([inapp(id: "1", variants: [embedded()])]).isEmpty)
    }

    @Test("A modal in-app stays on the overlay path")
    func keepsModalInapp() throws {
        let sut = try #require(sut)
        #expect(sut.filterOutNonOverlayInapps([inapp(id: "1", variants: [modal()])]).count == 1)
    }

    @Test("An in-app with both variants stays, and the overlay one is what gets built")
    func keepsMixedInapp() throws {
        let sut = try #require(sut)
        let inapps = sut.filterOutNonOverlayInapps([inapp(id: "1", variants: [embedded(), modal()])])
        #expect(inapps.count == 1)

        let checker = DI.injectOrFail(InAppTargetingCheckerProtocol.self)
        checker.prepare(id: "1", targeting: .true(TrueTargeting()))
        let transitions = sut.filterInappsByTargeting(inapps: inapps, targetingChecker: checker)
        #expect(transitions.first?.content == modal())
    }

    // MARK: - Direct call only

    @Test("A direct-call in-app answers no trigger")
    func dropsDirectCallInapp() throws {
        let sut = try #require(sut)
        let inapps = [inapp(id: "1", variants: [modal()], displayConditions: .directCall)]
        #expect(sut.filterOutDirectCallInapps(inapps).isEmpty)
    }

    @Test("An unrestricted in-app still answers triggers")
    func keepsUnrestrictedInapp() throws {
        let sut = try #require(sut)
        let inapps = [inapp(id: "1", variants: [modal()], displayConditions: .unrestricted)]
        #expect(sut.filterOutDirectCallInapps(inapps).count == 1)
    }

}
