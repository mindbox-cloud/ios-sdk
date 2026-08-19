//
//  EmbeddedBlockFeedServiceTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 8/13/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import Testing
@_spi(Internal) @testable import Mindbox

@Suite("Embedded block feed service", .tags(.embeddedBlocks))
@MainActor
struct EmbeddedBlockFeedServiceTests {

    @Test("The selection's answer is passed through")
    func selectionAnswerIsPassedThrough() {
        let bed = FeedBed(allowed: ["story-1", "story-3"])

        bed.ask(["story-1", "story-2", "story-3"])

        #expect(bed.answers == [["story-1", "story-3"]])
        #expect(bed.askedIds == [["story-1", "story-2", "story-3"]])
    }

    @Test("An empty question is answered without asking the selection")
    func emptyQuestionIsAnsweredWithoutAsking() {
        let bed = FeedBed()

        bed.ask([])

        #expect(bed.answers == [[]])
        #expect(bed.askedIds.isEmpty)
    }

    @Test("A slow selection still answers when it comes back")
    func slowSelectionStillAnswers() {
        let bed = FeedBed(allowed: ["story-1"], isDeferred: true)

        bed.ask(["story-1"])
        #expect(bed.answers.isEmpty)

        bed.flushSelection()

        #expect(bed.answers == [["story-1"]])
    }

    @Test("A tap fetches the in-app with its params and hands it to the scheduler")
    func tapHandsTheFetchedInappToTheScheduler() {
        var fetched: [(id: String, params: [String: JSONValue])] = []
        var shown: [String] = []
        let service = EmbeddedBlockFeedService(
            fetchInappToShow: { id, params, completion in
                fetched.append((id, params))
                completion(Self.formData(id: id))
            },
            showNow: { shown.append($0.inAppId) }
        )

        service.showInapp(id: "story-1", params: ["formId": .string("160477")])

        #expect(fetched.map(\.id) == ["story-1"])
        #expect(fetched.map(\.params) == [["formId": .string("160477")]])
        #expect(shown == ["story-1"])
    }

    @Test("A tap that resolves to nothing schedules nothing")
    func tapResolvingToNothingSchedulesNothing() {
        var shownCount = 0
        let service = EmbeddedBlockFeedService(
            fetchInappToShow: { _, _, completion in completion(nil) },
            showNow: { _ in shownCount += 1 }
        )

        service.showInapp(id: "story-1", params: [:])

        #expect(shownCount == 0)
    }

    private static func formData(id: String) -> InAppFormData {
        let modal = ModalFormVariant(content: InappFormVariantContent(background: ContentBackground(layers: []), elements: nil))
        return InAppFormData(inAppId: id,
                             isPriority: false,
                             delayTime: nil,
                             imagesDict: [:],
                             firstImageValue: "",
                             content: .modal(modal),
                             frequency: .once(OnceFrequency(kind: .session)))
    }

    @Test("An answer from a background thread is delivered on the main thread")
    func backgroundAnswerIsDeliveredOnTheMainThread() async {
        let service = EmbeddedBlockFeedService(ask: { _, completion in
            DispatchQueue.global().async { completion(FeedAnswer(inappIds: ["story-1"], vouch: {})) }
        })

        let deliveredOnMainThread: Bool = await withCheckedContinuation { continuation in
            service.showableInappIds(among: ["story-1"]) { _ in
                continuation.resume(returning: Thread.isMainThread)
            }
        }

        #expect(deliveredOnMainThread)
    }
}

@MainActor
private final class FeedBed {

    private(set) var answers: [[String]] = []
    private(set) var askedIds: [[String]] = []

    private let service: EmbeddedBlockFeedService
    private let allowed: [String]
    private let isDeferred: Bool

    private var pending: [(FeedAnswer) -> Void] = []

    init(allowed: [String] = [], isDeferred: Bool = false) {
        self.allowed = allowed
        self.isDeferred = isDeferred

        var askedIds: (([String]) -> Void)?
        var ask: ((@escaping (FeedAnswer) -> Void) -> Void)?

        service = EmbeddedBlockFeedService(
            ask: { ids, completion in
                askedIds?(ids)
                ask?(completion)
            }
        )

        askedIds = { [weak self] ids in self?.askedIds.append(ids) }
        ask = { [weak self] completion in
            guard let self else { return }

            if self.isDeferred {
                self.pending.append(completion)
            } else {
                completion(FeedAnswer(inappIds: self.allowed, vouch: {}))
            }
        }
    }

    func ask(_ ids: [String]) {
        service.showableInappIds(among: ids) { [weak self] answer in
            self?.answers.append(answer.inappIds)
        }
    }

    func flushSelection() {
        let completions = pending
        pending = []
        completions.forEach { $0(FeedAnswer(inappIds: allowed, vouch: {})) }
    }
}
