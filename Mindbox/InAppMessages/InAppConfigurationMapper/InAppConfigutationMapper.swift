//
//  InAppConfigutationMapper.swift
//  Mindbox
//
//  Created by Максим Казаков on 12.09.2022.
//

import Foundation
import MindboxLogger
import UIKit

protocol InAppConfigurationMapperProtocol {
    func mapConfigResponse(_ event: ApplicationEvent?, _ response: ConfigResponse, _ completion: @escaping (InAppFormData?) -> Void)
    var targetingChecker: InAppTargetingCheckerProtocol { get set }
    func sendRemainingInappsTargeting()
}

final class InAppConfigutationMapper: InAppConfigurationMapperProtocol {

    var targetingChecker: InAppTargetingCheckerProtocol
    var filteredInAppsByEvent: [InAppMessageTriggerEvent: [InAppTransitionData]] = [:]
    var filteredInappsByEventForTargeting: [InAppMessageTriggerEvent: [InAppTransitionData]] = [:]

    let dataFacade: InAppConfigurationDataFacadeProtocol

    private let inappFilterService: InappFilterProtocol
    private var validInapps: [InApp] = []
    private var savedEventForTargeting: ApplicationEvent?
    private var shownInnapId = ""

    init(inappFilterService: InappFilterProtocol,
         targetingChecker: InAppTargetingCheckerProtocol,
         dataFacade: InAppConfigurationDataFacadeProtocol) {
        self.inappFilterService = inappFilterService
        self.targetingChecker = targetingChecker
        self.dataFacade = dataFacade
    }

    /// Maps config response to business-logic handy InAppConfig model
    func mapConfigResponse(_ event: ApplicationEvent?,
                           _ response: ConfigResponse,
                           _ completion: @escaping (InAppFormData?) -> Void) {
        savedEventForTargeting = event
        self.targetingChecker.event = nil

        let filteredInapps = inappFilterService.filter(inapps: response.inapps?.elements, abTests: response.abtests)
        validInapps = inappFilterService.validInapps

        targetingChecker.event = event
        prepareTargetingChecker(for: filteredInapps)

        prepareForRemainingTargeting()

        dataFacade.setObservedOperation()

        if filteredInapps.isEmpty {
            Logger.common(message: "No inapps to show", level: .debug, category: .inAppMessages)
            completion(nil)
            return
        }

        dataFacade.fetchDependencies(model: event?.model) {
            self.filterByInappsEvents(inapps: filteredInapps, filteredInAppsByEvent: &self.filteredInAppsByEvent)
            if let event = event {
                if let inappsByEvent = self.filteredInAppsByEvent[.applicationEvent(event)] {
                    self.buildInAppByEvent(inapps: inappsByEvent) { formData in
                        completion(formData)
                    }
                } else {
                    Logger.common(message: "filteredInAppsByEvent is empty")
                    completion(nil)
                }
            } else if let inappsByEvent = self.filteredInAppsByEvent[.start] {
                self.buildInAppByEvent(inapps: inappsByEvent) { formData in
                    completion(formData)
                }
            } else {
                completion(nil)
            }
        }
    }

    func prepareForRemainingTargeting() {
        let estimatedInapps = validInapps
        prepareTargetingChecker(for: estimatedInapps)
    }

    func sendRemainingInappsTargeting() {
        self.dataFacade.fetchDependencies(model: savedEventForTargeting?.model) {
            self.filterByInappsEvents(inapps: self.validInapps,
                                      filteredInAppsByEvent: &self.filteredInappsByEventForTargeting)

            let logMessage = """
            TR | Initiating processing of remaining in-app targeting requests.
                 Full list of in-app messages: \(self.validInapps.map { $0.id })
                 Saved event for targeting: \(self.savedEventForTargeting?.name ?? "None")
            """
            Logger.common(message: logMessage, level: .debug, category: .inAppMessages)

            var targetedEventKey: InAppMessageTriggerEvent

            if let savedEventForTargeting = self.savedEventForTargeting {
                targetedEventKey = .applicationEvent(savedEventForTargeting)
            } else {
                targetedEventKey = .start
            }

            guard let inappsByEvent = self.filteredInappsByEventForTargeting[targetedEventKey] else {
                return
            }

            let preparedForTrackTargetingInapps: Set<String> = Set(self.validInapps.compactMap { inapp -> String? in
                guard inapp.id != self.shownInnapId,
                      inappsByEvent.contains(where: { $0.inAppId == inapp.id }),
                      self.targetingChecker.check(targeting: inapp.targeting) else {
                    return nil
                }
                return inapp.id
            })

            Logger.common(message: "TR | In-apps selected for targeting requests: \(preparedForTrackTargetingInapps)", level: .debug, category: .inAppMessages)

            preparedForTrackTargetingInapps.forEach { id in
                self.dataFacade.trackTargeting(id: id)
            }

            self.shownInnapId = ""
        }
    }

