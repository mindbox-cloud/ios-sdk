//
//  InAppMessage.swift
//  Mindbox
//
//  Created by Максим Казаков on 06.09.2022.
//  Copyright © 2022 Mikhail Barilov. All rights reserved.
//

import Foundation
import UIKit

/// Domain model that contains all data needed to show inapp on screen
struct InAppFormData {
    let inAppId: String
    let isPriority: Bool
    let delayTime: String?
    let imagesDict: [String: UIImage]
    let firstImageValue: String
    let content: MindboxFormVariant
    let frequency: InappFrequency?
    var operation: (name: String, body: String)?

    init(
        inAppId: String,
        isPriority: Bool,
        delayTime: String?,
        imagesDict: [String: UIImage],
        firstImageValue: String,
        content: MindboxFormVariant,
        frequency: InappFrequency?,
        operation: (name: String, body: String)? = nil
    ) {
        self.inAppId = inAppId
        self.isPriority = isPriority
        self.delayTime = delayTime
        self.imagesDict = imagesDict
        self.firstImageValue = firstImageValue
        self.content = content
        self.frequency = frequency
        self.operation = operation
    }
}

// TODO: - Need to remove this struct and use only InappFormData.
struct InAppTransitionData: Equatable {
    let inAppId: String
    let isPriority: Bool
    let delayTime: String?
    let content: MindboxFormVariant
    let frequency: InappFrequency?
}
