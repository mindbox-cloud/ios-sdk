//
//  InAppMapper.swift
//  Mindbox
//
//  Created by Максим Казаков on 12.09.2022.
//

import Foundation
import MindboxLogger
import UIKit

protocol InAppMapperProtocol {
    func mapConfigResponse(_ event: ApplicationEvent?, _ response: InAppConfigResponse,_ completion: @escaping (InAppFormData?) -> Void) -> Void
    var targetingChecker: InAppTargetingCheckerProtocol { get set }
}

class InAppMapper: InAppMapperProtocol {
    
    var targetingChecker: InAppTargetingCheckerProtocol
    var filteredInAppsByEvent = [InAppMessageTriggerEvent: [InAppTransitionData]]()
    
    private var segmentationService: SegmentationService
    private var geoService: GeoService
    private var imageDownloadService: ImageDownloadServiceProtocol
    private var persistenceStorage: PersistenceStorage
    private var dispatchGroup: DispatchGroup = DispatchGroup()

    private let sessionTemporaryStorage: SessionTemporaryStorage
    private let customerAbMixer: CustomerAbMixer
    private var inAppsVersion: Int

    init(segmentationService: SegmentationService,
         geoService: GeoService,
         imageDownloadService: ImageDownloadServiceProtocol,
         targetingChecker: InAppTargetingCheckerProtocol,
         persistenceStorage: PersistenceStorage,
         sessionTemporaryStorage: SessionTemporaryStorage,
         customerAbMixer: CustomerAbMixer,
         inAppsVersion: Int) {
        self.segmentationService = segmentationService
        self.geoService = geoService
        self.imageDownloadService = imageDownloadService
        self.targetingChecker = targetingChecker
        self.persistenceStorage = persistenceStorage
        self.sessionTemporaryStorage = sessionTemporaryStorage
        self.customerAbMixer = customerAbMixer
        self.inAppsVersion = inAppsVersion
    }
    
    /// Maps config response to business-logic handy InAppConfig model
    func mapConfigResponse(_ event: ApplicationEvent?,
                           _ response: InAppConfigResponse,
                           _ completion: @escaping (InAppFormData?) -> Void) {
        let shownInAppsIds = Set(persistenceStorage.shownInAppsIds ?? [])
        var filteredABTests = validationABTests(response.abtests)
        var responseInapps = filterInappsByABTests(filteredABTests, responseInapps: response.inapps)
        let ids = responseInapps.map { $0.id }
        Logger.common(message: "Filtered in-app IDs after AB-filter based on UUID branch: [\(ids.joined(separator: ", "))]")

        responseInapps = filterByInappVersion(responseInapps, shownInAppsIds: shownInAppsIds)
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
                    completion(nil)
                }
            } else if let inappsByEvent = self.filteredInAppsByEvent[.start] {
                self.buildInAppByEvent(inapps: inappsByEvent) { formData in
                    completion(formData)
                }
            }
        }
    }

    func prepareTargetingChecker(for inapps: [InAppConfigResponse.InApp]) {
        inapps.forEach({
            targetingChecker.prepare(targeting: $0.targeting)
        })
    }

    func fetchDependencies(model: InappOperationJSONModel?,
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
}

extension InAppMapper {
    func filterByInappVersion(_ inapps: [InAppConfigResponse.InApp]?, shownInAppsIds: Set<String>) -> [InAppConfigResponse.InApp] {
        guard let inapps = inapps else {
            return []
        }
        
        let filteredInapps = inapps.filter {
            inAppsVersion >= $0.sdkVersion.min
                && inAppsVersion <= ($0.sdkVersion.max ?? Int.max)
                && !shownInAppsIds.contains($0.id)
        }
        
        return filteredInapps
    }
    
    func setInAppsVersion(_ version: Int) {
        inAppsVersion = version
    }
    
    func validationABTests(_ abtests: [InAppConfigResponse.ABTest]?) -> [InAppConfigResponse.ABTest] {
        guard let abtests = abtests, !abtests.isEmpty else {
            Logger.common(message: "No AB Tests to filter. Exiting.")
            return []
        }
        
        let filteredABTests = abtests.filter {
            inAppsVersion >= $0.sdkVersion.min
            && inAppsVersion <= ($0.sdkVersion.max ?? Int.max)
        }
        
        for tests in filteredABTests {
            guard let variants = tests.variants, variants.count >= 2 else {
                Logger.common(message: "ABTest \(tests.id) does not have enough variants. Exiting.")
                return []
            }
            
            let modulusSum = variants.reduce(0) { $0 + $1.modulus.upper - $1.modulus.lower }
            if modulusSum != 100 {
                Logger.common(message: "ABTest [\(tests.id)] variants modulus sum is not equal to 100. Exiting.")
                return []
            }
        }
        
        return filteredABTests
    }
    
    func filterInappsByABTests(_ abTests: [InAppConfigResponse.ABTest], responseInapps: [InAppConfigResponse.InApp]?) -> [InAppConfigResponse.InApp] {
        let responseInapps = responseInapps ?? []
        guard !abTests.isEmpty else {
            return responseInapps
        }
        
        var result: [InAppConfigResponse.InApp] = []
        
        for abTest in abTests {
            guard let uuid = UUID(uuidString: persistenceStorage.deviceUUID ?? "" ),
                      let variants = abTest.variants
                else { continue }
            
            let hashValue = sessionTemporaryStorage.mockHashNumber ?? self.customerAbMixer.modulusGuidHash(identifier: uuid, salt: abTest.salt)
            
            Logger.common(message: "[Hash Value]: \(hashValue) for [UUID]: \(persistenceStorage.deviceUUID ?? "nil")")
            Logger.common(message: "[AB-test ID]: \(abTest.id)")
            
            var allInappsInVariantsExceptCurrentBranch: [String] = []
            
            for variant in variants {
                for object in variant {
                    if object.kind == .all {
                        responseInapps.forEach( {
                            allInappsInVariantsExceptCurrentBranch.append($0.id)
                        })
                    } else {
                        allInappsInVariantsExceptCurrentBranch += object.inapps ?? []
                    }
                }
            }
            
            var setInapps = Set(allInappsInVariantsExceptCurrentBranch)
            
            for variant in variants {
                let range = variant.modulus.lower..<variant.modulus.upper
                if range.contains(hashValue) {
                    for object in variant {
                        if object.kind == .all {
                            setInapps.removeAll()
                        } else if let inapps = object.inapps {
                            setInapps.subtract(inapps)
                        }
                    }
                }
            }
            
            result = responseInapps.filter { !setInapps.contains($0.id) }
            print(result)
            if result.isEmpty {
                return []
            }
        }
        return result
    }
    
    func filterByInappsEvents(inapps: [InAppConfigResponse.InApp]) {
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

    func buildInAppByEvent(inapps: [InAppTransitionData],
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
                    defer {
                        group.leave()
                    }

                    switch result {
                    case .success(let image):
                        formData = InAppFormData(inAppId: inapp.inAppId, image: image, redirectUrl: inapp.redirectUrl, intentPayload: inapp.intentPayload)
                        shouldDownloadImage = false

                    case .failure(_):
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
