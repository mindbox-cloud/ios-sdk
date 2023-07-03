//
//  SegmentationCheckRequest.swift
//  Mindbox
//
//  Created by vailence on 16.06.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

struct SegmentationCheckRequest: OperationBodyRequestType {
    let segmentations: [Segmentation]

    struct Segmentation: Encodable {
        let ids: Id

        struct Id: Encodable {
            let externalId: String
        }
    }
}
