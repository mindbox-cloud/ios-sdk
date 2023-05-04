//
//  InAppConfig.swift
//  Mindbox
//
//  Created by Максим Казаков on 09.09.2022.
//

import Foundation

let inAppsSdkVersion = 6

struct InAppConfig: Equatable {
    var inAppsByEvent: [InAppMessageTriggerEvent: [InAppInfo]]

    struct InAppInfo: Equatable {
        let id: String
        let formDataVariants: [SimpleImageInApp]
    }
}

struct SimpleImageInApp: Equatable {
    let image: UIImage
    let redirectUrl: String
    let intentPayload: String
}
