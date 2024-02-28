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
}

class InAppConfigurationDataFacade: InAppConfigurationDataFacadeProtocol {
    
    let geoService: GeoServiceProtocol
    let segmentationService: SegmentationServiceProtocol
    let sessionTemporaryStorage: SessionTemporaryStorage
    var targetingChecker: InAppTargetingCheckerProtocol
    let imageService: ImageDownloadServiceProtocol
    
    init(geoService: GeoServiceProtocol, 
         segmentationService: SegmentationServiceProtocol,
         sessionTemporaryStorage: SessionTemporaryStorage,
         targetingChecker: InAppTargetingCheckerProtocol,
         imageService: ImageDownloadServiceProtocol) {
        self.geoService = geoService
        self.segmentationService = segmentationService
        self.sessionTemporaryStorage = sessionTemporaryStorage
        self.targetingChecker = targetingChecker
        self.imageService = imageService
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
        sessionTemporaryStorage.observedCustomOperations = Set(targetingChecker.context.operationsName)
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
    
    func downloadImage(withUrl url: String, completion: @escaping (Result<UIImage, Error>) -> Void) {
        imageService.downloadImage(withUrl: url) { result in
            completion(result)
        }
    }
}
