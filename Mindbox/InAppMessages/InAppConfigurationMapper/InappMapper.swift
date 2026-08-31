//
//  InappMapper.swift
//  Mindbox
//
//  Created by vailence on 12.11.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import UIKit
import Foundation
import MindboxLogger

protocol InappMapperProtocol {
    func handleInapps(_ event: ApplicationEvent?,
                      _ candidates: ConfigCandidates,
                      _ completion: @escaping (InAppFormData?) -> Void)
    func selectInappForPlace(_ place: String,
                             trigger: ApplicationEvent?,
                             _ candidates: ConfigCandidates,
                             _ completion: @escaping (InAppTransitionData?) -> Void)
    func getInAppById(_ id: String,
                      _ candidates: ConfigCandidates,
                      _ completion: @escaping (InAppTransitionData?) -> Void)
    func getShowableInappIds(_ ids: [String],
                             askedBy blockInappId: String,
                             _ candidates: ConfigCandidates,
                             _ completion: @escaping ([String]) -> Void)
    func getInAppToShowById(_ id: String,
                            params: [String: JSONValue],
                            _ candidates: ConfigCandidates,
                            _ completion: @escaping (InAppFormData?) -> Void)
}

class InappMapper: InappMapperProtocol {

    private var targetingChecker: InAppTargetingCheckerProtocol
    private let inappFilterService: InappFilterProtocol
    private let dataFacade: InAppConfigurationDataFacadeProtocol
    private let presentationValidator: InAppPresentationValidatorProtocol
    private let formBuilder: InappFormBuilder

    @Locked private var shownInappIDWithHashValue: [String: Int] = [:]

    private let processingQueue = DispatchQueue(label: "com.Mindbox.inAppMapper.processingQueue")

    init(targetingChecker: InAppTargetingCheckerProtocol,
         inappFilterService: InappFilterProtocol,
         dataFacade: InAppConfigurationDataFacadeProtocol,
         presentationValidator: InAppPresentationValidatorProtocol) {
        self.targetingChecker = targetingChecker
        self.inappFilterService = inappFilterService
        self.dataFacade = dataFacade
        self.presentationValidator = presentationValidator
        self.formBuilder = InappFormBuilder(dataFacade: dataFacade)
    }

    // MARK: - Entry points

    func handleInapps(_ event: ApplicationEvent?,
                      _ candidates: ConfigCandidates,
                      _ completion: @escaping (InAppFormData?) -> Void) {
        runPass("the trigger", event: event) { finish in
            self.evaluate(self.triggerQuery(event, candidates), event: event) { verdict in
                self.buildFirstShowable(verdict, event: event) { formData in
                    self.evaluate(self.catchUpQuery(event, candidates), event: event) { catchUp in
                        self.vouchCatchUp(catchUp, event: event)
                        finish(formData != nil)
                        completion(formData)
                    }
                }
            }
        }
    }

    func selectInappForPlace(_ place: String,
                             trigger: ApplicationEvent?,
                             _ candidates: ConfigCandidates,
                             _ completion: @escaping (InAppTransitionData?) -> Void) {
        runPass("place '\(place)'", event: trigger) { finish in
            self.evaluate(self.placeQuery(place, candidates), event: trigger) { verdict in
                self.evaluate(self.placeTargetingQuery(place, candidates), event: trigger) { targeted in
                    let winner = verdict.first
                    self.vouch(targeted, winner: winner, at: place)

                    guard let winner else {
                        finish(false)
                        completion(nil)
                        return
                    }

                    guard self.presentationValidator.isWithinShowBudgets(isPriority: winner.isPriority,
                                                                        frequency: winner.frequency,
                                                                        id: winner.inAppId) else {
                        Logger.common(message: "[InappMapper] In-app \(winner.inAppId) won place '\(place)' but the show budgets are spent, the place stays empty",
                                      level: .debug, category: .inAppMessages)
                        // Selected all the same: spent budgets are no targeting failure, so the buffer is dropped as after the overlay's pass.
                        finish(true)
                        completion(nil)
                        return
                    }

                    finish(true)
                    completion(winner)
                }
            }
        }
    }

