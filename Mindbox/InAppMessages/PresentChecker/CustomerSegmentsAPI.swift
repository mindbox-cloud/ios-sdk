//
//  CustomerSegmentsAPI.swift
//  Mindbox
//
//  Created by Максим Казаков on 13.09.2022.
//  Copyright © 2022 Mikhail Barilov. All rights reserved.
//

import Foundation

struct CustomerSegmentsAPI {
    var fetchSegments: (_ segmentationCheckRequest: SegmentationCheckRequest, _ completion: @escaping (SegmentationCheckResponse?) -> Void) -> Void
    var fetchProductSegments: (_ segmentationCheckRequest: InAppProductSegmentRequest, _ completion: @escaping (InAppProductSegmentResponse?) -> Void) -> Void
}

extension CustomerSegmentsAPI {
    static let live = CustomerSegmentsAPI(
        fetchSegments: { segmentationCheckRequest, completion in
            Mindbox.shared.executeSyncOperation(
                operationSystemName: "Tracker.CheckCustomerSegments",
                operationBody: segmentationCheckRequest,
                customResponseType: SegmentationCheckResponse.self,
                completion: { result in
                    switch result {
                    case .success(let response):
                        completion(response)
                    case .failure:
                        completion(nil)
                    }
                }
            )
        }, fetchProductSegments: { segmentationCheckRequest, completion in
            Mindbox.shared.executeSyncOperation(
                operationSystemName: "Tracker.CheckProductSegments",
                operationBody: segmentationCheckRequest,
                customResponseType: InAppProductSegmentResponse.self,
                completion: { result in
                    switch result {
                    case .success(let response):
                        completion(response)
                    case .failure:
                        completion(nil)
                    }
                }
            )
        }
    )
}
