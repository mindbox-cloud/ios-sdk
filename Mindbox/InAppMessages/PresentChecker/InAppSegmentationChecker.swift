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
//        POST https://api(-staging).mindbox.ru/v3/operations/sync?endpointId={Идентификатор точки интеграции}&operation=Tracker.CheckCustomerSegments&deviceUUID={UUID устройства}
//
//    Headers:
//        Content-Type: application/json; charset=utf-8
//    Accept: application/json
//        User-Agent: {User-Agent устройства клиента}
//        X-Customer-IP: {IP адрес клиента}

        let targetings = request.possibleInApps.compactMap { $0.targeting }
        let segmentationRequest = SegmentationCheckRequest(
            segmentations: targetings.map {
                SegmentationCheckRequest.Segmentation(
                    ids: SegmentationCheckRequest.Segmentation.Id(externalId: $0.segmention)
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

            if let inAppToShow = request.possibleInApps.first(where: { inApp in
                guard let targeting = inApp.targeting else { return false }
                return customerSegmentationDict[targeting.segmention] == targeting.segment
            }) {
                completion(InAppResponse(triggerEvent: request.triggerEvent, inAppToShowId: inAppToShow.inAppId))
            } else {
                completion(nil)
            }
        }
    }

    private func fetchSegments(segmentationCheckRequest: SegmentationCheckRequest, completion: @escaping (SegmentationCheckResponse?) -> Void) {

    }
}


struct SegmentationCheckRequest: Encodable {
    let segmentations: [Segmentation]

    struct Segmentation: Encodable {
        let ids: Id

        struct Id: Encodable {
            let externalId: String
        }
    }
}

struct SegmentationCheckResponse: Decodable {
    enum Status: String, Decodable {
        case success = "Success"
        case validationError = "ValidationError"
        case protocolError = "ProtocolError"
    }

    let status: Status?
    let customerSegmentations: [CustomerSegmentation]

    struct CustomerSegmentation: Decodable {
        let segmentation: Segmentation
        let segment: Segment?
    }

    struct Segmentation: Decodable {
        let ids: Id
    }

    struct Segment: Decodable {
        let ids: Id?
    }

    struct Id: Decodable {
        let externalId: String
    }
}