    /// Vouches as it answers, not on delivery — the overlay's rule. An id whose targeting still lacks data
    /// after the fetch is cut: fail closed, in sync with Android.
    func getShowableInappIds(_ ids: [String],
                             askedBy blockInappId: String,
                             _ candidates: ConfigCandidates,
                             _ completion: @escaping ([String]) -> Void) {
        runPass("a page of in-app \(blockInappId) asking about \(ids.count) in-app(s)", event: nil) { finish in
            self.evaluate(self.pageQuery(ids, candidates), event: nil) { verdict in
                self.evaluate(self.pageTargetingQuery(ids, candidates), event: nil) { offered in
                    // A page's question selects nothing; false only flushes a buffer this pass
                    // keeps empty (collectsFailures: false).
                    finish(false)
                    self.vouchOffers(offered, by: blockInappId)
                    completion(verdict.map(\.inAppId))
                }
            }
        }
    }

    /// Nothing checked, display conditions included: a direct call may show anything the config holds.
    func getInAppById(_ id: String,
                      _ candidates: ConfigCandidates,
                      _ completion: @escaping (InAppTransitionData?) -> Void) {
        processingQueue.async {
            completion(self.transition(forId: id, in: candidates))
        }
    }

    /// Show history is deliberately not consulted: the page already offered this in-app, and a tap
    /// has to open it however many times it opened before. A pass of its own, so a form that could
    /// not be built reports why at once instead of leaving that to whatever pass comes next.
    func getInAppToShowById(_ id: String,
                            params: [String: JSONValue],
                            _ candidates: ConfigCandidates,
                            _ completion: @escaping (InAppFormData?) -> Void) {
        runPass("a tap on in-app \(id)", event: nil) { finish in
            guard let transitionData = self.transition(forId: id, in: candidates) else {
                finish(false)
                completion(nil)
                return
            }

            guard transitionData.content.isOverlayPresentable else {
                Logger.common(message: "[InappMapper] In-app \(id) is drawn inside the host layout and cannot be shown over the screen.",
                              level: .error, category: .inAppMessages)
                finish(false)
                completion(nil)
                return
            }

            self.buildInApp(transitionData, extraParams: params) { formData in
                finish(formData != nil)
                completion(formData)
            }
        }
    }

    private func transition(forId id: String, in candidates: ConfigCandidates) -> InAppTransitionData? {
        guard let inapp = inappFilterService.filter(id: id, in: candidates) else { return nil }

        // The variant the page's question picks, so a tap opens what the page offered.
        guard let variant = inapp.form.variants.first(where: { $0.isOverlayPresentable })
                ?? inapp.form.variants.first else {
            Logger.common(message: "[InappMapper] In-app \(id) has no variant left to render.",
                          level: .error, category: .inAppMessages)
            return nil
        }

        return InAppTransitionData(inAppId: inapp.id,
                                   isPriority: inapp.isPriority,
                                   delayTime: inapp.delayTime,
                                   content: variant,
                                   frequency: inapp.frequency,
                                   tags: inapp.tags)
    }

    // MARK: - The pass

    /// One serial queue and one shared checker: a pass holds the queue until `finish`, so a place resolve
    /// cannot land between a trigger's selection and its catch-up and swap the event under it.
    /// The buffered failures answer "why was nothing shown", so only a pass that selected nothing sends them.
    private func runPass(_ label: String,
                         event: ApplicationEvent?,
                         _ body: @escaping (_ finish: @escaping (_ selected: Bool) -> Void) -> Void) {
        processingQueue.async {
            let group = DispatchGroup()
            group.enter()

            Logger.common(message: "[InappMapper] Pass for \(label) by event: \(event?.name ?? "start")",
                          level: .debug, category: .inAppMessages)
            self.targetingChecker.event = event

            // A missed finish freezes the queue for good, a second one would crash the leave.
            let finishLock = NSLock()
            var finished = false

            body { selected in
                finishLock.lock()
                let alreadyFinished = finished
                finished = true
                finishLock.unlock()

                guard !alreadyFinished else {
                    assertionFailure("[InappMapper] The pass for \(label) tried to finish twice")
                    return
                }

                if selected {
                    self.dataFacade.discardCollectedFailures()
                } else {
                    self.dataFacade.sendCollectedFailures()
                }
                group.leave()
            }

            group.wait()
        }
    }

