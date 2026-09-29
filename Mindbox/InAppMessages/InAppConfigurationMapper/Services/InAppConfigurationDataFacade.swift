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
    /// Buffers an `Inapp.ShowFailure` for every cut candidate whose fetch failed on the server side.
    /// Returns whether any cut candidate could not be checked at all — its segmentation or geo failed
    /// to fetch for whatever reason, offline included. Such a pass did not find the place empty.
    @discardableResult
    func collectTargetingFailures(forFailedTargetingInappIds failedTargetingInappIds: Set<String>, tagsByInappId: [String: [String: String]]) -> Bool

    func downloadImage(withUrl url: String, inappId: String, tags: [String: String]?, completion: @escaping (Result<UIImage, MindboxError>) -> Void)
    func trackTargeting(id: String?, tags: [String: String]?)

    /// Sends what the pass buffered — targeting and image failures alike — as one `Inapp.ShowFailure`.
    func sendCollectedFailures()

    /// Drops what the pass buffered: it picked something to show, so there is no "why nothing was shown".
    func discardCollectedFailures()
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

    /// What the analytics hear: only a server-side failure is reported, per candidate it cut.
    /// Written from the fetch callbacks — segmentation answers on the main thread, geo on a URLSession
    /// thread — and read on the pass's queue, hence the lock; the same for the set below.
    @Locked private var pendingTargetingFailureDetails: [InAppShowFailureReason: String] = [:]

    /// What the place hears: any fetch that failed left its candidates unchecked, offline included.
    @Locked private var uncheckableReasons: Set<InAppShowFailureReason> = []

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
        pendingTargetingFailureDetails = [:]
        uncheckableReasons = []
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

    @discardableResult
    func collectTargetingFailures(forFailedTargetingInappIds failedTargetingInappIds: Set<String>, tagsByInappId: [String: [String: String]]) -> Bool {
        let reported = $pendingTargetingFailureDetails.exchange([:])
        let uncheckable = $uncheckableReasons.exchange([])

        guard !failedTargetingInappIds.isEmpty else {
            return false
        }

        reported.forEach { reason, details in
            failedTargetingInappIds.intersection(inappIds(for: reason)).forEach {
                failureManager.addFailure(inappId: $0, reason: reason, details: details, tags: tagsByInappId[$0])
            }
        }

        return uncheckable.contains { !failedTargetingInappIds.isDisjoint(with: inappIds(for: $0)) }
    }

    func downloadImage(withUrl url: String, inappId: String, tags: [String: String]?, completion: @escaping (Result<UIImage, MindboxError>) -> Void) {
        imageService.downloadImage(withUrl: url) { result in
            if case .failure(let error) = result {
                switch error {
                case .serverError, .protocolError, .unknown:
                    let details = "Image URL: \(url) | \(error.localizedDescription)"
                    self.failureManager.addFailure(
                        inappId: inappId,
                        reason: .imageDownloadFailed,
                        details: details,
                        tags: tags
                    )
                default:
                    break
                }
            }
            completion(result)
        }
    }

    func trackTargeting(id: String?, tags: [String: String]?) {
        if let id = id {
            do {
                try self.tracker.trackTargeting(id: id, tags: tags)
                Logger.common(message: "Track InApp.Targeting. Id \(id)", level: .info, category: .inAppMessages)
            } catch {
                Logger.common(message: "Track InApp.Targeting failed with error: \(error)", level: .error, category: .inAppMessages)
            }
        }
    }

    func sendCollectedFailures() {
        failureManager.sendFailures()
    }

    func discardCollectedFailures() {
        failureManager.clearFailures()
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

        // Whatever failed, the candidates that need this data were not checked.
        $uncheckableReasons.mutate { $0.insert(reason) }

        // Only the server's own failure is worth a report; offline and the like are not its doing.
        guard case .serverError = error else {
            return
        }

        $pendingTargetingFailureDetails.mutate { $0[reason] = error.failureReason }
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
