//
//  InAppPresentChecker.swift
//  Mindbox
//
//  Created by Максим Казаков on 06.09.2022.
//  Copyright © 2022 Mikhail Barilov. All rights reserved.
//

import Foundation

protocol InAppSegmentationCheckerProtocol: AnyObject {
    func getInAppToPresent(request: InAppsCheckRequest, completionQueue: DispatchQueue, _ completion: @escaping (InAppResponse?) -> Void)
}

/// Makes request to network and returns in-app messages that should be shown
final class InAppSegmentationChecker: InAppSegmentationCheckerProtocol {

    private let customerSegmentsAPI: CustomerSegmentsAPI

    init(customerSegmentsAPI: CustomerSegmentsAPI) {
        self.customerSegmentsAPI = customerSegmentsAPI
    }

    // It's guaranteed that the method will return the first inapp in list that fits the conditions
    func getInAppToPresent(request: InAppsCheckRequest, completionQueue: DispatchQueue, _ completion: @escaping (InAppResponse?) -> Void) {
        // In case segmentation check failed, we need to show the first inapp without targeting
        let firstWithoutTargeting = request.possibleInApps
            .first(where: { $0.targeting == nil })
            .map { InAppResponse(triggerEvent: request.triggerEvent, inAppToShowId: $0.inAppId) }

        let targetings = request.possibleInApps.compactMap { $0.targeting }
        let segmentationRequest = SegmentationCheckRequest(
            segmentations: targetings.map {
                SegmentationCheckRequest.Segmentation(
                    ids: SegmentationCheckRequest.Segmentation.Id(externalId: $0.segmentation)
                )
            }
        )

        Log("InApps segments: \(targetings)")
            .category(.inAppMessages).level(.debug).make()

        customerSegmentsAPI.fetchSegments(segmentationRequest) { response in
            completionQueue.async {
                guard let response = response,
                      response.status == .success else {
                    completion(firstWithoutTargeting)
                    return
                }
                self.completeWithResponse(response, request: request, completion: completion)
            }
        }
    }

    private func completeWithResponse(
        _ response: SegmentationCheckResponse,
        request: InAppsCheckRequest,
        completion: @escaping (InAppResponse?) -> Void
    ) {
        // [SegmentationId: SegmentId] from response
        let customerSegmentationDict: [String: String] = Dictionary(
            uniqueKeysWithValues: response.customerSegmentations.compactMap {
                guard let segment = $0.segment?.ids else { return nil }
                return ($0.segmentation.ids.externalId, segment.externalId)
            }
        )
        Log("Fetched customer segments ([segmentationId: segmentId]): \(customerSegmentationDict)")
            .category(.inAppMessages).level(.debug).make()

        if let inAppToShow = request.possibleInApps.first(where: { inApp in
            if let targeting = inApp.targeting {
                return targeting.segment == customerSegmentationDict[targeting.segmentation]
            } else {
                return true
            }
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