    /// One question to the shared checker, inside a pass only.
    private struct TargetingQuery {

        let label: String

        /// In-apps the checker learns about before the check — what to fetch, who listens to which operation.
        let prepares: () -> [InApp]

        /// The pass's candidates, decided once the checker has been prepared.
        let candidates: (PreparationContext) -> [InApp]

        /// Fetches geo/segmentations first; off for a follow-up question whose pass already did.
        let fetchesDependencies: Bool

        /// A failed fetch becomes a buffered `Inapp.ShowFailure` for every candidate the pass then cut.
        /// Off for a page's question: what it cut is not reported in this iteration.
        let collectsFailures: Bool

        let pickVariant: (InApp) -> MindboxFormVariant?
    }

    private func evaluate(_ query: TargetingQuery,
                          event: ApplicationEvent?,
                          completion: @escaping ([InAppTransitionData]) -> Void) {
        let prepared = query.prepares()
        prepared.forEach { targetingChecker.prepare(id: $0.id, targeting: $0.targeting) }

        // Narrowed before the fetch: its completion answers on the main queue, where frequency reads have no business.
        let candidates = query.candidates(targetingChecker.context)
        let startedAt = Date()

        let check = {
            let suitable = self.inappFilterService.filterInappsByTargeting(inapps: candidates,
                                                                           targetingChecker: self.targetingChecker,
                                                                           pickVariant: query.pickVariant)
            if query.collectsFailures {
                self.collectTargetingFailures(among: candidates, suitable: suitable)
            }

            let ms = Int(Date().timeIntervalSince(startedAt) * 1000)
            Logger.common(message: """
            [InappMapper] \(query.label): \(candidates.count) candidate(s), \(suitable.count) targeted, \
            answered in \(ms) ms.
            """, level: .debug, category: .inAppMessages)

            completion(suitable)
        }

        if query.fetchesDependencies {
            dataFacade.fetchDependencies(model: event?.model, shouldCollectFailures: query.collectsFailures, check)
        } else {
            check()
        }
    }

    private func collectTargetingFailures(among candidates: [InApp], suitable: [InAppTransitionData]) {
        let suitableIds = Set(suitable.map(\.inAppId))
        let failedIds = Set(candidates.map(\.id)).subtracting(suitableIds)
        let tagsByInappId: [String: [String: String]] = candidates.reduce(into: [:]) { result, inapp in
            guard failedIds.contains(inapp.id), let tags = inapp.tags else { return }
            result[inapp.id] = tags
        }
        dataFacade.collectTargetingFailures(forFailedTargetingInappIds: failedIds, tagsByInappId: tagsByInappId)
    }

    // MARK: - Queries

    private static let overlayVariant: (InApp) -> MindboxFormVariant? = { inapp in
        inapp.form.variants.first(where: { $0.isOverlayPresentable })
    }

    private func triggerQuery(_ event: ApplicationEvent?, _ candidates: ConfigCandidates) -> TargetingQuery {
        TargetingQuery(
            label: "the trigger",
            prepares: { candidates.renderable },
            candidates: { context in
                guard let event = event else {
                    return self.inappFilterService.filterForTrigger(in: candidates)
                }

                return self.inappFilterService.filterInappsByOperationForShow(event: event,
                                                                             operationInapps: context.operationInapps,
                                                                             in: candidates)
            },
            fetchesDependencies: true,
            collectsFailures: true,
            pickVariant: Self.overlayVariant
        )
    }

