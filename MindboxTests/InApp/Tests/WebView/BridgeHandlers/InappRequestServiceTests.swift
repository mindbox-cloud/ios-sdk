//
//  InappRequestServiceTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 8/13/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import Testing
@_spi(Internal) @testable import Mindbox

@Suite("In-app request service", .tags(.webView))
@MainActor
struct InappRequestServiceTests {

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
        let service = InappRequestService(hasConfig: { known })

        #expect(!service.hasConfig)

        known = true

        #expect(service.hasConfig)
    }

    @Test("A tap fetches the in-app with its params and hands it to the scheduler")
    func tapHandsTheFetchedInappToTheScheduler() {
        var fetched: [(id: String, params: [String: JSONValue])] = []
        var shown: [String] = []
        let service = InappRequestService(
            fetchInappToShow: { id, params, completion in
                fetched.append((id, params))
                completion(Self.formData(id: id))
            },
            showNow: { formData, _, _, _ in shown.append(formData.inAppId) }
        )

        service.showInapp(id: "story-1", params: ["formId": .string("160477")], proceedIf: { true }) { _ in }

        #expect(fetched.map(\.id) == ["story-1"])
        #expect(fetched.map(\.params) == [["formId": .string("160477")]])
        #expect(shown == ["story-1"])
    }

    @Test("A tap's processing time runs from the tap to the form being ready")
    func tapProcessingTimeRunsFromTheTap() {
        var ticks: [TimeInterval] = [10, 10.25]
        var durations: [TimeInterval] = []
        let service = InappRequestService(
            fetchInappToShow: { id, _, completion in completion(Self.formData(id: id)) },
            showNow: { _, processingDuration, _, _ in durations.append(processingDuration) },
            now: { ticks.removeFirst() }
        )

        service.showInapp(id: "story-1", params: [:], proceedIf: { true }) { _ in }

        #expect(durations == [0.25])
    }

    @Test("A tap that resolves to nothing schedules nothing and answers unknown_inapp")
    func tapResolvingToNothingAnswersUnknownInapp() {
        var shownCount = 0
        var outcomes: [Result<Void, BridgeErrorCode>] = []
        let service = InappRequestService(
            fetchInappToShow: { _, _, completion in completion(nil) },
            showNow: { _, _, _, _ in shownCount += 1 }
        )

        service.showInapp(id: "story-1", params: [:], proceedIf: { true }) { outcomes.append($0) }

        #expect(shownCount == 0)
        #expect(outcomes.map(\.isSuccess) == [false])
        #expect(outcomes.first?.refusal == .unknownInapp)
    }

    @Test("A show that opened answers success")
    func openedShowAnswersSuccess() {
        var outcomes: [Result<Void, BridgeErrorCode>] = []
        let service = InappRequestService(
            fetchInappToShow: { id, _, completion in completion(Self.formData(id: id)) },
            showNow: { _, _, _, completion in completion(.success(())) }
        )

        service.showInapp(id: "story-1", params: [:], proceedIf: { true }) { outcomes.append($0) }

        #expect(outcomes.map(\.isSuccess) == [true])
    }

    @Test("A show that failed on the way to the screen answers show_failed")
    func failedShowAnswersShowFailed() {
        var outcomes: [Result<Void, BridgeErrorCode>] = []
        let service = InappRequestService(
            fetchInappToShow: { id, _, completion in completion(Self.formData(id: id)) },
            showNow: { _, _, _, completion in completion(.failure(.presentationFailed(.failedToLoadWindow))) }
        )

        service.showInapp(id: "story-1", params: [:], proceedIf: { true }) { outcomes.append($0) }

        #expect(outcomes.first?.refusal == .showFailed)
    }

    @Test("A show whose requester was gone by the time it would start answers not_visible")
    func showWithTheRequesterGoneAnswersNotVisible() {
        var outcomes: [Result<Void, BridgeErrorCode>] = []
        let service = InappRequestService(
            fetchInappToShow: { id, _, completion in completion(Self.formData(id: id)) },
            showNow: { _, _, _, completion in completion(.failure(.requesterGone)) }
        )

        service.showInapp(id: "story-1", params: [:], proceedIf: { true }) { outcomes.append($0) }

        #expect(outcomes.first?.refusal == .notVisible)
    }

    @Test("The requester's own check reaches the scheduler, asked when the scheduler asks it")
    func requesterCheckReachesTheScheduler() {
        var handedChecks: [() -> Bool] = []
        let service = InappRequestService(
            fetchInappToShow: { id, _, completion in completion(Self.formData(id: id)) },
            showNow: { _, _, requesterIsActive, _ in handedChecks.append(requesterIsActive) }
        )
        var isRequesterActive = true

        service.showInapp(id: "story-1", params: [:], proceedIf: { isRequesterActive }) { _ in }

        #expect(handedChecks.map { $0() } == [true])
        isRequesterActive = false
        #expect(handedChecks.map { $0() } == [false])
    }

    @Test("A tap shown through the scheduler from the container hands it the requester's own check")
    func containerSchedulerGetsTheRequestersCheck() throws {
        let scheduler = SchedulerSpy()
        try withScheduler(scheduler) {
            let service = InappRequestService(fetchInappToShow: { id, _, completion in completion(Self.formData(id: id)) })
            var isRequesterActive = true

            service.showInapp(id: "story-1", params: [:], proceedIf: { isRequesterActive }) { _ in }

            let handedCheck = try #require(scheduler.requesterChecks.first)
            #expect(handedCheck())
            isRequesterActive = false
            #expect(!handedCheck())
        }
    }

    /// The default show path reaches the scheduler through DI, which is process-global: restored after the body.
    private func withScheduler(_ scheduler: InappScheduleManagerProtocol, _ body: () throws -> Void) rethrows {
        let savedBuilder = MBInject.buildTestContainer
        let savedMode = MBInject.mode
        defer {
            MBInject.buildTestContainer = savedBuilder
            MBInject.mode = savedMode
        }
        MBInject.buildTestContainer = {
            let container = MBContainer()
            container.register(InappScheduleManagerProtocol.self) { scheduler }
            return container
        }
        MBInject.mode = .test

        try body()
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
        let service = InappRequestService(ask: { _, _, completion in
            DispatchQueue.global().async { completion(["story-1"]) }
        })

        let deliveredOnMainThread: Bool = await withCheckedContinuation { continuation in
            service.showableInappIds(among: ["story-1"], askedBy: "block") { _ in
                continuation.resume(returning: Thread.isMainThread)
            }
        }

        #expect(deliveredOnMainThread)
    }

    @Test("A tap answered from a background thread reaches the page on the main thread")
    func backgroundTapAnswerIsDeliveredOnTheMainThread() async {
        let service = InappRequestService(fetchInappToShow: { _, _, completion in
            DispatchQueue.global().async { completion(nil) }
        })

        let deliveredOnMainThread: Bool = await withCheckedContinuation { continuation in
            service.showInapp(id: "story-1", params: [:], proceedIf: { true }) { _ in
                continuation.resume(returning: Thread.isMainThread)
            }
        }

        #expect(deliveredOnMainThread)
    }

    @Test("The asking in-app travels with the question")
    func askingInappTravelsWithTheQuestion() {
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

    private let service: InappRequestService
    private let allowed: [String]
    private let isDeferred: Bool

    private var pending: [([String]) -> Void] = []

    init(allowed: [String] = [], isDeferred: Bool = false) {
        self.allowed = allowed
        self.isDeferred = isDeferred

        var asked: (([String], String) -> Void)?
        var ask: ((@escaping ([String]) -> Void) -> Void)?

        service = InappRequestService(
            ask: { ids, requesterInappId, completion in
                asked?(ids, requesterInappId)
                ask?(completion)
            }
        )

        asked = { [weak self] ids, requesterInappId in
            self?.askedIds.append(ids)
            self?.askedBy.append(requesterInappId)
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

    func ask(_ ids: [String], askedBy requesterInappId: String = "block") {
        service.showableInappIds(among: ids, askedBy: requesterInappId) { [weak self] allowed in
            self?.answers.append(allowed)
        }
    }

    func flushSelection() {
        let completions = pending
        pending = []
        completions.forEach { $0(allowed) }
    }
}

private extension Result where Success == Void, Failure == BridgeErrorCode {

    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    var refusal: BridgeErrorCode? {
        if case .failure(let refusal) = self { return refusal }
        return nil
    }
}

private final class SchedulerSpy: InappScheduleManagerProtocol {
    weak var delegate: InAppMessagesDelegate?
    private(set) var requesterChecks: [() -> Bool] = []

    func scheduleInApp(_ inAppFormData: InAppFormData, processingDuration: TimeInterval) {}

    func showInAppNow(_ inAppFormData: InAppFormData,
                      processingDuration: TimeInterval,
                      proceedIf requesterIsActive: @escaping () -> Bool,
                      completion: @escaping (Result<Void, InappShowNowError>) -> Void) {
        requesterChecks.append(requesterIsActive)
    }
}
