//
//  EmbeddedBlockResolverTests.swift
//  MindboxTests
//
//  Created by vailence on 06.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import Testing
@_spi(Internal) @testable import Mindbox

@Suite("Embedded block resolver", .tags(.embeddedBlocks))
@MainActor
struct EmbeddedBlockResolverTests {

    @Test("Every block asks for its own answer")
    func everyResolveAsksTheLoader() {
        let loader = ContentLoaderSpy()
        let resolver = EmbeddedBlockResolver(load: loader.load)
        var answers: [EmbeddedBlockResolution] = []

        resolver.resolve("promo") { resolution, _ in answers.append(resolution) }
        resolver.resolve("promo") { resolution, _ in answers.append(resolution) }
        resolver.resolve("stories") { resolution, _ in answers.append(resolution) }

        #expect(loader.requestedIds == ["promo", "promo", "stories"])

        loader.answer(.content(.stub))

        #expect(answers == [.content(.stub), .content(.stub), .content(.stub)])
    }

    @Test("An empty answer is not remembered")
    func emptyAnswerIsNotRemembered() {
        let loader = ContentLoaderSpy()
        let resolver = EmbeddedBlockResolver(load: loader.load)

        resolver.resolve("promo") { _, _ in }
        loader.answer(.empty)

        var second: EmbeddedBlockResolution?
        resolver.resolve("promo") { resolution, _ in second = resolution }
        loader.answer(.content(.stub))

        #expect(loader.requestedIds == ["promo", "promo"])
        #expect(second == .content(.stub))
    }

    @Test("The trigger travels to the loader untouched")
    func triggerTravelsToTheLoader() {
        let loader = ContentLoaderSpy()
        let resolver = EmbeddedBlockResolver(load: loader.load)
        let event = ApplicationEvent(name: "custom.operation", model: nil)

        resolver.resolve("promo", trigger: event) { _, _ in }
        resolver.resolve("promo") { _, _ in }

        #expect(loader.requestedTriggers.count == 2)
        #expect(loader.requestedTriggers[0] === event)
        #expect(loader.requestedTriggers[1] == nil)
    }

    @Test("An answer from a background thread is delivered on the main thread")
    func backgroundAnswerIsDeliveredOnTheMainThread() async {
        let resolver = EmbeddedBlockResolver(load: { _, _, completion in
            DispatchQueue.global().async { completion(.content(.stub), 0) }
        })

        let deliveredOnMainThread: Bool = await withCheckedContinuation { continuation in
            resolver.resolve("promo") { _, _ in
                continuation.resume(returning: Thread.isMainThread)
            }
        }

        #expect(deliveredOnMainThread)
    }

    @Test("An answer from the main thread is delivered without a hop")
    func mainThreadAnswerIsDeliveredSynchronously() {
        let resolver = EmbeddedBlockResolver(load: { _, _, completion in completion(.empty, 0) })
        var answer: EmbeddedBlockResolution?

        resolver.resolve("promo") { resolution, _ in answer = resolution }

        #expect(answer == .empty)
    }

    // MARK: - What the selection's answer becomes

    private func embeddedInapp(params: [String: JSONValue]) throws -> InAppTransitionData {
        let layer = WebviewContentBackgroundLayer(baseUrl: "https://inapp.local/stories",
                                                  contentUrl: "https://mindbox.ru/block.html",
                                                  params: params)
        let content = InappFormVariantContent(background: ContentBackground(layers: [.webview(layer)]),
                                              elements: nil)
        let variant = MindboxFormVariant.embedded(EmbeddedFormVariant(content: content,
                                                                      placeSystemName: "stories-list-container"))
        return InAppTransitionData(inAppId: "block-inapp-id",
                                   isPriority: false,
                                   delayTime: nil,
                                   content: variant,
                                   frequency: nil,
                                   tags: nil)
    }

    /// The params are not read on the way: an empty catalog is the page's own call to make (`contentRendered: 0`).
    @Test("The selection's answer becomes the page, params untouched")
    func resolutionMapsTheWebviewLayerIntoThePage() throws {
        let catalogs: [[String: JSONValue]] = [
            ["stories": .array([.object(["inAppId": .string("55555555")])])],
            [:],
            ["stories": .array([])]
        ]

        for params in catalogs {
            let inapp = try embeddedInapp(params: params)

            let resolution = EmbeddedBlockResolver.resolution(from: inapp, place: "stories-list-container")

            guard case .content(let content) = resolution else {
                Issue.record("Expected content for params \(params), got \(resolution)")
                continue
            }
            #expect(content.inAppId == "block-inapp-id")
            #expect(content.params == params)
        }
    }
}

/// A loader that answers only when asked to: this is how the resolver's behaviour while a load is
/// still in flight gets tested.
private final class ContentLoaderSpy {

    private(set) var requestedIds: [String] = []
    private(set) var requestedTriggers: [ApplicationEvent?] = []

    private var completions: [(EmbeddedBlockResolution, TimeInterval) -> Void] = []

    func load(_ id: String, trigger: ApplicationEvent?, completion: @escaping (EmbeddedBlockResolution, TimeInterval) -> Void) {
        requestedIds.append(id)
        requestedTriggers.append(trigger)
        completions.append(completion)
    }

    func answer(_ resolution: EmbeddedBlockResolution) {
        let pending = completions
        completions = []
        pending.forEach { $0(resolution, 0) }
    }
}
