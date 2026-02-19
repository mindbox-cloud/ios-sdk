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
    func fetchDependencies(
        model: InappOperationJSONModel?,
        shouldCollectFailures: Bool,
        _ completion: @escaping () -> Void
    )
    func downloadImage(withUrl url: String, completion: @escaping (Result<UIImage, Error>) -> Void)
    func trackTargeting(id: String?)
}

extension InAppConfigurationDataFacadeProtocol {
    func fetchDependencies(model: InappOperationJSONModel?, _ completion: @escaping () -> Void) {
        fetchDependencies(model: model, shouldCollectFailures: true, completion)
    }
}

class InAppConfigurationDataFacade: InAppConfigurationDataFacadeProtocol {

    var geoService: GeoServiceProtocol?
    let segmentationService: SegmentationServiceProtocol
    var targetingChecker: InAppTargetingCheckerProtocol
    let imageService: ImageDownloadServiceProtocol
    let tracker: InappTargetingTrackProtocol
    let failureManager: InappShowFailureManagerProtocol

    init(segmentationService: SegmentationServiceProtocol,
         targetingChecker: InAppTargetingCheckerProtocol,
         imageService: ImageDownloadServiceProtocol,
         tracker: InappTargetingTrackProtocol,
         failureManager: InappShowFailureManagerProtocol) {
        self.segmentationService = segmentationService
        self.targetingChecker = targetingChecker
        self.imageService = imageService
        self.tracker = tracker
        self.failureManager = failureManager
    }

    private let dispatchGroup = DispatchGroup()

    func fetchDependencies(
        model: InappOperationJSONModel?,
        shouldCollectFailures: Bool,
        _ completion: @escaping () -> Void
    ) {
        fetchSegmentationIfNeeded(shouldCollectFailures: shouldCollectFailures)
        fetchGeoIfNeeded(shouldCollectFailures: shouldCollectFailures)
        fetchProductSegmentationIfNeeded(
            products: model?.viewProduct?.product,
            shouldCollectFailures: shouldCollectFailures
        )

        dispatchGroup.notify(queue: .main) {
            completion()
        }
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

extension InAppConfigurationDataFacade {
    private func fetchSegmentationIfNeeded(shouldCollectFailures: Bool) {
        if !SessionTemporaryStorage.shared.checkSegmentsRequestCompleted {
            dispatchGroup.enter()
            segmentationService.checkSegmentationRequest { result in
                switch result {
                case .success(let response):
                    self.targetingChecker.checkedSegmentations = response
                case .failure(let error):
                    self.targetingChecker.checkedSegmentations = nil
                    if shouldCollectFailures {
                        self.addTargetingFailureIfNeeded(
                            for: error,
                            reason: .customerSegmentRequestFailed,
                            inappIds: self.targetingChecker.context.segmentInapps
                        )
                    }
                }
                self.dispatchGroup.leave()
            }
        }
    }

    private func fetchGeoIfNeeded(shouldCollectFailures: Bool) {
        if targetingChecker.context.isNeedGeoRequest {
            dispatchGroup.enter()
            geoService = DI.injectOrFail(GeoServiceProtocol.self)
            geoService?.geoRequest { result in
                switch result {
                case .success(let model):
                    self.targetingChecker.geoModels = model
                case .failure(let error):
                    self.targetingChecker.geoModels = nil
                    if shouldCollectFailures {
                        self.addTargetingFailureIfNeeded(
                            for: error,
                            reason: .geoTargetingFailed,
                            inappIds: self.targetingChecker.context.geoInapps
                        )
                    }
                }
                self.dispatchGroup.leave()
                self.geoService = nil
            }
        }
    }

    func fetchProductSegmentationIfNeeded(products: ProductCategory?, shouldCollectFailures: Bool = true) {
        guard targetingChecker.event?.name == SessionTemporaryStorage.shared.viewProductOperation else {
            Logger.common(message: "Skipping segmentation fetch: unexpected event '\(targetingChecker.event?.name ?? "nil")'")
            return
        }

        guard let products = products,
              let firstProduct = products.firstProduct else {
            Logger.common(message: "Skipping segmentation fetch: no products or empty IDs")
            return
        }

        guard targetingChecker.checkedProductSegmentations[firstProduct] == nil else {
            Logger.common(message: "Skipping segmentation fetch: already checked for product '\(firstProduct.key)'")
            return
        }

        dispatchGroup.enter()
        segmentationService.checkProductSegmentationRequest(products: products) { result in
            switch result {
            case .success(let response):
                if let response = response {
                    self.targetingChecker.checkedProductSegmentations[firstProduct] = response
                }
            case .failure(let error):
                if shouldCollectFailures {
                    self.addTargetingFailureIfNeeded(
                        for: error,
                        reason: .productSegmentRequestFailed,
                        inappIds: self.targetingChecker.context.productSegmentInapps
                    )
                }
            }

            self.dispatchGroup.leave()
        }
    }

    private func addTargetingFailureIfNeeded(
        for error: MindboxError,
        reason: InAppShowFailureReason,
        inappIds: Set<String>
    ) {
        guard case .serverError = error else {
            return
        }

        let details = error.failureReason
        inappIds.forEach {
            failureManager.addFailure(inappId: $0, reason: reason, details: details)
        }
    }
}
