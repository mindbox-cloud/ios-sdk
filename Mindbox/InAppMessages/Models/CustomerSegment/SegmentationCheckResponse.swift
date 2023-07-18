//
//  SegmentationCheckResponse.swift
//  Mindbox
//
//  Created by Максим Казаков on 06.09.2022.
//  Copyright © 2022 Mikhail Barilov. All rights reserved.
//

import Foundation
import MindboxLogger

struct SegmentationCheckResponse: OperationResponseType {
    let status: Status
    let customerSegmentations: [CustomerSegmentation]?

    struct CustomerSegmentation: Codable, Equatable {
        let segmentation: Segmentation
        let segment: Segment?
    }

    struct Segmentation: Codable, Equatable {
        let ids: Id
    }

    struct Segment: Codable, Equatable {
        let ids: Id?
    }

    struct Id: Codable, Equatable {
        let externalId: String
    }
}
