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
                      _ response: ConfigResponse,
                      _ completion: @escaping (InAppFormData?) -> Void)
    func selectInappForPlace(_ place: String,
                             trigger: ApplicationEvent?,
                             _ response: ConfigResponse,
                             _ completion: @escaping (InAppTransitionData?) -> Void)
    func getInAppById(_ id: String,
                      _ response: ConfigResponse,
                      _ completion: @escaping (InAppTransitionData?) -> Void)
    func getRenderableInappIds(_ ids: [String],
                               _ response: ConfigResponse,
                               _ completion: @escaping (FeedAnswer) -> Void)
    func getInAppToShowById(_ id: String,
                            params: [String: JSONValue],
                            _ response: ConfigResponse,
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
    @Locked private var abTests: [ABTest]?
    
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
                      _ response: ConfigResponse,
                      _ completion: @escaping (InAppFormData?) -> Void) {
        processingQueue.async {
            let group = DispatchGroup()
            group.enter()

            Logger.common(message: "[InappMapper] Start handingInapps by event: \(event?.name ?? "start")",
                          level: .debug, category: .inAppMessages)
            self.setupEnvironment(event: event)
            self.abTests = response.abtests
            let filteredInapps = self.getFilteredInapps(inappsDTO: response.inapps?.elements, abTests: response.abtests)
            self.prepareTargetingChecker(for: filteredInapps)
            self.prepareForRemainingTargeting()

            self.chooseInappToShow(filteredInapps: filteredInapps) { formData in
                self.sendRemainingInappsTargeting {
                    completion(formData)
                    group.leave()
                }
            }
            
            group.wait()
        }
    }

    /// What a block at this place should show, or `nil` for "nothing to show" — which for a block is an
    /// outcome, not an error.
    ///
    /// Runs on the same serial queue as the trigger path. That is not incidental: the targeting checker
    /// is one shared instance holding the event it was prepared with, so two resolves in flight at once
    /// would answer each other's questions.
    ///
    /// The trigger is a parameter because the push side calls this with the operation that just
    /// happened, and pull calls it with nothing at all.
    func selectInappForPlace(_ place: String,
                             trigger: ApplicationEvent?,
                             _ response: ConfigResponse,
                             _ completion: @escaping (InAppTransitionData?) -> Void) {
        let query = TargetingQuery(
            label: "place '\(place)'",
            event: trigger,
            response: response,
            fetchesDependencies: true,
            candidates: {
                self.inappFilterService.filter(place: place,
                                               inapps: response.inapps?.elements,
                                               abTests: response.abtests)
            },
            pickVariant: { $0.form.variants.first { $0.placeSystemName == place } }
        )

        evaluateTargeting(query) { suitableInapps in
            // Two candidates for one place is a legitimate config, and the answer is the first by
            // priority. The rest are not queued anywhere: a block shows one thing at a time and asks
            // again when it needs to.
            guard let winner = suitableInapps.first else {
                completion(nil)
                return
            }

            // Checked on the winner and not as a filter, because the budgets are shared: what stops one
            // candidate stops the next.
            guard self.presentationValidator.isWithinShowBudgets(isPriority: winner.isPriority,
                                                                frequency: winner.frequency,
                                                                id: winner.inAppId) else {
                Logger.common(message: "[InappMapper] In-app \(winner.inAppId) won place '\(place)' but the show budgets are spent, the place stays empty",
                              level: .debug, category: .inAppMessages)
                completion(nil)
                return
            }

            // Vouching comes after the budgets: an in-app the place did not get was not offered.
            self.vouchOncePerSession(for: [winner])

            completion(winner)
        }
    }

    /// Which of `ids` a feed may draw.
    ///
    /// Same queue and same shared targeting checker as every other path, but this one never goes to
    /// the network: the answer comes from what the session has already fetched, and an id whose
    /// targeting needs data that is not there is cut — the wire contract's fail closed, in sync with
    /// Android. The place resolve that built the page has fetched the same dependencies moments
    /// earlier, so a cold cache here means that fetch failed, and retrying it is not this question's
    /// job.
    func getRenderableInappIds(_ ids: [String],
                               _ response: ConfigResponse,
                               _ completion: @escaping (FeedAnswer) -> Void) {
        let query = TargetingQuery(
            label: "a feed asking about \(ids.count) in-app(s)",
            // No event: a feed asks about itself. Its stories answer no trigger — that is what makes
            // them direct-call — so there is nothing for an operation to add to the question.
            event: nil,
            response: response,
            fetchesDependencies: false,
            candidates: {
                self.inappFilterService.filter(feedIds: ids,
                                               inapps: response.inapps?.elements,
                                               abTests: response.abtests)
            },
            pickVariant: { $0.form.variants.first { $0.isOverlayPresentable } }
        )

        evaluateTargeting(query) { allowed in
            // The vouching travels with the answer instead of happening here, because the caller is the
            // one who knows whether the answer reached the page at all.
            //
            // Every delivered answer vouches anew, with no per-session dedup — the same rule the
            // operation targeting of overlays lives by, where every occurrence is a new offer. A feed's
            // occurrence is its question: a page that asks again is drawing the feed again (in sync
            // with Android, which also sends per answer).
            let answer = FeedAnswer(inappIds: allowed.map(\.inAppId)) { [weak self] in
                for inapp in allowed {
                    self?.dataFacade.trackTargeting(id: inapp.inAppId, tags: inapp.tags)
                }
            }

            completion(answer)
        }
    }

    /// Sends `Inapp.Targeting` for in-apps that have not been vouched for in this session yet.
    ///
    /// The place path only. Its resolves repeat for reasons that offer nothing new — the block
    /// reappears, a config lands, an operation passes by — so the winner is vouched for once per
    /// session. A feed's question is different: each one redraws the feed, so its vouching happens per
    /// delivered answer, above. Whether this split is right is an open question with Android.
    private func vouchOncePerSession(for inapps: [InAppTransitionData]) {
        for inapp in inapps {
            guard !SessionTemporaryStorage.shared.vouchedInappIds.contains(inapp.inAppId) else {
                Logger.common(message: "[InappMapper] In-app \(inapp.inAppId) was already vouched for in this session, no second Inapp.Targeting",
                              level: .debug, category: .inAppMessages)
                continue
            }

            SessionTemporaryStorage.shared.vouchedInappIds.insert(inapp.inAppId)
            self.dataFacade.trackTargeting(id: inapp.inAppId, tags: inapp.tags)
        }
    }

    /// A question that ends in "who is targeted". The callers differ only in which candidates they
    /// start from and which variant they are going to render.
    private struct TargetingQuery {

        /// How the question names itself in the log.
        let label: String

        let event: ApplicationEvent?
        let response: ConfigResponse

        /// Whether the pass may go to the network for geo and segmentations before checking.
        ///
        /// A place resolve may: nothing is waiting on it but a shimmer. A feed's question may not —
        /// the page holds a three-second deadline, and an answer that waited out a request is an
        /// answer to nobody. A checker asked without its data says "not targeted", so the id is cut.
        let fetchesDependencies: Bool

        let candidates: () -> [InApp]
        let pickVariant: (InApp) -> MindboxFormVariant?
    }

    /// The shared shape of answering one: one serial queue, one environment, one targeting pass.
    /// Sharing it is the point — a feed and a trigger disagreeing about who is targeted would be a
    /// defect nobody could explain.
    ///
    /// The elapsed time is logged on purpose. A feed page gives up after three seconds, and whether
    /// that budget is ever really at risk is a question for measurements, not for guesses.
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

    /// The content behind an id, with nothing checked — display conditions included. A direct call is
    /// allowed to show anything the config holds, whatever it says about triggers.
    func getInAppById(_ id: String,
                      _ response: ConfigResponse,
                      _ completion: @escaping (InAppTransitionData?) -> Void) {
        processingQueue.async {
            guard let inapp = self.inappFilterService.filter(id: id, inapps: response.inapps?.elements) else {
                completion(nil)
                return
            }

            // Any variant, not only an overlay one: whether a variant can actually be shown is the
            // caller's check, applied below by the overlay path. Keeping a feed from opening inside a
            // feed is the feed's job, done where it answers which of its stories may be shown.
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

    /// Everything needed to show the in-app behind an id, ready for the presenter.
    ///
    /// The history of shows is deliberately not consulted. On the trigger path an in-app that was
    /// already shown is skipped, and that is right there — but here the page has already offered this
    /// in-app to the user, and what they just tapped has to open, however many times it opened before.
    func getInAppToShowById(_ id: String,
                            params: [String: JSONValue],
                            _ response: ConfigResponse,
                            _ completion: @escaping (InAppFormData?) -> Void) {
        getInAppById(id, response) { transitionData in
            guard let transitionData = transitionData else {
                completion(nil)
                return
            }

            // `getInAppById` resolves blocks too, but this path ends in the overlay displayer, and a
            // variant drawn inside the host layout has nothing it could show there. Without the guard
            // the build fails further down with no images and no explanation for why a tap did nothing.
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

    private func getFilteredInapps(inappsDTO: [InAppDTO]?, abTests: [ABTest]?) -> [InApp] {
        inappFilterService.filter(inapps: inappsDTO, abTests: abTests)
    }

    private func prepareTargetingChecker(for inapps: [InApp]) {
        inapps.forEach {
            targetingChecker.prepare(id: $0.id, targeting: $0.targeting)
        }
    }

    private func prepareForRemainingTargeting() {
        let estimatedInapps = inappFilterService.validInapps
        prepareTargetingChecker(for: estimatedInapps)
    }

    private func chooseInappToShow(filteredInapps: [InApp], completion: @escaping (InAppFormData?) -> Void) {
        dataFacade.fetchDependencies(model: applicationEvent?.model) {
            let inapps = self.applicationEvent == nil ? filteredInapps : self.inappFilterService.filterInappsByOperationForShow(
                event: self.applicationEvent,
                abTests: self.abTests,
                operationInapps: self.targetingChecker.context.operationInapps
            )
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
                    self?.shownInappIDWithHashValue[id] = self?.getEventHashValue()
                }

                completion(formData)
            }
        }
    }

    /// Turns a chosen in-app into everything the presenter needs, downloading its images on the way.
    ///
    /// Blocking, and deliberately so: the callers walk a list and stop at the first in-app that could be
    /// built. Must not be called on `processingQueue` — waiting for a download there would stall every
    /// targeting question behind it.
    private func makeFormData(_ inapp: InAppTransitionData, extraParams: [String: JSONValue]?) -> InAppFormData? {
        Logger.common(message: "[InappMapper] Starting in-app processing. [ID]: \(inapp.inAppId)", level: .debug, category: .inAppMessages)

        // A web page draws itself: there is nothing for the SDK to fetch, and waiting for images that do
        // not exist would only delay the show.
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

    /// The direct-call counterpart: off the serial queue, answered on the main thread.
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

    func sendRemainingInappsTargeting(_ completion: @escaping () -> Void) {
        self.dataFacade.fetchDependencies(model: applicationEvent?.model, shouldCollectFailures: false) {
            let inapps = self.applicationEvent == nil ? self.inappFilterService.validInapps : self.inappFilterService.filterInappsByOperation(
                event: self.applicationEvent,
                operationInapps: self.targetingChecker.context.operationInapps
            )
            // A direct-call in-app answers no trigger, so the catch-up does not vouch for it either:
            // otherwise every start would pump the story funnel with every user, block or no block.
            let triggerable = inapps.filter { $0.displayConditions != .directCall }
            let suitableInapps = self.inappFilterService.filterInappsByTargeting(inapps: triggerable, targetingChecker: self.targetingChecker)

            let logMessage = """
            [InappMapper] TR | Initiating processing of remaining in-app targeting requests.
                 Full list of in-app messages: \(self.inappFilterService.validInapps.map { $0.id })
                 Saved event for targeting: \(self.applicationEvent?.name ?? "None")
            """
            Logger.common(message: logMessage, level: .debug, category: .inAppMessages)

            for inapp in suitableInapps {
                if self.shownInappIDWithHashValue[inapp.inAppId] != self.getEventHashValue(),
                   let inapp = self.inappFilterService.validInapps.first(where: { $0.id == inapp.inAppId }),
                    self.targetingChecker.check(targeting: inapp.targeting) {
                       self.dataFacade.trackTargeting(id: inapp.id, tags: inapp.tags)
                }
            }
            
            completion()
        }
    }
}
