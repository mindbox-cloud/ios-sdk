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
    func mapConfigResponse(_ event: ApplicationEvent?, _ response: InAppConfigResponse,_ completion: @escaping (InAppFormData?) -> Void) -> Void
    var targetingChecker: InAppTargetingCheckerProtocol { get set }
}

final class InAppConfigutationMapper: InAppConfigurationMapperProtocol {

    private let customerSegmentsAPI: CustomerSegmentsAPI
    private var inAppsVersion: Int
    var targetingChecker: InAppTargetingCheckerProtocol
    private var geoModel: InAppGeoResponse?
    private let fetcher: NetworkFetcher
    private let sessionTemporaryStorage: SessionTemporaryStorage
    private let persistenceStorage: PersistenceStorage
    var filteredInAppsByEvent: [InAppMessageTriggerEvent: [InAppTransitionData]] = [:]
    private let imageDownloader: ImageDownloader

    private let dispatchGroup = DispatchGroup()

    init(customerSegmentsAPI: CustomerSegmentsAPI,
         inAppsVersion: Int,
         targetingChecker: InAppTargetingCheckerProtocol,
         networkFetcher: NetworkFetcher,
         sessionTemporaryStorage: SessionTemporaryStorage,
         persistenceStorage: PersistenceStorage,
         imageDownloader: ImageDownloader) {
        self.customerSegmentsAPI = customerSegmentsAPI
        self.inAppsVersion = inAppsVersion
        self.targetingChecker = targetingChecker
        self.fetcher = networkFetcher
        self.sessionTemporaryStorage = sessionTemporaryStorage
        self.persistenceStorage = persistenceStorage
        self.imageDownloader = imageDownloader
    }
    
    func setInAppsVersion(_ version: Int) {
        inAppsVersion = version
    }

    /// Maps config response to business-logic handy InAppConfig model
    func mapConfigResponse(_ event: ApplicationEvent?,
                           _ response: InAppConfigResponse,
                           _ completion: @escaping (InAppFormData?) -> Void) {
        let shownInAppsIds = Set(persistenceStorage.shownInAppsIds ?? [])
        let responseInapps = filterByInappVersion(response.inapps, shownInAppsIds: shownInAppsIds)

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

    private func prepareTargetingChecker(for inapps: [InAppConfigResponse.InApp]) {
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
            checkSegmentationRequest { response in
                self.targetingChecker.checkedSegmentations = response
                self.dispatchGroup.leave()
            }
        }
    }

    private func fetchGeoIfNeeded() {
        if targetingChecker.context.isNeedGeoRequest
            && !sessionTemporaryStorage.geoRequestCompleted {
            dispatchGroup.enter()
            geoRequest { model in
                self.targetingChecker.geoModels = model
                self.dispatchGroup.leave()
            }
        }
    }

    private func fetchProductSegmentationIfNeeded(products: ProductCategory?) {
        if !sessionTemporaryStorage.checkProductSegmentsRequestCompleted,
            let products = products {
            dispatchGroup.enter()
            checkProductSegmentationRequest(products: products) { response in
                self.targetingChecker.checkedProductSegmentations = response
                self.dispatchGroup.leave()
            }
        }
    }

    private func checkSegmentationRequest(_ completion: @escaping ([SegmentationCheckResponse.CustomerSegmentation]?) -> Void) -> Void {

        if sessionTemporaryStorage.checkSegmentsRequestCompleted {
            completion(targetingChecker.checkedSegmentations)
            return
        }

        let arrayOfSegments = Array(Set(targetingChecker.context.segments))
        let segments: [SegmentationCheckRequest.Segmentation] = arrayOfSegments.map {
            return .init(ids: .init(externalId: $0))
        }

        if segments.isEmpty {
            completion(nil)
            return
        }

        let model = SegmentationCheckRequest(segmentations: segments)

        customerSegmentsAPI.fetchSegments(model) { response in
            self.sessionTemporaryStorage.checkSegmentsRequestCompleted = true
            guard let response = response,
                  response.status == .success else {
                Logger.common(message: "Customer Segment does not exist, or response status not equal to Success. Status: \(String(describing: response?.status))", level: .debug, category: .inAppMessages)

                completion(nil)
                return
            }

            Logger.common(message: "Customer Segment response: \n\(response)")
            completion(response.customerSegmentations)
        }
    }

    private func checkProductSegmentationRequest(products: ProductCategory,
                                                 _ completion: @escaping ([InAppProductSegmentResponse.CustomerSegmentation]?) -> Void) -> Void {
        if sessionTemporaryStorage.isPresentingInAppMessage {
            return
        }

        let arrayOfSegments = Array(Set(targetingChecker.context.productSegments))
        let segments: [InAppProductSegmentRequest.Segmentation] = arrayOfSegments.map {
            return .init(ids: .init(externalId: $0))
        }

        if segments.isEmpty {
            completion(nil)
            return
        }

        let model = InAppProductSegmentRequest(segmentations: segments, products: [products])

        customerSegmentsAPI.fetchProductSegments(model) { response in
            guard let response = response,
                  response.status == .success else {
                Logger.common(message: "Customer Segment does not exist, or response status not equal to Success. Status: \(String(describing: response?.status))", level: .debug, category: .inAppMessages)

                completion(nil)
                return
            }

            Logger.common(message: "Customer Segment response: \n\(response)")
            var checkedProductSegmentations: [InAppProductSegmentResponse.CustomerSegmentation] = []
            response.products?.forEach {
                checkedProductSegmentations.append(contentsOf: $0.segmentations)
            }

            completion(checkedProductSegmentations)
        }
    }

    private func geoRequest(_ completion: @escaping (InAppGeoResponse?) -> Void) -> Void {
        if sessionTemporaryStorage.geoRequestCompleted {
            completion(targetingChecker.geoModels)
            return
        }

        let route = FetchInAppGeoRoute()
        fetcher.request(type: InAppGeoResponse.self, route: route, needBaseResponse: false) { response in
            self.sessionTemporaryStorage.geoRequestCompleted = true
            switch response {
            case .success(let result):
                completion(result)
            case .failure(let error):
                Logger.error(error.asLoggerError())
                completion(nil)
            }
        }
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
                
                self.imageDownloader.downloadImage(withUrl: inapp.imageUrl) { localURL, response, error in
                    defer {
                        group.leave()
                    }
                    
                    if let error = error as? NSError {
                        Logger.common(message: "Failed to download image for url: \(inapp.imageUrl). \nError: \(error.localizedDescription)", level: .debug, category: .inAppMessages)
                        if error.code == NSURLErrorTimedOut {
                            return
                        }
                    } else if let response = response, response.statusCode != 200 {
                        Logger.common(message: "Image download failed with status code \(response.statusCode). [ID]: \(inapp.inAppId)", level: .debug, category: .inAppMessages)

                        return
                    } else if let localURL = localURL {
                        do {
                            let imageData = try Data(contentsOf: localURL)
                            guard let image = UIImage(data: imageData) else {
                                Logger.common(message: "Inapps image is incorrect. [URL]: \(localURL)", level: .debug, category: .inAppMessages)
                                return
                            }
                            
                            Logger.common(message: "Image is loaded successfully. [ID]: \(inapp.inAppId)", level: .debug, category: .inAppMessages)
                            formData = InAppFormData(inAppId: inapp.inAppId, image: image, redirectUrl: inapp.redirectUrl, intentPayload: inapp.intentPayload)
                            shouldDownloadImage = false
                        } catch {
                            Logger.common(message: "Failed to read image data. Error: \(error.localizedDescription)", level: .debug, category: .inAppMessages)
                            return
                        }
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
