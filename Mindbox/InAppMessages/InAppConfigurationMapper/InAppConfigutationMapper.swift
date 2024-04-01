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
    func mapConfigResponse(_ event: ApplicationEvent?, _ response: ConfigResponse,_ completion: @escaping (InAppFormData?) -> Void) -> Void
    var targetingChecker: InAppTargetingCheckerProtocol { get set }
    func sendRemainingInappsTargeting()
}

final class InAppConfigutationMapper: InAppConfigurationMapperProtocol {
    
    var targetingChecker: InAppTargetingCheckerProtocol
    var filteredInAppsByEvent: [InAppMessageTriggerEvent: [InAppTransitionData]] = [:]
    var filteredInappsByEventForTargeting: [InAppMessageTriggerEvent: [InAppTransitionData]] = [:]
    
    let dataFacade: InAppConfigurationDataFacadeProtocol
    
    private let inappFilterService: InappFilterProtocol
    private let urlExtractorService: VariantImageUrlExtractorServiceProtocol
    
    private var validInapps: [InApp] = []
    private var savedEventForTargeting: ApplicationEvent?
    private var shownInnapId = ""

    init(inappFilterService: InappFilterProtocol,
         targetingChecker: InAppTargetingCheckerProtocol,
         urlExtractorService: VariantImageUrlExtractorServiceProtocol,
         dataFacade: InAppConfigurationDataFacadeProtocol) {
        self.inappFilterService = inappFilterService
        self.targetingChecker = targetingChecker
        self.urlExtractorService = urlExtractorService
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
        dataFacade.setObservedOperation()
        
        prepareForRemainingTargeting()
        
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
        
        self.dataFacade.fetchDependencies(model: savedEventForTargeting?.model) {
            self.filterByInappsEvents(inapps: estimatedInapps,
                                      filteredInAppsByEvent: &self.filteredInappsByEventForTargeting)
        }
    }
    
    func sendRemainingInappsTargeting() {
        let logMessage = """
        TR | Initiating processing of remaining in-app targeting requests.
             Full list of in-app messages: \(validInapps.map { $0.id })
             Saved event for targeting: \(savedEventForTargeting?.name ?? "None")
        """
        Logger.common(message: logMessage, level: .debug, category: .inAppMessages)
        
        let targetedEventKey: InAppMessageTriggerEvent = savedEventForTargeting != nil
            ? .applicationEvent(savedEventForTargeting!)
            : .start
        
        let targetedInApps = filteredInappsByEventForTargeting[targetedEventKey]?.filter { inAppData in
            !validInapps.contains { $0.id == shownInnapId && $0.id == inAppData.inAppId }
        } ?? []
                
        Logger.common(message: "TR | In-apps selected for targeting requests: \(targetedInApps.map { $0.inAppId })", level: .debug, category: .inAppMessages)

        targetedInApps.forEach { inAppData in
            dataFacade.trackTargeting(id: inAppData.inAppId)
        }
        
        shownInnapId = ""
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

        DispatchQueue.global().async {
            for inapp in inapps {
                
                guard formData == nil else {
                    break
                }
                
                var imageDict: [String: UIImage] = [:]
                var gotError = false
                
                if self.inappFilterService.shownInAppsIds.contains(inapp.inAppId) {
                    continue
                }
                
                let imageValues = self.urlExtractorService.extractImageURL(from: inapp.content)
                
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
                    self?.shownInnapId = formData?.inAppId ?? ""
                    if !SessionTemporaryStorage.shared.isPresentingInAppMessage {
                        self?.dataFacade.trackTargeting(id: formData?.inAppId)
                    }
                    
                    completion(formData)
                }
            }
        }
    }
}
