//
//  InAppConfigurationDataFacade.swift
//  Mindbox
//
//  Created by vailence on 28.02.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
import UIKit
import MindboxLogger

protocol InAppConfigurationDataFacadeProtocol {
    func fetchDependencies(model: InappOperationJSONModel?, _ completion: @escaping () -> Void)
    func downloadImage(withUrl url: String, completion: @escaping (Result<UIImage, Error>) -> Void)
    func setObservedOperation()
    func trackTargeting(id: String?)
}

class InAppConfigurationDataFacade: InAppConfigurationDataFacadeProtocol {
    
    let geoService: GeoServiceProtocol
    let segmentationService: SegmentationServiceProtocol
    var targetingChecker: InAppTargetingCheckerProtocol
    let imageService: ImageDownloadServiceProtocol
    let tracker: InappTargetingTrackProtocol
    
    init(geoService: GeoServiceProtocol, 
         segmentationService: SegmentationServiceProtocol,
         targetingChecker: InAppTargetingCheckerProtocol,
         imageService: ImageDownloadServiceProtocol,
         tracker: InappTargetingTrackProtocol) {
        self.geoService = geoService
        self.segmentationService = segmentationService
        self.targetingChecker = targetingChecker
        self.imageService = imageService
        self.tracker = tracker
    }
    
    private let dispatchGroup = DispatchGroup()
    
    func fetchDependencies(model: InappOperationJSONModel?, _ completion: @escaping () -> Void) {
        fetchSegmentationIfNeeded()
        fetchGeoIfNeeded()
        fetchProductSegmentationIfNeeded(products: model?.viewProduct?.product)
        
        dispatchGroup.notify(queue: .main) {
            completion()
        }
    }
    
    func setObservedOperation() {
        SessionTemporaryStorage.shared.observedCustomOperations = Set(targetingChecker.context.operationsName)
    }
    
    func downloadImage(withUrl url: String, completion: @escaping (Result<UIImage, Error>) -> Void) {
        imageService.downloadImage(withUrl: url) { result in
            completion(result)
        }
    }
    
    func trackTargeting(id: String?) {
        if let id = id {
            do {
                try self.tracker.trackTargeting(id: id)
                Logger.common(message: "Track InApp.Targeting. Id \(id)", level: .info, category: .inAppMessages)
            } catch {
                Logger.common(message: "Track InApp.Targeting failed with error: \(error)", level: .error, category: .inAppMessages)
            }
        }
    }
}

private extension InAppConfigurationDataFacade {
    private func fetchSegmentationIfNeeded() {
        if !SessionTemporaryStorage.shared.checkSegmentsRequestCompleted {
            dispatchGroup.enter()
            segmentationService.checkSegmentationRequest { response in
                self.targetingChecker.checkedSegmentations = response
                self.dispatchGroup.leave()
            }
        }
    }

    private func fetchGeoIfNeeded() {
        if targetingChecker.context.isNeedGeoRequest
            && !SessionTemporaryStorage.shared.geoRequestCompleted {
            dispatchGroup.enter()
            geoService.geoRequest { model in
                self.targetingChecker.geoModels = model
                self.dispatchGroup.leave()
            }
        }
    }

    private func fetchProductSegmentationIfNeeded(products: ProductCategory?) {
        if !SessionTemporaryStorage.shared.checkProductSegmentsRequestCompleted,
            let products = products {
            dispatchGroup.enter()
            segmentationService.checkProductSegmentationRequest(products: products) { response in
                self.targetingChecker.checkedProductSegmentations = response
                self.dispatchGroup.leave()
            }
        }
    }
}
