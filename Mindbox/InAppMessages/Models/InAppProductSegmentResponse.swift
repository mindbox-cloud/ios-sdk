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
    let products: [ProductCategory]

    struct Segmentation: Encodable {
        let ids: Id

        struct Id: Encodable {
            let externalId: String
        }
    }
}

struct InAppProductSegmentResponse: OperationResponseType {
    let status: Status
    let products: [Product]?

    struct Product: Codable {
        let ids: [String: String]
        let segmentations: [CustomerSegmentation]
    }

    struct CustomerSegmentation: Codable, Equatable {
        let ids: Id
        let segment: Segment?
    }

    struct Segment: Codable, Equatable {
        let ids: Id?
    }

    struct Id: Codable, Equatable {
        let externalId: String
    }
}
