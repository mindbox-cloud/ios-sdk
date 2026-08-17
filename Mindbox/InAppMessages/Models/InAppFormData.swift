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
    let tags: [String: String]?
    var operation: (name: String, body: String)?

    /// Params supplied by whoever asked for this show, merged flat into the page's start payload on
    /// top of the ones the config carries. Only a direct call has them.
    ///
    /// Whatever is sent wins, service keys included: for the SDK this is an opaque dictionary to pass
    /// on, neither validated nor limited. Collisions are settled in the config and the page.
    let extraParams: [String: JSONValue]?

    init(
        inAppId: String,
        isPriority: Bool,
        delayTime: String?,
        imagesDict: [String: UIImage],
        firstImageValue: String,
        content: MindboxFormVariant,
        frequency: InappFrequency?,
        tags: [String: String]? = nil,
        operation: (name: String, body: String)? = nil,
        extraParams: [String: JSONValue]? = nil
    ) {
        self.inAppId = inAppId
        self.isPriority = isPriority
        self.delayTime = delayTime
        self.imagesDict = imagesDict
        self.firstImageValue = firstImageValue
        self.content = content
        self.frequency = frequency
        self.tags = tags
        self.operation = operation
        self.extraParams = extraParams
    }
}

// TODO: - Need to remove this struct and use only InappFormData.
struct InAppTransitionData: Equatable {
    let inAppId: String
    let isPriority: Bool
    let delayTime: String?
    let content: MindboxFormVariant
    let frequency: InappFrequency?
    let tags: [String: String]?
}
