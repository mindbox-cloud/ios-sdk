//
//  EmbeddedBlockDebugOverrideTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 17.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
@_spi(Internal) @testable import Mindbox

/// The overrides are process-global — every test cleans up after itself.
@Suite("Embedded block debug overrides", .tags(.embeddedBlocks))
@MainActor
struct EmbeddedBlockDebugOverrideTests {

    private final class ConfigSpy {
        private(set) var loadCalls = 0

        func load(_ place: String, _ trigger: ApplicationEvent?,
                  _ completion: @escaping (EmbeddedBlockResolution) -> Void) {
            loadCalls += 1
            completion(.empty)
        }
    }

    @Test("Override answers the place and the config is not asked")
    func overrideAnswersInsteadOfTheConfig() throws {
        defer { MindboxEmbeddedBlockDebug.removeAllContent() }
        let spy = ConfigSpy()
        let resolver = EmbeddedBlockResolver(load: spy.load)
        MindboxEmbeddedBlockDebug.setContent(.html("<p>qa</p>"), for: "qa-place")

        var answer: EmbeddedBlockResolution?
        resolver.resolve("qa-place") { answer = $0 }

        guard case .content(let content)? = answer else {
            Issue.record("expected content from the override, got \(String(describing: answer))")
            return
        }
        #expect(spy.loadCalls == 0)
        #expect(content.inAppId == "qa-debug-override")
    }

    @Test("Empty override switches the place off")
    func emptyOverrideSwitchesThePlaceOff() {
        defer { MindboxEmbeddedBlockDebug.removeAllContent() }
        let spy = ConfigSpy()
        let resolver = EmbeddedBlockResolver(load: spy.load)
        MindboxEmbeddedBlockDebug.setContent(.empty, for: "qa-place")

        var answer: EmbeddedBlockResolution?
        resolver.resolve("qa-place") { answer = $0 }

        #expect(answer == .empty)
        #expect(spy.loadCalls == 0)
    }

    @Test("Removed override gives the config path back")
    func removedOverrideGivesTheConfigBack() {
        defer { MindboxEmbeddedBlockDebug.removeAllContent() }
        let spy = ConfigSpy()
        let resolver = EmbeddedBlockResolver(load: spy.load)
        MindboxEmbeddedBlockDebug.setContent(.empty, for: "qa-place")
        MindboxEmbeddedBlockDebug.removeContent(for: "qa-place")

        var answer: EmbeddedBlockResolution?
        resolver.resolve("qa-place") { answer = $0 }

        #expect(answer == .empty)
        #expect(spy.loadCalls == 1)
    }

    @Test("Override holds only the place it was set for")
    func overrideHoldsOnlyItsPlace() {
        defer { MindboxEmbeddedBlockDebug.removeAllContent() }
        let spy = ConfigSpy()
        let resolver = EmbeddedBlockResolver(load: spy.load)
        MindboxEmbeddedBlockDebug.setContent(.empty, for: "qa-place")

        resolver.resolve("qa-other-place") { _ in }

        #expect(spy.loadCalls == 1)
    }

    @Test("Markup override travels as a data url carrying the same markup")
    func markupTravelsAsADataUrl() throws {
        defer { MindboxEmbeddedBlockDebug.removeAllContent() }
        let markup = "<!doctype html><p>лента — feed</p>"
        let resolver = EmbeddedBlockResolver(load: ConfigSpy().load)
        MindboxEmbeddedBlockDebug.setContent(.html(markup), for: "qa-place")

        var answer: EmbeddedBlockResolution?
        resolver.resolve("qa-place") { answer = $0 }

        guard case .content(let content)? = answer else {
            Issue.record("expected content from the override, got \(String(describing: answer))")
            return
        }

        let prefix = "data:text/html;charset=utf-8;base64,"
        #expect(content.contentUrl.hasPrefix(prefix))
        let base64 = String(content.contentUrl.dropFirst(prefix.count))
        let decoded = try #require(Data(base64Encoded: base64).flatMap { String(data: $0, encoding: .utf8) })
        #expect(decoded == markup)

        // An override must not leave a trace a real in-app's frequency would later read.
        #expect(InappFrequency.countsShows(content.frequency) == false)
    }
}
