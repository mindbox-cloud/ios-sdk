//
//  EmbeddedBlockInappServiceTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 8/13/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import Testing
@_spi(Internal) @testable import Mindbox

@Suite("Embedded block in-app service", .tags(.embeddedBlocks))
@MainActor
struct EmbeddedBlockInappServiceTests {

    @Test("The selection's answer is passed through")
    func selectionAnswerIsPassedThrough() {
        let bed = ServiceBed(allowed: ["story-1", "story-3"])

        bed.ask(["story-1", "story-2", "story-3"])

        #expect(bed.answers == [["story-1", "story-3"]])
        #expect(bed.askedIds == [["story-1", "story-2", "story-3"]])
    }

    @Test("An empty question is answered without asking the selection")
    func emptyQuestionIsAnsweredWithoutAsking() {
        let bed = ServiceBed()

        bed.ask([])

        #expect(bed.answers == [[]])
        #expect(bed.askedIds.isEmpty)
    }

    @Test("A slow selection still answers when it comes back")
    func slowSelectionStillAnswers() {
        let bed = ServiceBed(allowed: ["story-1"], isDeferred: true)

        bed.ask(["story-1"])
        #expect(bed.answers.isEmpty)

        bed.flushSelection()

        #expect(bed.answers == [["story-1"]])
    }

    @Test("Whether a config is in hand is asked of the configuration every time")
    func hasConfigIsAskedOfTheConfiguration() {
        var known = false
        let service = EmbeddedBlockInappService(hasConfig: { known })

        #expect(!service.hasConfig)

        known = true

        #expect(service.hasConfig)
    }

    @Test("A tap fetches the in-app with its params and hands it to the scheduler")
    func tapHandsTheFetchedInappToTheScheduler() {
        var fetched: [(id: String, params: [String: JSONValue])] = []
        var shown: [String] = []
        let service = EmbeddedBlockInappService(
            fetchInappToShow: { id, params, completion in
                fetched.append((id, params))
                completion(Self.formData(id: id))
            },
            showNow: { formData, _ in shown.append(formData.inAppId) }
        )

        service.showInapp(id: "story-1", params: ["formId": .string("160477")])

        #expect(fetched.map(\.id) == ["story-1"])
        #expect(fetched.map(\.params) == [["formId": .string("160477")]])
        #expect(shown == ["story-1"])
    }

    @Test("A tap's processing time runs from the tap to the form being ready")
    func tapProcessingTimeRunsFromTheTap() {
        var ticks: [TimeInterval] = [10, 10.25]
        var durations: [TimeInterval] = []
        let service = EmbeddedBlockInappService(
            fetchInappToShow: { id, _, completion in completion(Self.formData(id: id)) },
            showNow: { _, processingDuration in durations.append(processingDuration) },
            now: { ticks.removeFirst() }
        )

        service.showInapp(id: "story-1", params: [:])

        #expect(durations == [0.25])
    }

    @Test("A tap that resolves to nothing schedules nothing")
    func tapResolvingToNothingSchedulesNothing() {
        var shownCount = 0
        let service = EmbeddedBlockInappService(
            fetchInappToShow: { _, _, completion in completion(nil) },
            showNow: { _, _ in shownCount += 1 }
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
        let service = EmbeddedBlockInappService(ask: { _, _, completion in
            DispatchQueue.global().async { completion(["story-1"]) }
        })

        let deliveredOnMainThread: Bool = await withCheckedContinuation { continuation in
            service.showableInappIds(among: ["story-1"], askedBy: "block") { _ in
                continuation.resume(returning: Thread.isMainThread)
            }
        }

        #expect(deliveredOnMainThread)
    }

    @Test("The block's in-app travels with the question")
    func blockInappTravelsWithTheQuestion() {
        let bed = ServiceBed(allowed: ["story-1"])

        bed.ask(["story-1"], askedBy: "block-1")

        #expect(bed.askedBy == ["block-1"])
    }
}

@MainActor
private final class ServiceBed {

    private(set) var answers: [[String]] = []
    private(set) var askedIds: [[String]] = []
    private(set) var askedBy: [String] = []

    private let service: EmbeddedBlockInappService
    private let allowed: [String]
    private let isDeferred: Bool

    private var pending: [([String]) -> Void] = []

    init(allowed: [String] = [], isDeferred: Bool = false) {
        self.allowed = allowed
        self.isDeferred = isDeferred

        var asked: (([String], String) -> Void)?
        var ask: ((@escaping ([String]) -> Void) -> Void)?

        service = EmbeddedBlockInappService(
            ask: { ids, blockInappId, completion in
                asked?(ids, blockInappId)
                ask?(completion)
            }
        )

        asked = { [weak self] ids, blockInappId in
            self?.askedIds.append(ids)
            self?.askedBy.append(blockInappId)
        }
        ask = { [weak self] completion in
            guard let self else { return }

            if self.isDeferred {
                self.pending.append(completion)
            } else {
                completion(self.allowed)
            }
        }
    }

    func ask(_ ids: [String], askedBy blockInappId: String = "block") {
        service.showableInappIds(among: ids, askedBy: blockInappId) { [weak self] allowed in
            self?.answers.append(allowed)
        }
    }

    func flushSelection() {
        let completions = pending
        pending = []
        completions.forEach { $0(allowed) }
    }
}
