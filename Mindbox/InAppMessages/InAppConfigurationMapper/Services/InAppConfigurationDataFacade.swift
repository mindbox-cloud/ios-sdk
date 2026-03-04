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
    func collectTargetingFailures(forFailedTargetingInappIds failedTargetingInappIds: Set<String>)
    func downloadImage(withUrl url: String, inappId: String, completion: @escaping (Result<UIImage, MindboxError>) -> Void)
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

    private var pendingTargetingFailureDetails: [InAppShowFailureReason: String] = [:]

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
        pendingTargetingFailureDetails.removeAll()
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

    func collectTargetingFailures(forFailedTargetingInappIds failedTargetingInappIds: Set<String>) {
        defer {
            pendingTargetingFailureDetails.removeAll()
        }

        guard !failedTargetingInappIds.isEmpty else {
            return
        }

        pendingTargetingFailureDetails.forEach { reason, details in
            let inappIds = inappIds(for: reason)
            failedTargetingInappIds.intersection(inappIds).forEach {
                failureManager.addFailure(inappId: $0, reason: reason, details: details)
            }
        }
    }

    func downloadImage(withUrl url: String, inappId: String, completion: @escaping (Result<UIImage, MindboxError>) -> Void) {
        imageService.downloadImage(withUrl: url) { result in
            if case .failure(let error) = result {
                switch error {
                case .serverError, .protocolError, .unknown:
                    self.failureManager.addFailure(
                        inappId: inappId,
                        reason: .imageDownloadFailed,
                        details: error.localizedDescription
                    )
                default:
                    break
                }
            }
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
        dispatchGroup.enter()
        segmentationService.checkSegmentationRequest { result in
            switch result {
            case .success(let response):
                self.targetingChecker.checkedSegmentations = response
            case .failure(let error):
                self.targetingChecker.checkedSegmentations = nil
                self.storeTargetingFailureIfNeeded(
                    for: error,
                    reason: .customerSegmentRequestFailed,
                    shouldCollectFailures: shouldCollectFailures
                )
            }
            self.dispatchGroup.leave()
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
                    self.storeTargetingFailureIfNeeded(
                        for: error,
                        reason: .geoRequestFailed,
                        shouldCollectFailures: shouldCollectFailures
                    )
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
                self.storeTargetingFailureIfNeeded(
                    for: error,
                    reason: .productSegmentRequestFailed,
                    shouldCollectFailures: shouldCollectFailures
                )
            }

            self.dispatchGroup.leave()
        }
    }

    private func storeTargetingFailureIfNeeded(
        for error: MindboxError,
        reason: InAppShowFailureReason,
        shouldCollectFailures: Bool
    ) {
        guard shouldCollectFailures else {
            return
        }
        guard case .serverError = error else {
            return
        }

        pendingTargetingFailureDetails[reason] = error.failureReason
    }

    private func inappIds(for reason: InAppShowFailureReason) -> Set<String> {
        switch reason {
        case .customerSegmentRequestFailed:
            return targetingChecker.context.segmentInapps
        case .geoRequestFailed:
            return targetingChecker.context.geoInapps
        case .productSegmentRequestFailed:
            return targetingChecker.context.productSegmentInapps
        default:
            return []
        }
    }
}
