//
//  SegmentationService.swift
//  Mindbox
//
//  Created by vailence on 31.05.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

protocol SegmentationServiceProtocol {
    func checkSegmentationRequest(completion: @escaping ([SegmentationCheckResponse.CustomerSegmentation]?) -> Void)
    func checkProductSegmentationRequest(products: ProductCategory, completion: @escaping ([InAppProductSegmentResponse.CustomerSegmentation]?) -> Void)
}

class SegmentationService: SegmentationServiceProtocol {
    let customerSegmentsAPI: CustomerSegmentsAPI
    var sessionTemporaryStorage: SessionTemporaryStorage
    var targetingChecker: InAppTargetingCheckerProtocol

    init(customerSegmentsAPI: CustomerSegmentsAPI,
         sessionTemporaryStorage: SessionTemporaryStorage,
         targetingChecker: InAppTargetingCheckerProtocol) {
        self.customerSegmentsAPI = customerSegmentsAPI
        self.sessionTemporaryStorage = sessionTemporaryStorage
        self.targetingChecker = targetingChecker
    }

    func checkSegmentationRequest(completion: @escaping ([SegmentationCheckResponse.CustomerSegmentation]?) -> Void) {
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
            guard let response = response, response.status == .success else {
                Logger.common(message: "Customer Segment does not exist, or response status not equal to Success. Status: \(String(describing: response?.status))", level: .debug, category: .inAppMessages)

                completion(nil)
                return
            }

            Logger.common(message: "Customer Segment response: \n\(response)")
            completion(response.customerSegmentations)
        }
    }

    func checkProductSegmentationRequest(products: ProductCategory, completion: @escaping ([InAppProductSegmentResponse.CustomerSegmentation]?) -> Void) {
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
            guard let response = response, response.status == .success else {
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
}