    private func prepareTargetingChecker(for inapps: [InApp]) {
        inapps.forEach({
            targetingChecker.prepare(targeting: $0.targeting)
        })
    }

    func filterByInappsEvents(inapps: [InApp], filteredInAppsByEvent: inout [InAppMessageTriggerEvent: [InAppTransitionData]]) {
        for inapp in inapps {
            var triggerEvent: InAppMessageTriggerEvent = .start

            let inAppAlreadyAddedForEvent = filteredInAppsByEvent[triggerEvent]?.contains(where: { $0.inAppId == inapp.id }) ?? false

            // If the in-app message has already been added, continue to the next message
            guard !inAppAlreadyAddedForEvent else {
                continue
            }

            guard targetingChecker.check(targeting: inapp.targeting) else {
                continue
            }

            if let event = targetingChecker.event {
                triggerEvent = .applicationEvent(event)
            }

            var inAppsForEvent = filteredInAppsByEvent[triggerEvent] ?? [InAppTransitionData]()
            if let inAppFormVariants = inapp.form.variants.first {
                let formData = InAppTransitionData(inAppId: inapp.id,
                                                   content: inAppFormVariants)
                inAppsForEvent.append(formData)
                filteredInAppsByEvent[triggerEvent] = inAppsForEvent
            }
        }
    }

    private func buildInAppByEvent(inapps: [InAppTransitionData],
                                   completion: @escaping (InAppFormData?) -> Void) {
        var formData: InAppFormData?
        let group = DispatchGroup()
        let imageDictQueue = DispatchQueue(label: "com.mindbox.imagedict.queue", attributes: .concurrent)

        // FIXME: Rewrite this closure in the future
        // swiftlint:disable:next closure_body_length
        DispatchQueue.global().async {
            for inapp in inapps {

                guard formData == nil else {
                    break
                }

                var imageDict: [String: UIImage] = [:]
                var gotError = false

                if self.inappFilterService.shownInAppDictionary[inapp.inAppId] != nil {
                    continue
                }

                let urlExtractorService = DI.injectOrFail(VariantImageUrlExtractorServiceProtocol.self)
                let imageValues = urlExtractorService.extractImageURL(from: inapp.content)

                Logger.common(message: "Starting in-app processing. [ID]: \(inapp.inAppId)", level: .debug, category: .inAppMessages)
                for imageValue in imageValues {
                    group.enter()
                    Logger.common(message: "Initiating the process of image loading from the URL: \(imageValue)", level: .debug, category: .inAppMessages)
                    self.dataFacade.downloadImage(withUrl: imageValue) { result in
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

                imageDictQueue.sync {
                    if !imageDict.isEmpty && !gotError {
                        let firstImageValue = imageValues.first ?? ""
                        formData = InAppFormData(inAppId: inapp.inAppId, imagesDict: imageDict, firstImageValue: firstImageValue, content: inapp.content)
                    }
                }
            }

            group.notify(queue: .main) {
                DispatchQueue.main.async { [weak self] in
                    if !SessionTemporaryStorage.shared.isPresentingInAppMessage {
                        self?.shownInnapId = formData?.inAppId ?? ""
                        self?.dataFacade.trackTargeting(id: formData?.inAppId)
                    }

                    completion(formData)
                }
            }
        }
    }
}
