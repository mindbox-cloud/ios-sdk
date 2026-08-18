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

    @Test("An answer from a background thread is delivered on the main thread")
    func backgroundAnswerIsDeliveredOnTheMainThread() async {
        let service = EmbeddedBlockFeedService(ask: { _, completion in
            DispatchQueue.global().async { completion(FeedAnswer(inappIds: ["story-1"], vouch: {})) }
        })

        let deliveredOnMainThread: Bool = await withCheckedContinuation { continuation in
            service.renderableInappIds(among: ["story-1"]) { _ in
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
        service.renderableInappIds(among: ids) { [weak self] answer in
            self?.answers.append(answer.inappIds)
        }
    }

    func flushSelection() {
        let completions = pending
        pending = []
        completions.forEach { $0(FeedAnswer(inappIds: allowed, vouch: {})) }
    }
}
