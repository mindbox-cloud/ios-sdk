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
    
    private let inappFilterService: InappFilterProtocol
    var targetingChecker: InAppTargetingCheckerProtocol
    private let persistenceStorage: PersistenceStorage
    var filteredInAppsByEvent: [InAppMessageTriggerEvent: [InAppTransitionData]] = [:]
    private let sdkVersionValidator: SDKVersionValidator
    private let urlExtractorService: VariantImageUrlExtractorServiceProtocol
    private let abTestDeviceMixer: ABTestDeviceMixer
    
    let dataFacade: InAppConfigurationDataFacadeProtocol
    
    private var fullListOfInapps: [InApp] = []
    private var inappsDictForTargeting: [InAppMessageTriggerEvent: [InAppTransitionData]] = [:]
    private var savedEventForTargeting: ApplicationEvent?
    private var shownInnapId: String = ""
    private var completionSuccess = false

    init(inappFilterService: InappFilterProtocol,
         targetingChecker: InAppTargetingCheckerProtocol,
         persistenceStorage: PersistenceStorage,
         sdkVersionValidator: SDKVersionValidator,
         urlExtractorService: VariantImageUrlExtractorServiceProtocol,
         abTestDeviceMixer: ABTestDeviceMixer,
         dataFacade: InAppConfigurationDataFacadeProtocol) {
        self.inappFilterService = inappFilterService
        self.targetingChecker = targetingChecker
        self.persistenceStorage = persistenceStorage
        self.sdkVersionValidator = sdkVersionValidator
        self.urlExtractorService = urlExtractorService
        self.abTestDeviceMixer = abTestDeviceMixer
        self.dataFacade = dataFacade
    }

    /// Maps config response to business-logic handy InAppConfig model
    func mapConfigResponse(_ event: ApplicationEvent?,
                           _ response: ConfigResponse,
                           _ completion: @escaping (InAppFormData?) -> Void) {
        let shownInAppsIds = Set(persistenceStorage.shownInAppsIds ?? [])
        savedEventForTargeting = event
        self.targetingChecker.event = nil
        fullListOfInapps = inappFilterService.filter(inapps: response.inapps?.elements)
        let responseInapps = filterInappsByABTests(response.abtests, responseInapps: fullListOfInapps)
        let filteredInapps = filterInappsBySDKVersion(responseInapps, shownInAppsIds: shownInAppsIds)
        Logger.common(message: "Shown in-apps ids: [\(shownInAppsIds)]", level: .info, category: .inAppMessages)
        
        targetingChecker.event = event
        prepareTargetingChecker(for: filteredInapps)
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
    
    func sendRemainingInappsTargeting() {
        Logger.common(message: "TR | Initiating processing of remaining in-app targeting requests.", level: .debug, category: .inAppMessages)
        Logger.common(message: "TR | Full list of in-app messages: \(fullListOfInapps.map { $0.id })", level: .debug, category: .inAppMessages)
        Logger.common(message: "TR | Saved event for targeting: \(savedEventForTargeting?.name ?? "None")", level: .debug, category: .inAppMessages)
        
        self.prepareTargetingChecker(for: fullListOfInapps)
        dataFacade.setObservedOperation()
        self.dataFacade.fetchDependencies(model: savedEventForTargeting?.model) {
            self.filterByInappsEvents(inapps: self.fullListOfInapps, filteredInAppsByEvent: &self.inappsDictForTargeting)
            let inappsForTargeting = self.inAppsByEventForTargeting(event: self.savedEventForTargeting, asd: self.inappsDictForTargeting)
            var ids = inappsForTargeting.map { $0.inAppId }
            if self.completionSuccess && ids.contains(self.shownInnapId) {
                ids.removeAll { $0 == self.shownInnapId }
            }

            let setIds = Set(ids)
            Logger.common(message: "TR | In-apps selected for targeting requests: \(setIds)", level: .debug, category: .inAppMessages)
            setIds.forEach { self.dataFacade.trackTargeting(id: $0) }
            self.completionSuccess = false
        }
    }
    
    func inAppsByEventForTargeting(event: ApplicationEvent?, asd: [InAppMessageTriggerEvent: [InAppTransitionData]]) -> [InAppTransitionData] {
        if let event = event {
            if let inappsByEvent = asd[.applicationEvent(event)] {
                return inappsByEvent
            } else {
                return []
            }
        } else if let inappsByEvent = asd[.start] {
            return inappsByEvent
        } else {
            Logger.common(message: "No inapps available for the event or start.")
            return []
        }
    }
    
    func filterInappsBySDKVersion(_ inapps: [InApp]?, shownInAppsIds: Set<String>) -> [InApp] {
        guard let inapps = inapps else {
            return []
        }
        
        let filteredInapps = inapps.filter {
            sdkVersionValidator.isValid(item: $0.sdkVersion)
            && !shownInAppsIds.contains($0.id)
        }
        
        return filteredInapps
    }
    
    func filterInappsByABTests(_ abTests: [ABTest]?, responseInapps: [InApp]?) -> [InApp] {
        let responseInapps = responseInapps ?? []
        guard let abTests = abTests, !abTests.isEmpty else {
            return responseInapps
        }
        
        var result: [InApp] = responseInapps
        
        for abTest in abTests {
            guard let uuid = UUID(uuidString: persistenceStorage.deviceUUID ?? "" ),
                  let salt = abTest.salt,
                  let variants = abTest.variants else {
                continue
            }
            
            let hashValue = try? abTestDeviceMixer.modulusGuidHash(identifier: uuid, salt: salt)
            
            guard let hashValue = hashValue else {
                continue
            }
            
            Logger.common(message: "[Hash Value]: \(hashValue) for [UUID]: \(persistenceStorage.deviceUUID ?? "nil")")
            Logger.common(message: "[AB-test ID]: \(abTest.id)")
            
            var allInappsInVariantsExceptCurrentBranch: [String] = []
            
            for variant in variants {
                if let objects = variant.objects {
                    for object in objects {
                        if object.kind == .all {
                            responseInapps.forEach( {
                                allInappsInVariantsExceptCurrentBranch.append($0.id)
                            })
                        } else {
                            allInappsInVariantsExceptCurrentBranch += object.inapps ?? []
                        }
                    }
                }
            }
            
            var setInapps = Set(allInappsInVariantsExceptCurrentBranch)
            
            for variant in variants {
                if let modulus = variant.modulus, let objects = variant.objects, let upper = modulus.upper {
                    let range = modulus.lower..<upper
                    if range.contains(hashValue) {
                        Logger.common(message: "[AB-test branch ID]: \(variant.id)")
                        for object in objects {
                            if object.kind == .all {
                                setInapps.removeAll()
                            } else if let inapps = object.inapps {
                                setInapps.subtract(inapps)
                            }
                        }
                    }
                }
            }
            
            let currentResult = responseInapps.filter { !setInapps.contains($0.id) }
            result = result.filter { currentResult.contains($0) }
        }
        
        let ids = result.map { $0.id }
        Logger.common(message: "Filtered in-app IDs after AB-filter based on UUID branch: [\(ids.joined(separator: ", "))]")
        
        return result
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
                
                if let shownInapps = self.persistenceStorage.shownInAppsIds, shownInapps.contains(inapp.inAppId) {
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
                    self?.dataFacade.trackTargeting(id: formData?.inAppId)
                    self?.completionSuccess = true
                    completion(formData)
                }
            }
        }
    }
}
