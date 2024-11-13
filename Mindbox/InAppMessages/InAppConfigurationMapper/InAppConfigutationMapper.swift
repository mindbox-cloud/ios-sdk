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

    var shownInAppIdsWithEvents: [String: Int] = [:]

    let dataFacade: InAppConfigurationDataFacadeProtocol

    private let inappFilterService: InappFilterProtocol
    private var validInapps: [InApp] = []
    private var savedEventForTargeting: ApplicationEvent?

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
            var suitableInapps: [InAppTransitionData] = []
            if let event = self.savedEventForTargeting {
                suitableInapps = self.filterByInappsEvents(inapps: self.getOperationInappsByEvent())
            } else {
                suitableInapps = self.filterByInappsEvents(inapps: filteredInapps)
            }

            if suitableInapps.isEmpty {
                completion(nil)
                return
            }

            self.buildInAppByEvent(inapps: suitableInapps) { formData in
                completion(formData)
            }
        }
    }

    func prepareForRemainingTargeting() {
        let estimatedInapps = validInapps
        prepareTargetingChecker(for: estimatedInapps)
    }

    func sendRemainingInappsTargeting() {
        self.dataFacade.fetchDependencies(model: savedEventForTargeting?.model) {
            var suitableInapps = [InAppTransitionData]()
            if let event = self.savedEventForTargeting {
                suitableInapps = self.filterByInappsEvents(inapps: self.getOperationInappsByEvent())
            } else {
                suitableInapps = self.filterByInappsEvents(inapps: self.validInapps)
            }

            let logMessage = """
            TR | Initiating processing of remaining in-app targeting requests.
                 Full list of in-app messages: \(self.validInapps.map { $0.id })
                 Saved event for targeting: \(self.savedEventForTargeting?.name ?? "None")
            """
            Logger.common(message: logMessage, level: .debug, category: .inAppMessages)

            var hashValue = self.savedEventForTargeting?.hashValue ?? InAppMessageTriggerEvent.start.hashValue
            let targetedEventKey: InAppMessageTriggerEvent = .start
            for inapp in suitableInapps {
                if self.shownInAppIdsWithEvents[inapp.inAppId] != hashValue,
                   let inapp = self.validInapps.first(where: { $0.id == inapp.inAppId }),
                    self.targetingChecker.check(targeting: inapp.targeting) {
                       self.dataFacade.trackTargeting(id: inapp.id)
                }
            }
//
//
//            var targetedEventKey: InAppMessageTriggerEvent
//
//            if let savedEventForTargeting = self.savedEventForTargeting {
//                targetedEventKey = .applicationEvent(savedEventForTargeting)
//            } else {
//                targetedEventKey = .start
//            }
//
//            guard let inappsByEvent = self.filteredInappsByEventForTargeting[targetedEventKey] else {
//                return
//            }
//
//            let preparedForTrackTargetingInapps: Set<String> = Set(self.validInapps.compactMap { inapp -> String? in
//                guard inappsByEvent.contains(where: { $0.inAppId == inapp.id }),
//                      self.targetingChecker.check(targeting: inapp.targeting) else {
//                    return nil
//                }
//                return inapp.id
//            })
//
//            Logger.common(message: "TR | In-apps selected for targeting requests: \(preparedForTrackTargetingInapps)", level: .debug, category: .inAppMessages)
//
//            preparedForTrackTargetingInapps.forEach { id in
//                self.dataFacade.trackTargeting(id: id)
//            }
        }
    }

    private func prepareTargetingChecker(for inapps: [InApp]) {
        inapps.forEach({
            targetingChecker.prepare(id: $0.id, targeting: $0.targeting)
        })
    }

    func getOperationInappsByEvent() -> [InApp] {
        if let event = targetingChecker.event, let inappIDS = targetingChecker.context.operationInapps[event.name] {
            return validInapps.filter { inappIDS.contains($0.id) }
        }

        return []
    }

    func filterByInappsEvents(inapps: [InApp]) -> [InAppTransitionData] {
        var filteredInAppsByEvent: [InAppTransitionData] = []

        for inapp in inapps {

            guard targetingChecker.check(targeting: inapp.targeting) else {
                continue
            }

            if let inAppFormVariants = inapp.form.variants.first {
                let formData = InAppTransitionData(inAppId: inapp.id,
                                                   content: inAppFormVariants)
                filteredInAppsByEvent.append(formData)
            }
        }

        return filteredInAppsByEvent
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
                        self?.dataFacade.trackTargeting(id: formData?.inAppId)
                        self?.shownInAppIdsWithEvents[formData!.inAppId] = self?.savedEventForTargeting?.hashValue ?? InAppMessageTriggerEvent.start.hashValue // MARK: - Check force unwrap
                    }

                    completion(formData)
                }
            }
        }
    }
}
