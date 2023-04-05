//
//  InAppProductSegmentResponse.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 06.04.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

struct InAppProductSegmentRequest: OperationBodyRequestType {
    let segmentations: [Segmentation]

    struct Segmentation: Encodable {
        let ids: Id

        struct Id: Encodable {
            let externalId: String
        }
    }
}

struct InAppProductSegmentResponse: OperationResponseType {
    let status: Status
    let customerSegmentations: [CustomerSegmentation]?

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
