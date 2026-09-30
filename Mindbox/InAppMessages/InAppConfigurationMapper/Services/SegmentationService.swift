//
//  SegmentationService.swift
//  Mindbox
//
//  Created by vailence on 13.06.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

protocol SegmentationServiceProtocol {
    func checkSegmentationRequest(
        completion: @escaping (Result<[SegmentationCheckResponse.CustomerSegmentation]?, MindboxError>) -> Void
    )
    func checkProductSegmentationRequest(
        products: ProductCategory,
        completion: @escaping (Result<[InAppProductSegmentResponse.CustomerSegmentation]?, MindboxError>) -> Void
    )
}

class SegmentationService: SegmentationServiceProtocol {
    var customerSegmentsAPI: CustomerSegmentsAPI
    var targetingChecker: InAppTargetingCheckerProtocol

    init(customerSegmentsAPI: CustomerSegmentsAPI,
         targetingChecker: InAppTargetingCheckerProtocol) {
        self.customerSegmentsAPI = customerSegmentsAPI
        self.targetingChecker = targetingChecker
    }

    func checkSegmentationRequest(
        completion: @escaping (Result<[SegmentationCheckResponse.CustomerSegmentation]?, MindboxError>) -> Void
    ) {
        if let cachedResult = SessionTemporaryStorage.shared.segmentationRequestResult {
            completion(cachedResult)
            return
        }

        let arrayOfSegments = Array(Set(targetingChecker.context.segments))
        let segments: [SegmentationCheckRequest.Segmentation] = arrayOfSegments.map {
            return .init(ids: .init(externalId: $0))
        }

        if segments.isEmpty {
            completion(.success(nil))
            return
        }

        let model = SegmentationCheckRequest(segmentations: segments)

        customerSegmentsAPI.fetchSegments(model) { result in
            switch result {
            case .success(let response):
                guard response.status == .success else {
                    Logger.common(message: "Customer Segment does not exist, or response status not equal to Success. Status: \(response.status).", level: .debug, category: .inAppMessages)
                    SessionTemporaryStorage.shared.segmentationRequestResult = .success(nil)
                    completion(.success(nil))
                    return
                }

                Logger.common(message: "Customer Segment response: \n\(response)")
                SessionTemporaryStorage.shared.segmentationRequestResult = .success(response.customerSegmentations)
                completion(.success(response.customerSegmentations))
            case .failure(let error):
                Logger.error(error.asLoggerError())
                SessionTemporaryStorage.shared.segmentationRequestResult = .failure(error)
                completion(.failure(error))
            }
        }
    }

    func checkProductSegmentationRequest(
        products: ProductCategory,
        completion: @escaping (Result<[InAppProductSegmentResponse.CustomerSegmentation]?, MindboxError>) -> Void
    ) {
        let arrayOfSegments = Array(Set(targetingChecker.context.productSegments))
        let segments: [InAppProductSegmentRequest.Segmentation] = arrayOfSegments.map {
            return .init(ids: .init(externalId: $0))
        }

        if segments.isEmpty {
            completion(.success(nil))
            return
        }

        let model = InAppProductSegmentRequest(segmentations: segments, products: [products])

        customerSegmentsAPI.fetchProductSegments(model) { result in
            switch result {
            case .success(let response):
                guard response.status == .success else {
                    Logger.common(message: "Customer Segment does not exist, or response status not equal to Success. Status: \(response.status).", level: .debug, category: .inAppMessages)
                    completion(.success(nil))
                    return
                }

                Logger.common(message: "Customer Segment response: \n\(response).")
                var checkedProductSegmentations: [InAppProductSegmentResponse.CustomerSegmentation] = []
                response.products?.forEach {
                    checkedProductSegmentations.append(contentsOf: $0.segmentations)
                }

                completion(.success(checkedProductSegmentations))
            case .failure(let error):
                Logger.error(error.asLoggerError())
                completion(.failure(error))
            }
        }
    }
}
