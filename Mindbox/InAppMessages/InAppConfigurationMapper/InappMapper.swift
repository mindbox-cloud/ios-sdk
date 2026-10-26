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
                             _ completion: @escaping (EmbeddedPlaceSelection) -> Void)
    func getShowableInappIds(_ ids: [String],
                             askedBy requesterInappId: String,
                             _ candidates: ConfigCandidates,
                             _ completion: @escaping ([String]) -> Void)
}

class InappMapper: InappMapperProtocol {

    private var targetingChecker: InAppTargetingCheckerProtocol
    private let inappFilterService: InappFilterProtocol
    private let dataFacade: InAppConfigurationDataFacadeProtocol
    private let formBuilder: InappFormBuilder

    @Locked private var shownInappIDWithHashValue: [String: Int] = [:]

    private let processingQueue = DispatchQueue(label: "com.Mindbox.inAppMapper.processingQueue")

    init(targetingChecker: InAppTargetingCheckerProtocol,
         inappFilterService: InappFilterProtocol,
         dataFacade: InAppConfigurationDataFacadeProtocol) {
        self.targetingChecker = targetingChecker
        self.inappFilterService = inappFilterService
        self.dataFacade = dataFacade
        self.formBuilder = InappFormBuilder(dataFacade: dataFacade, imageFailures: .bufferedForThePass)
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
                             _ completion: @escaping (EmbeddedPlaceSelection) -> Void) {
        runPass("place '\(place)'", event: trigger) { finish in
            self.evaluate(self.placeQuery(place, candidates), event: trigger) { verdict, cutByFetchFailure in
                self.evaluate(self.placeTargetingQuery(place, candidates), event: trigger) { targeted in
                    let winner = verdict.first
                    self.vouch(targeted, winner: winner, at: place)

                    guard let winner else {
                        finish(false)
                        completion(cutByFetchFailure ? .targetingUnavailable : .decided(nil))
                        return
                    }

                    finish(true)
                    completion(.decided(winner))
                }
            }
        }
    }

    func getShowableInappIds(_ ids: [String],
                             askedBy requesterInappId: String,
                             _ candidates: ConfigCandidates,
                             _ completion: @escaping ([String]) -> Void) {
        runPass("a page of in-app \(requesterInappId) asking about \(ids.count) in-app(s)", event: nil) { finish in
            self.evaluate(self.pageQuery(ids, candidates), event: nil) { verdict in
                self.evaluate(self.pageTargetingQuery(ids, candidates), event: nil) { offered in
                    finish(false)
                    self.vouchOffers(offered, by: requesterInappId)
                    completion(verdict.map(\.inAppId))
                }
            }
        }
    }

    // MARK: - The pass

    private func runPass(_ label: String,
                         event: ApplicationEvent?,
                         _ body: @escaping (_ finish: @escaping (_ selected: Bool) -> Void) -> Void) {
        processingQueue.async {
            let group = DispatchGroup()
            group.enter()

            Logger.common(message: "[InappMapper] Pass for \(label) by event: \(event?.name ?? "start")",
                          level: .debug, category: .inAppMessages)
            self.targetingChecker.event = event

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

    private struct TargetingQuery {

        let label: String

        let prepares: () -> [InApp]

        let candidates: (PreparationContext) -> [InApp]

        let fetchesDependencies: Bool

        let collectsFailures: Bool

        let pickVariant: (InApp) -> MindboxFormVariant?
    }

    private func evaluate(_ query: TargetingQuery,
                          event: ApplicationEvent?,
                          completion: @escaping ([InAppTransitionData]) -> Void) {
        evaluate(query, event: event) { suitable, _ in completion(suitable) }
    }

    private func evaluate(_ query: TargetingQuery,
                          event: ApplicationEvent?,
                          completion: @escaping ([InAppTransitionData], _ cutByFetchFailure: Bool) -> Void) {
        let prepared = query.prepares()
        prepared.forEach { targetingChecker.prepare(id: $0.id, targeting: $0.targeting) }

        let candidates = query.candidates(targetingChecker.context)
        let startedAt = Date()

        let check = {
            let suitable = self.inappFilterService.filterInappsByTargeting(inapps: candidates,
                                                                           targetingChecker: self.targetingChecker,
                                                                           pickVariant: query.pickVariant)
            let cutByFetchFailure = query.collectsFailures
                ? self.collectTargetingFailures(among: candidates, suitable: suitable)
                : false

            let ms = Int(Date().timeIntervalSince(startedAt) * 1000)
            Logger.common(message: """
            [InappMapper] \(query.label): \(candidates.count) candidate(s), \(suitable.count) targeted, \
            answered in \(ms) ms.
            """, level: .debug, category: .inAppMessages)

            completion(suitable, cutByFetchFailure)
        }

        if query.fetchesDependencies {
            dataFacade.fetchDependencies(model: event?.model, shouldCollectFailures: query.collectsFailures, check)
        } else {
            check()
        }
    }

    private func collectTargetingFailures(among candidates: [InApp], suitable: [InAppTransitionData]) -> Bool {
        let suitableIds = Set(suitable.map(\.inAppId))
        let failedIds = Set(candidates.map(\.id)).subtracting(suitableIds)
        let tagsByInappId: [String: [String: String]] = candidates.reduce(into: [:]) { result, inapp in
            guard failedIds.contains(inapp.id), let tags = inapp.tags else { return }
            result[inapp.id] = tags
        }
        return dataFacade.collectTargetingFailures(forFailedTargetingInappIds: failedIds, tagsByInappId: tagsByInappId)
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
                let triggerable = listening.filter { $0.displayConditions != .directCall }
                return self.inappFilterService.filterOutNonOverlayInapps(triggerable)
            },
            fetchesDependencies: true,
            collectsFailures: false,
            pickVariant: Self.overlayVariant
        )
    }

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

    private func vouch(_ targeted: [InAppTransitionData], winner: InAppTransitionData?, at place: String) {
        for inapp in targeted {
            guard inapp.inAppId == winner?.inAppId else {
                vouchOncePerSession(for: [inapp])
                continue
            }

            guard SessionTemporaryStorage.shared.$ledger.mutate({ $0.vouchWinner(inapp.inAppId, at: place) }) else {
                Logger.common(message: "[InappMapper] In-app \(inapp.inAppId) is still what place '\(place)' vouched for last, no second Inapp.Targeting",
                              level: .debug, category: .inAppMessages)
                continue
            }

            dataFacade.trackTargeting(id: inapp.inAppId, tags: inapp.tags)
        }
    }

    private func vouchOffers(_ offered: [InAppTransitionData], by requesterInappId: String) {
        for inapp in offered {
            let offer = PageOffer(requesterInappId: requesterInappId, inappId: inapp.inAppId)
            guard SessionTemporaryStorage.shared.$ledger.mutate({ $0.vouchOffer(offer) }) else { continue }

            dataFacade.trackTargeting(id: inapp.inAppId, tags: inapp.tags)
        }
    }

    private func vouchOncePerSession(for inapps: [InAppTransitionData]) {
        for inapp in inapps {
            guard SessionTemporaryStorage.shared.$ledger.mutate({ $0.vouch(inapp.inAppId) }) else {
                Logger.common(message: "[InappMapper] In-app \(inapp.inAppId) was already vouched for in this session, no second Inapp.Targeting",
                              level: .debug, category: .inAppMessages)
                continue
            }

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
}