    /// The trigger's second question: everyone the event could have targeted, so the funnel hears
    /// about the in-apps a show would never pick — the A/B pool included.
    private func catchUpQuery(_ event: ApplicationEvent?, _ candidates: ConfigCandidates) -> TargetingQuery {
        TargetingQuery(
            label: "the targeting catch-up",
            prepares: { [] },
            candidates: { context in
                let listening: [InApp]
                if let event = event {
                    listening = self.inappFilterService.filterInappsByOperation(event: event,
                                                                                operationInapps: context.operationInapps,
                                                                                in: candidates)
                } else {
                    listening = candidates.renderable
                }
                // Not the direct-call in-apps: vouching for them here would offer every one of them on every start.
                let triggerable = listening.filter { $0.displayConditions != .directCall }
                // Not the pure-embedded ones either: their place resolve vouches, twice would double the funnel (in sync with Android).
                return self.inappFilterService.filterOutNonOverlayInapps(triggerable)
            },
            fetchesDependencies: true,
            collectsFailures: false,
            pickVariant: Self.overlayVariant
        )
    }

    /// Prepares everyone, like the trigger: the session's single segmentation fetch is shaped by whoever
    /// asks first, and a block that waited for the config asks before the start pass does.
    private func placeQuery(_ place: String, _ candidates: ConfigCandidates) -> TargetingQuery {
        TargetingQuery(
            label: "place '\(place)'",
            prepares: { candidates.renderable },
            candidates: { _ in self.inappFilterService.filter(place: place, in: candidates) },
            fetchesDependencies: true,
            collectsFailures: true,
            pickVariant: { $0.form.variants.first { $0.placeSystemName == place } }
        )
    }

    /// Everyone the place could have shown — the A/B cut and the spent frequencies in, the direct-call
    /// in-apps out: the catch-up's rule for one place.
    private func placeTargetingQuery(_ place: String, _ candidates: ConfigCandidates) -> TargetingQuery {
        TargetingQuery(
            label: "targeting at place '\(place)'",
            prepares: { [] },
            candidates: { _ in
                self.inappFilterService.inapps(addressedTo: place, in: candidates)
                    .filter { $0.displayConditions != .directCall }
            },
            fetchesDependencies: false,
            collectsFailures: false,
            pickVariant: { $0.form.variants.first { $0.placeSystemName == place } }
        )
    }

    /// Fetches like a place resolve — a cold cache may miss the page's deadline, an accepted cost.
    private func pageQuery(_ ids: [String], _ candidates: ConfigCandidates) -> TargetingQuery {
        TargetingQuery(
            label: "a page asking about \(ids.count) in-app(s)",
            prepares: { candidates.renderable },
            candidates: { _ in self.inappFilterService.filter(requestedIds: ids, in: candidates) },
            fetchesDependencies: true,
            collectsFailures: false,
            pickVariant: Self.overlayVariant
        )
    }

    /// Everyone the page could have drawn — the A/B cut and the spent frequencies in, so an A/B test on an
    /// in-app the page lists hears from both branches (in sync with Android).
    private func pageTargetingQuery(_ ids: [String], _ candidates: ConfigCandidates) -> TargetingQuery {
        TargetingQuery(
            label: "targeting for the page's \(ids.count) in-app(s)",
            prepares: { [] },
            candidates: { _ in self.inappFilterService.inapps(askedAbout: ids, in: candidates) },
            fetchesDependencies: false,
            collectsFailures: false,
            pickVariant: Self.overlayVariant
        )
    }

    // MARK: - After the trigger's verdict

    private func buildFirstShowable(_ inapps: [InAppTransitionData],
                                    event: ApplicationEvent?,
                                    completion: @escaping (InAppFormData?) -> Void) {
        guard !inapps.isEmpty else {
            completion(nil)
            return
        }

        var formData: InAppFormData?

        DispatchQueue.global().async {
            let operation = Self.operation(from: event)
            for inapp in inapps where formData == nil {
                formData = self.formBuilder.makeFormData(inapp, extraParams: nil, operation: operation)
            }

            DispatchQueue.main.async { [weak self] in
                if let id = formData?.inAppId {
                    self?.dataFacade.trackTargeting(id: id, tags: formData?.tags)
                    self?.$shownInappIDWithHashValue.mutate { $0[id] = Self.eventHash(event) }
                }

                completion(formData)
            }
        }
    }

