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
}

class InappMapper: InappMapperProtocol {

    private var applicationEvent: ApplicationEvent?
    private var targetingChecker: InAppTargetingCheckerProtocol
    private let inappFilterService: InappFilterProtocol
    private let dataFacade: InAppConfigurationDataFacadeProtocol

    private var shownInappIDWithHashValue: [String: Int] = [:]

    init(targetingChecker: InAppTargetingCheckerProtocol,
         inappFilterService: InappFilterProtocol,
         dataFacade: InAppConfigurationDataFacadeProtocol) {
        self.targetingChecker = targetingChecker
        self.inappFilterService = inappFilterService
        self.dataFacade = dataFacade
    }

    func handleInapps(_ event: ApplicationEvent?,
                      _ response: ConfigResponse,
                      _ completion: @escaping (InAppFormData?) -> Void) {
        setupEnvironment(event: event)

        let filteredInapps = getFilteredInapps(inappsDTO: response.inapps?.elements, abTests: response.abtests)
        prepareTargetingChecker(for: filteredInapps)
        prepareForRemainingTargeting()
        chooseInappToShow(filteredInapps: filteredInapps) { formData in
            completion(formData)
            self.sendRemainingInappsTargeting()
        }
    }

    private func setupEnvironment(event: ApplicationEvent?) {
        Logger.common(message: "Start handingInapps by event: \(event?.name ?? "start")", level: .debug, category: .inAppMessages)
        applicationEvent = event
        targetingChecker.event = nil
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
            let inapps = self.applicationEvent == nil ? filteredInapps : self.getOperationInappsByEvent()
            let suitableInapps = self.filterByInappsEvents(inapps: inapps)

            if suitableInapps.isEmpty {
                completion(nil)
                return
            }

            self.buildInAppByEvent(inapps: suitableInapps) { formData in
                completion(formData)
            }
        }
    }

    private func getOperationInappsByEvent() -> [InApp] {
        if let event = targetingChecker.event,
           let inappIDS = targetingChecker.context.operationInapps[event.name] {
            return inappFilterService.validInapps.filter { inappIDS.contains($0.id) }
        }

        return []
    }

    private func filterByInappsEvents(inapps: [InApp]) -> [InAppTransitionData] {
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
                        if let id = formData?.inAppId {
                            self?.dataFacade.trackTargeting(id: id)
                            self?.shownInappIDWithHashValue[id] = self?.getEventHashValue()
                        }
                    }

                    completion(formData)
                }
            }
        }
    }

    private func getEventHashValue() -> Int {
        return applicationEvent?.hashValue ?? InAppMessageTriggerEvent.start.hashValue
    }

    func sendRemainingInappsTargeting() {
        self.dataFacade.fetchDependencies(model: applicationEvent?.model) {
            let inapps = self.applicationEvent == nil ? self.inappFilterService.validInapps : self.getOperationInappsByEvent()
            let suitableInapps = self.filterByInappsEvents(inapps: inapps)

            let logMessage = """
            TR | Initiating processing of remaining in-app targeting requests.
                 Full list of in-app messages: \(self.inappFilterService.validInapps.map { $0.id })
                 Saved event for targeting: \(self.applicationEvent?.name ?? "None")
            """
            Logger.common(message: logMessage, level: .debug, category: .inAppMessages)

            for inapp in suitableInapps {
                if self.shownInappIDWithHashValue[inapp.inAppId] != self.getEventHashValue(),
                   let inapp = self.inappFilterService.validInapps.first(where: { $0.id == inapp.inAppId }),
                    self.targetingChecker.check(targeting: inapp.targeting) {
                       self.dataFacade.trackTargeting(id: inapp.id)
                }
            }
        }
    }
}
