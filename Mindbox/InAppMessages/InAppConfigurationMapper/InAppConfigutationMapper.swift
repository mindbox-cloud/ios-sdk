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
}

final class InAppConfigutationMapper: InAppConfigurationMapperProtocol {

    private let geoService: GeoServiceProtocol
    private let segmentationService: SegmentationServiceProtocol
    private let customerSegmentsAPI: CustomerSegmentsAPI
    private var inAppsVersion: Int
    var targetingChecker: InAppTargetingCheckerProtocol
    private let sessionTemporaryStorage: SessionTemporaryStorage
    private let persistenceStorage: PersistenceStorage
    var filteredInAppsByEvent: [InAppMessageTriggerEvent: [InAppTransitionData]] = [:]
    private let sdkVersionValidator: SDKVersionValidator
    private let imageDownloadService: ImageDownloadServiceProtocol
    private let abTestDeviceMixer: ABTestDeviceMixer

    private let dispatchGroup = DispatchGroup()

    init(geoService: GeoServiceProtocol,
         segmentationService: SegmentationServiceProtocol,
         customerSegmentsAPI: CustomerSegmentsAPI,
         inAppsVersion: Int,
         targetingChecker: InAppTargetingCheckerProtocol,
         sessionTemporaryStorage: SessionTemporaryStorage,
         persistenceStorage: PersistenceStorage,
         sdkVersionValidator: SDKVersionValidator,
         imageDownloadService: ImageDownloadServiceProtocol,
         abTestDeviceMixer: ABTestDeviceMixer) {
        self.geoService = geoService
        self.segmentationService = segmentationService
        self.customerSegmentsAPI = customerSegmentsAPI
        self.inAppsVersion = inAppsVersion
        self.targetingChecker = targetingChecker
        self.sessionTemporaryStorage = sessionTemporaryStorage
        self.persistenceStorage = persistenceStorage
        self.sdkVersionValidator = sdkVersionValidator
        self.imageDownloadService = imageDownloadService
        self.abTestDeviceMixer = abTestDeviceMixer
    }
    
    func setInAppsVersion(_ version: Int) {
        inAppsVersion = version
    }

    /// Maps config response to business-logic handy InAppConfig model
    func mapConfigResponse(_ event: ApplicationEvent?,
                           _ response: ConfigResponse,
                           _ completion: @escaping (InAppFormData?) -> Void) {
        let shownInAppsIds = Set(persistenceStorage.shownInAppsIds ?? [])
        var responseInapps = filterInappsByABTests(response.abtests, responseInapps: response.inapps)

        if responseInapps.isEmpty {
            Logger.common(message: "Inapps from config is empty. No inapps to show", level: .debug, category: .inAppMessages)
            completion(nil)
            return
        }

        targetingChecker.event = event
        prepareTargetingChecker(for: responseInapps)
        sessionTemporaryStorage.observedCustomOperations = Set(targetingChecker.context.operationsName)
        Logger.common(message: "Shown in-apps ids: [\(shownInAppsIds)]", level: .info, category: .inAppMessages)

        fetchDependencies(model: event?.model) {
            self.filterByInappsEvents(inapps: responseInapps)
            if let event = event {
                if let inappsByEvent = self.filteredInAppsByEvent[.applicationEvent(event)] {
                    self.buildInAppByEvent(inapps: inappsByEvent) { formData in
                        completion(formData)
                    }
                } else {
                    Logger.common(message: "filteredInAppsByEvent is empty")
                }
            } else if let inappsByEvent = self.filteredInAppsByEvent[.start] {
                self.buildInAppByEvent(inapps: inappsByEvent) { formData in
                    completion(formData)
                }
            }
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
        
        var result: [InApp] = []
        
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
                if let modulus = variant.modulus, let objects = variant.objects {
                    let range = modulus.lower..<modulus.upper
                    if range.contains(hashValue) {
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
            
            result = responseInapps.filter { !setInapps.contains($0.id) }
            if result.isEmpty {
                return []
            }
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

    private func fetchDependencies(model: InappOperationJSONModel?,
                                   _ completion: @escaping () -> Void) {
        fetchSegmentationIfNeeded()
        fetchGeoIfNeeded()
        fetchProductSegmentationIfNeeded(products: model?.viewProduct?.product)

        dispatchGroup.notify(queue: .main) {
            completion()
        }
    }

    private func fetchSegmentationIfNeeded() {
        if !sessionTemporaryStorage.checkSegmentsRequestCompleted {
            dispatchGroup.enter()
            segmentationService.checkSegmentationRequest { response in
                self.targetingChecker.checkedSegmentations = response
                self.dispatchGroup.leave()
            }
        }
    }

    private func fetchGeoIfNeeded() {
        if targetingChecker.context.isNeedGeoRequest
            && !sessionTemporaryStorage.geoRequestCompleted {
            dispatchGroup.enter()
            geoService.geoRequest { model in
                self.targetingChecker.geoModels = model
                self.dispatchGroup.leave()
            }
        }
    }

    private func fetchProductSegmentationIfNeeded(products: ProductCategory?) {
        if !sessionTemporaryStorage.checkProductSegmentsRequestCompleted,
            let products = products {
            dispatchGroup.enter()
            segmentationService.checkProductSegmentationRequest(products: products) { response in
                self.targetingChecker.checkedProductSegmentations = response
                self.dispatchGroup.leave()
            }
        }
    }
    
    func filterByInappsEvents(inapps: [InApp]) {
        for inapp in inapps {
            var triggerEvent: InAppMessageTriggerEvent = .start
            
            let inAppAlreadyAddedForEvent = filteredInAppsByEvent.values.flatMap { $0 }
                .filter { $0.inAppId == inapp.id }
            
            // If the in-app message has already been added, continue to the next message
            guard inAppAlreadyAddedForEvent.isEmpty else {
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
                                                   imageUrl: inAppFormVariants.imageUrl, // Change this later
                                                   redirectUrl: inAppFormVariants.redirectUrl,
                                                   intentPayload: inAppFormVariants.intentPayload)
                inAppsForEvent.append(formData)
                filteredInAppsByEvent[triggerEvent] = inAppsForEvent
            }
        }
        
        self.targetingChecker.event = nil
    }
    
    private func buildInAppByEvent(inapps: [InAppTransitionData],
                                   completion: @escaping (InAppFormData?) -> Void) {
        var shouldDownloadImage = true
        var formData: InAppFormData?
        let group = DispatchGroup()

        DispatchQueue.global().async {
            for inapp in inapps {
                if !shouldDownloadImage {
                    break
                }
                
                if let shownInapps = self.persistenceStorage.shownInAppsIds, shownInapps.contains(inapp.inAppId) {
                    continue
                }
                
                group.enter()
                Logger.common(message: "Starting inapp processing. [ID]: \(inapp.inAppId)", level: .debug, category: .inAppMessages)
                self.imageDownloadService.downloadImage(withUrl: inapp.imageUrl) { result in
                    defer { group.leave() }
                    
                    switch result {
                    case .success(let image):
                        formData = InAppFormData(inAppId: inapp.inAppId, image: image, redirectUrl: inapp.redirectUrl, intentPayload: inapp.intentPayload)
                        shouldDownloadImage = false
                    case .failure:
                        break
                    }
                }
                
                group.wait()
            }
            
            group.notify(queue: .main) {
                DispatchQueue.main.async {
                    completion(formData)
                }
            }
        }
    }
}