    private func vouchCatchUp(_ suitable: [InAppTransitionData], event: ApplicationEvent?) {
        Logger.common(message: "[InappMapper] TR | Targeting catch-up for event \(event?.name ?? "start"): \(suitable.map(\.inAppId))",
                      level: .debug, category: .inAppMessages)

        let hash = Self.eventHash(event)
        for inapp in suitable where shownInappIDWithHashValue[inapp.inAppId] != hash {
            dataFacade.trackTargeting(id: inapp.inAppId, tags: inapp.tags)
        }
    }

    /// Everyone the place could have shown hears its `Inapp.Targeting`: the losers once per session,
    /// the winner by the place's slot — showing another in-app and coming back is a new offer.
    private func vouch(_ targeted: [InAppTransitionData], winner: InAppTransitionData?, at place: String) {
        for inapp in targeted {
            guard inapp.inAppId == winner?.inAppId else {
                vouchOncePerSession(for: [inapp])
                continue
            }

            guard SessionTemporaryStorage.shared.ledger.placeTargetedInappId[place] != inapp.inAppId else {
                Logger.common(message: "[InappMapper] In-app \(inapp.inAppId) is still what place '\(place)' vouched for last, no second Inapp.Targeting",
                              level: .debug, category: .inAppMessages)
                continue
            }

            SessionTemporaryStorage.shared.$ledger.mutate {
                $0.placeTargetedInappId[place] = inapp.inAppId
                $0.vouchedInappIds.insert(inapp.inAppId)
            }
            dataFacade.trackTargeting(id: inapp.inAppId, tags: inapp.tags)
        }
    }

    /// Once per session per block and in-app: the same in-app offered by another block is a new offer.
    private func vouchOffers(_ offered: [InAppTransitionData], by blockInappId: String) {
        for inapp in offered {
            let offer = BlockOffer(blockInappId: blockInappId, inappId: inapp.inAppId)
            guard !SessionTemporaryStorage.shared.ledger.vouchedBlockOffers.contains(offer) else { continue }

            SessionTemporaryStorage.shared.$ledger.mutate { $0.vouchedBlockOffers.insert(offer) }
            dataFacade.trackTargeting(id: inapp.inAppId, tags: inapp.tags)
        }
    }

    /// The losers at a place: their resolves repeat without offering anything new, hence once per session.
    private func vouchOncePerSession(for inapps: [InAppTransitionData]) {
        for inapp in inapps {
            guard !SessionTemporaryStorage.shared.ledger.vouchedInappIds.contains(inapp.inAppId) else {
                Logger.common(message: "[InappMapper] In-app \(inapp.inAppId) was already vouched for in this session, no second Inapp.Targeting",
                              level: .debug, category: .inAppMessages)
                continue
            }

            SessionTemporaryStorage.shared.$ledger.mutate { $0.vouchedInappIds.insert(inapp.inAppId) }
            self.dataFacade.trackTargeting(id: inapp.inAppId, tags: inapp.tags)
        }
    }

    private static func eventHash(_ event: ApplicationEvent?) -> Int {
        event?.hashValue ?? InAppMessageTriggerEvent.start.hashValue
    }

    private static func operation(from event: ApplicationEvent?) -> (name: String, body: String)? {
        guard let event = event else { return nil }

        let body: String
        if let model = event.model,
           let data = try? JSONEncoder().encode(model),
           let jsonString = String(data: data, encoding: .utf8) {
            body = jsonString
        } else {
            body = "{}"
        }

        return (name: event.name, body: body)
    }

    // MARK: - Building the form

    private func buildInApp(_ inapp: InAppTransitionData,
                            extraParams: [String: JSONValue],
                            completion: @escaping (InAppFormData?) -> Void) {
        DispatchQueue.global().async {
            let formData = self.formBuilder.makeFormData(inapp, extraParams: extraParams, operation: nil)

            DispatchQueue.main.async {
                completion(formData)
            }
        }
    }
}
