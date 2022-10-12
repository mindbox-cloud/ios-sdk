//
//  InAppConfig.swift
//  Mindbox
//
//  Created by Максим Казаков on 09.09.2022.
//

import Foundation

let inAppsSdkVersion = 1

struct InAppConfig: Equatable {
    var inAppsByEvent: [InAppMessageTriggerEvent: [InAppInfo]]

    struct InAppInfo: Equatable {
        let id: String
        let targeting: SegmentationTargeting?
        let formDataVariants: [SimpleImageInApp]
    }
}

struct SimpleImageInApp: Equatable {
    let imageUrl: String
    let redirectUrl: String
    let intentPayload: String
}

struct SegmentationTargeting: Equatable {
    let segmentation: String
    let segment: String
}
