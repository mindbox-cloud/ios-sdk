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
    func getRenderableInappIds(_ ids: [String],
                               _ candidates: ConfigCandidates,
                               _ completion: @escaping (FeedAnswer) -> Void)
    func getInAppToShowById(_ id: String,
                            params: [String: JSONValue],
                            _ candidates: ConfigCandidates,
                            _ completion: @escaping (InAppFormData?) -> Void)
}

class InappMapper: InappMapperProtocol {

    // @Locked: written on the processing queue when a pass sets up its environment, read from the
    // main and global queues by the build/track completions that pass hops through.
    @Locked private var applicationEvent: ApplicationEvent?
    private var targetingChecker: InAppTargetingCheckerProtocol
    private let inappFilterService: InappFilterProtocol
    private let dataFacade: InAppConfigurationDataFacadeProtocol
    private let presentationValidator: InAppPresentationValidatorProtocol

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
    }

    func handleInapps(_ event: ApplicationEvent?,
                      _ candidates: ConfigCandidates,
                      _ completion: @escaping (InAppFormData?) -> Void) {
        processingQueue.async {
            let group = DispatchGroup()
            group.enter()

            Logger.common(message: "[InappMapper] Start handingInapps by event: \(event?.name ?? "start")",
                          level: .debug, category: .inAppMessages)
            self.setupEnvironment(event: event)
            self.prepareTargetingChecker(for: candidates.renderable)
            // Narrowed here rather than in the fetch completion below: that one answers on the main
            // queue, and the frequency reads and their logging have no business there.
            let inapps = self.showableInapps(in: candidates)

            self.chooseInappToShow(inapps) { formData in
                self.sendRemainingInappsTargeting(candidates) {
                    completion(formData)
                    group.leave()
                }
            }
            
            group.wait()
        }
    }

    func selectInappForPlace(_ place: String,
                             trigger: ApplicationEvent?,
                             _ candidates: ConfigCandidates,
                             _ completion: @escaping (InAppTransitionData?) -> Void) {
        let query = TargetingQuery(
            label: "place '\(place)'",
            event: trigger,
            fetchesDependencies: true,
            candidates: {
                self.inappFilterService.filter(place: place, in: candidates)
            },
            pickVariant: { $0.form.variants.first { $0.placeSystemName == place } }
        )

        evaluateTargeting(query) { suitableInapps in
            guard let winner = suitableInapps.first else {
                completion(nil)
                return
            }

            guard self.presentationValidator.isWithinShowBudgets(isPriority: winner.isPriority,
                                                                frequency: winner.frequency,
                                                                id: winner.inAppId) else {
                Logger.common(message: "[InappMapper] In-app \(winner.inAppId) won place '\(place)' but the show budgets are spent, the place stays empty",
                              level: .debug, category: .inAppMessages)
                completion(nil)
                return
            }

            self.vouchOncePerSession(for: [winner])

            completion(winner)
        }
    }

    /// Never goes to the network: answers from what the session already fetched, and an id whose
    /// targeting lacks data is cut — fail closed, in sync with Android.
    func getRenderableInappIds(_ ids: [String],
                               _ candidates: ConfigCandidates,
                               _ completion: @escaping (FeedAnswer) -> Void) {
        let query = TargetingQuery(
            label: "a feed asking about \(ids.count) in-app(s)",
            event: nil,
            fetchesDependencies: false,
            candidates: {
                self.inappFilterService.filter(feedIds: ids, in: candidates)
            },
            pickVariant: { $0.form.variants.first { $0.isOverlayPresentable } }
        )

        evaluateTargeting(query) { allowed in
            // Vouching travels with the answer — only the caller knows it reached the page — and
            // repeats per delivered answer with no session dedup, in sync with Android.
            let answer = FeedAnswer(inappIds: allowed.map(\.inAppId)) { [weak self] in
                for inapp in allowed {
                    self?.dataFacade.trackTargeting(id: inapp.inAppId, tags: inapp.tags)
                }
            }

            completion(answer)
        }
    }

    /// Place path only: its resolves repeat without offering anything new, hence once per session —
    /// unlike a feed, which vouches per delivered answer. The split is an open question with Android.
    private func vouchOncePerSession(for inapps: [InAppTransitionData]) {
        for inapp in inapps {
            guard !SessionTemporaryStorage.shared.vouchedInappIds.contains(inapp.inAppId) else {
                Logger.common(message: "[InappMapper] In-app \(inapp.inAppId) was already vouched for in this session, no second Inapp.Targeting",
                              level: .debug, category: .inAppMessages)
                continue
            }

            SessionTemporaryStorage.shared.$vouchedInappIds.mutate { $0.insert(inapp.inAppId) }
            self.dataFacade.trackTargeting(id: inapp.inAppId, tags: inapp.tags)
        }
    }

    private struct TargetingQuery {

        let label: String

        let event: ApplicationEvent?

        /// A place resolve may fetch geo/segmentations; a feed may not — its page holds a
        /// three-second deadline, and a checker asked without data says "not targeted".
        let fetchesDependencies: Bool

        let candidates: () -> [InApp]
        let pickVariant: (InApp) -> MindboxFormVariant?
    }

    /// One serial queue and one shared targeting checker for every path — two passes in flight would
    /// answer each other's questions.
    private func evaluateTargeting(_ query: TargetingQuery,
                                   completion: @escaping ([InAppTransitionData]) -> Void) {
        processingQueue.async {
            let group = DispatchGroup()
            group.enter()

            self.setupEnvironment(event: query.event)

            let candidates = query.candidates()
            self.prepareTargetingChecker(for: candidates)

            let startedAt = Date()

            let checkTargeting = {
                let suitable = self.inappFilterService.filterInappsByTargeting(
                    inapps: candidates,
                    targetingChecker: self.targetingChecker,
                    pickVariant: query.pickVariant
                )

                let ms = Int(Date().timeIntervalSince(startedAt) * 1000)
                Logger.common(message: """
                [InappMapper] \(query.label): \(candidates.count) candidate(s), \(suitable.count) targeted, \
                answered in \(ms) ms.
                """, level: .debug, category: .inAppMessages)

                completion(suitable)
                group.leave()
            }

            if query.fetchesDependencies {
                self.dataFacade.fetchDependencies(model: query.event?.model, checkTargeting)
            } else {
                checkTargeting()
            }

            group.wait()
        }
    }

    /// Nothing checked, display conditions included: a direct call may show anything the config holds.
    func getInAppById(_ id: String,
                      _ candidates: ConfigCandidates,
                      _ completion: @escaping (InAppTransitionData?) -> Void) {
        processingQueue.async {
            guard let inapp = self.inappFilterService.filter(id: id, in: candidates) else {
                completion(nil)
                return
            }

            guard let variant = inapp.form.variants.first else {
                Logger.common(message: "[InappMapper] In-app \(id) has no variant left to render.",
                              level: .error, category: .inAppMessages)
                completion(nil)
                return
            }

            completion(InAppTransitionData(inAppId: inapp.id,
                                           isPriority: inapp.isPriority,
                                           delayTime: inapp.delayTime,
                                           content: variant,
                                           frequency: inapp.frequency,
                                           tags: inapp.tags))
        }
    }

    /// Show history is deliberately not consulted: the page already offered this in-app, and a tap
    /// has to open it however many times it opened before.
    func getInAppToShowById(_ id: String,
                            params: [String: JSONValue],
                            _ candidates: ConfigCandidates,
                            _ completion: @escaping (InAppFormData?) -> Void) {
        getInAppById(id, candidates) { transitionData in
            guard let transitionData = transitionData else {
                completion(nil)
                return
            }

            guard transitionData.content.isOverlayPresentable else {
                Logger.common(message: "[InappMapper] In-app \(id) is drawn inside the host layout and cannot be shown over the screen.",
                              level: .error, category: .inAppMessages)
                completion(nil)
                return
            }

            self.buildInApp(transitionData, extraParams: params, completion: completion)
        }
    }

    private func setupEnvironment(event: ApplicationEvent?) {
        applicationEvent = event
        targetingChecker.event = event
    }

    private func prepareTargetingChecker(for inapps: [InApp]) {
        inapps.forEach {
            targetingChecker.prepare(id: $0.id, targeting: $0.targeting)
        }
    }

    private func showableInapps(in candidates: ConfigCandidates) -> [InApp] {
        guard let event = applicationEvent else {
            return inappFilterService.filterForTrigger(in: candidates)
        }

        return inappFilterService.filterInappsByOperationForShow(
            event: event,
            operationInapps: targetingChecker.context.operationInapps,
            in: candidates
        )
    }

    private func chooseInappToShow(_ inapps: [InApp], completion: @escaping (InAppFormData?) -> Void) {
        dataFacade.fetchDependencies(model: applicationEvent?.model) {
            let suitableInapps = self.inappFilterService.filterInappsByTargeting(inapps: inapps, targetingChecker: self.targetingChecker)
            let suitableIds = Set(suitableInapps.map(\.inAppId))
            let failedTargetingInappIds = Set(inapps.map(\.id)).subtracting(suitableIds)
            let tagsByInappId: [String: [String: String]] = inapps.reduce(into: [:]) { result, inapp in
                guard failedTargetingInappIds.contains(inapp.id), let tags = inapp.tags else { return }
                result[inapp.id] = tags
            }
            self.dataFacade.collectTargetingFailures(forFailedTargetingInappIds: failedTargetingInappIds, tagsByInappId: tagsByInappId)

            if suitableInapps.isEmpty {
                completion(nil)
                return
            }

            self.buildInAppByEvent(inapps: suitableInapps) { formData in
                completion(formData)
            }
        }
    }

    private func buildInAppByEvent(inapps: [InAppTransitionData],
                                   completion: @escaping (InAppFormData?) -> Void) {
        var formData: InAppFormData?

        DispatchQueue.global().async {
            for inapp in inapps where formData == nil {
                formData = self.makeFormData(inapp, extraParams: nil)
            }

            DispatchQueue.main.async { [weak self] in
                if let id = formData?.inAppId {
                    self?.dataFacade.trackTargeting(id: id, tags: formData?.tags)
                    self?.$shownInappIDWithHashValue.mutate { $0[id] = self?.getEventHashValue() }
                }

                completion(formData)
            }
        }
    }

    /// Blocking by design — callers walk a list and stop at the first buildable in-app. Must not run
    /// on `processingQueue`: a download wait there would stall every targeting question behind it.
    private func makeFormData(_ inapp: InAppTransitionData, extraParams: [String: JSONValue]?) -> InAppFormData? {
        Logger.common(message: "[InappMapper] Starting in-app processing. [ID]: \(inapp.inAppId)", level: .debug, category: .inAppMessages)

        if case .modal(let modal) = inapp.content,
           modal.content.background.layers.contains(where: { $0.layerType == .webview }) {
            return InAppFormData(inAppId: inapp.inAppId,
                                 isPriority: inapp.isPriority,
                                 delayTime: inapp.delayTime,
                                 imagesDict: [:],
                                 firstImageValue: "",
                                 content: inapp.content,
                                 frequency: inapp.frequency,
                                 tags: inapp.tags,
                                 operation: getOperation(),
                                 extraParams: extraParams)
        }

        let urlExtractorService = DI.injectOrFail(VariantImageUrlExtractorServiceProtocol.self)
        let imageValues = urlExtractorService.extractImageURL(from: inapp.content)

        let group = DispatchGroup()
        let imageDictQueue = DispatchQueue(label: "com.mindbox.imagedict.queue", attributes: .concurrent)
        var imageDict: [String: UIImage] = [:]
        var gotError = false

        for imageValue in imageValues {
            group.enter()
            Logger.common(message: "[InappMapper] Initiating the process of image loading from the URL: \(imageValue)", level: .debug, category: .inAppMessages)
            dataFacade.downloadImage(withUrl: imageValue, inappId: inapp.inAppId, tags: inapp.tags) { result in
                defer {
                    group.leave()
                }

                switch result {
                case .success(let image):
                    imageDictQueue.async(flags: .barrier) {
                        imageDict[imageValue] = image
                    }
                case .failure:
                    gotError = true
                }
            }
        }

        group.wait()

        return imageDictQueue.sync {
            guard !imageDict.isEmpty, !gotError else { return nil }

            return InAppFormData(inAppId: inapp.inAppId,
                                 isPriority: inapp.isPriority,
                                 delayTime: inapp.delayTime,
                                 imagesDict: imageDict,
                                 firstImageValue: imageValues.first ?? "",
                                 content: inapp.content,
                                 frequency: inapp.frequency,
                                 tags: inapp.tags,
                                 operation: getOperation(),
                                 extraParams: extraParams)
        }
    }

    private func buildInApp(_ inapp: InAppTransitionData,
                            extraParams: [String: JSONValue],
                            completion: @escaping (InAppFormData?) -> Void) {
        DispatchQueue.global().async {
            let formData = self.makeFormData(inapp, extraParams: extraParams)

            DispatchQueue.main.async {
                completion(formData)
            }
        }
    }

    private func getEventHashValue() -> Int {
        return applicationEvent?.hashValue ?? InAppMessageTriggerEvent.start.hashValue
    }

    private func getOperation() -> (name: String, body: String)? {
        guard let event = applicationEvent else { return nil }

        let name = event.name
        let body: String

        if let model = event.model,
           let data = try? JSONEncoder().encode(model),
           let jsonString = String(data: data, encoding: .utf8) {
            body = jsonString
        } else {
            body = "{}"
        }

        return (name: name, body: body)
    }

    private func sendRemainingInappsTargeting(_ candidates: ConfigCandidates, _ completion: @escaping () -> Void) {
        self.dataFacade.fetchDependencies(model: applicationEvent?.model, shouldCollectFailures: false) {
            let inapps: [InApp]
            if let event = self.applicationEvent {
                inapps = self.inappFilterService.filterInappsByOperation(
                    event: event,
                    operationInapps: self.targetingChecker.context.operationInapps,
                    in: candidates
                )
            } else {
                inapps = candidates.renderable
            }
            // A direct-call in-app answers no trigger, so the catch-up does not vouch for it either —
            // otherwise every start would pump the story funnel with every user.
            let triggerable = inapps.filter { $0.displayConditions != .directCall }
            // A pure-embedded in-app is vouched by its place resolve — speaking here too would double
            // the funnel. A mixed form stays: the catch-up covers its overlay half (in sync with Android).
            let catchUpCandidates = self.inappFilterService.filterOutNonOverlayInapps(triggerable)
            let suitableInapps = self.inappFilterService.filterInappsByTargeting(inapps: catchUpCandidates, targetingChecker: self.targetingChecker)

            let logMessage = """
            [InappMapper] TR | Initiating processing of remaining in-app targeting requests.
                 Full list of in-app messages: \(candidates.renderable.map { $0.id })
                 Saved event for targeting: \(self.applicationEvent?.name ?? "None")
            """
            Logger.common(message: logMessage, level: .debug, category: .inAppMessages)

            for inapp in suitableInapps {
                if self.shownInappIDWithHashValue[inapp.inAppId] != self.getEventHashValue(),
                   let inapp = candidates.renderable.first(where: { $0.id == inapp.inAppId }),
                    self.targetingChecker.check(targeting: inapp.targeting) {
                       self.dataFacade.trackTargeting(id: inapp.id, tags: inapp.tags)
                }
            }
            
            completion()
        }
    }
}
