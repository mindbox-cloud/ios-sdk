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
            .first
            .map { InAppResponse(triggerEvent: request.triggerEvent, inAppToShowId: $0.inAppId) }

        let targetings = request.possibleInApps.compactMap { $0.inAppId }
        let targetingsSet = Set(targetings)
        let segmentationRequest = SegmentationCheckRequest(
            segmentations: targetingsSet.map {
                SegmentationCheckRequest.Segmentation(ids: SegmentationCheckRequest.Segmentation.Id(externalId: $0))
            }
        )

        Logger.common(message: "Tracker.CheckCustomerSegments request. Body: \(segmentationRequest)", level: .debug, category: .inAppMessages)
        customerSegmentsAPI.fetchSegments(segmentationRequest) { response in
            completionQueue.async {
                guard let response = response,
                      response.status == .success else {
                    Logger.common(message: "Tracker.CheckCustomerSegments bad response. Response: \(String(describing: response))", level: .debug, category: .inAppMessages)
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
            response.customerSegmentations.compactMap {
                guard let segment = $0.segment?.ids else { return nil }
                return ($0.segmentation.ids.externalId, segment.externalId)
            },
            uniquingKeysWith: { f, _ in f }
        )
        Logger.common(message: "Fetched customer segments ([segmentationId: segmentId]): \(customerSegmentationDict)", level: .debug, category: .inAppMessages)
        if let inAppToShow = request.possibleInApps.first(where: { inApp in
            return true
        }) {
            Logger.common(message: "Found segment match for in-app: \(inAppToShow.inAppId)", level: .debug, category: .inAppMessages)
            completion(InAppResponse(triggerEvent: request.triggerEvent, inAppToShowId: inAppToShow.inAppId))
        } else {
            Logger.common(message: "Didn't find in-app that match segments", level: .debug, category: .inAppMessages)
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
