//
//  InAppPresentChecker.swift
//  Mindbox
//
//  Created by Максим Казаков on 06.09.2022.
//  Copyright © 2022 Mikhail Barilov. All rights reserved.
//

import Foundation

/// Makes request to network and returns in-app messages that should be shown
final class InAppSegmentationChecker {

    func getInAppToPresent(request: InAppsCheckRequest, completionQueue: DispatchQueue, _ completion: @escaping (InAppResponse?) -> Void) {
        let targetings = request.possibleInApps.compactMap { $0.targeting }
        let segmentationRequest = SegmentationCheckRequest(
            segmentations: targetings.map {
                SegmentationCheckRequest.Segmentation(
                    ids: SegmentationCheckRequest.Segmentation.Id(externalId: $0.segmentation)
                )
            }
        )
        fetchSegments(segmentationCheckRequest: segmentationRequest) { response in
            guard let response = response,
                  response.status == .success else { return }

            // [SegmentationId: SegmentId] from response
            let customerSegmentationDict: [String: String] = Dictionary(
                uniqueKeysWithValues: response.customerSegmentations.compactMap {
                    guard let segment = $0.segment?.ids else { return nil }
                    return ($0.segmentation.ids.externalId, segment.externalId)
                }
            )
            Log("Fetched customer segments ([segmentationId: segmentId]): \(customerSegmentationDict)")
                .category(.inAppMessages).level(.debug).make()

            Log("InApps segments: \(targetings)")
                .category(.inAppMessages).level(.debug).make()

            if let inAppToShow = request.possibleInApps.first(where: { inApp in
                guard let targeting = inApp.targeting else { return false }
                return targeting.segment == customerSegmentationDict[targeting.segmentation] 
            }) {
                Log("Found segment match for in-app: \(inAppToShow.inAppId)")
                    .category(.inAppMessages).level(.debug).make()
                completion(InAppResponse(triggerEvent: request.triggerEvent, inAppToShowId: inAppToShow.inAppId))
            } else {
                Log("Didn't find in-app that match segments")
                    .category(.inAppMessages).level(.debug).make()
                completion(nil)
            }
        }
    }

    private func fetchSegments(segmentationCheckRequest: SegmentationCheckRequest, completion: @escaping (SegmentationCheckResponse?) -> Void) {
        Mindbox.shared.executeSyncOperation(
            operationSystemName: "Tracker.CheckCustomerSegments",
            operationBody: segmentationCheckRequest,
            customResponseType: SegmentationCheckResponse.self,
            completion: { result in
                switch result {
                case .success(let response):
                    completion(response)
                case .failure:
                    break
                }
            }
        )
    }
}


struct SegmentationCheckRequest: OperationBodyRequestType {
    let segmentations: [Segmentation]

    struct Segmentation: Encodable {
        let ids: Id

        struct Id: Encodable {
            let externalId: String
        }
    }
}

struct SegmentationCheckResponse: OperationResponseType {
    let status: Status
    let customerSegmentations: [CustomerSegmentation]

    struct CustomerSegmentation: Codable {
        let segmentation: Segmentation
        let segment: Segment?
    }

    struct Segmentation: Codable {
        let ids: Id
    }

    struct Segment: Codable {
        let ids: Id?
    }

    struct Id: Codable {
        let externalId: String
    }
}
