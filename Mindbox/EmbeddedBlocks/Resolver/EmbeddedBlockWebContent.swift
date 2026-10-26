//
//  EmbeddedBlockWebContent.swift
//  Mindbox
//
//  Created by vailence on 06.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

struct EmbeddedBlockWebContent: Equatable {

    let inAppId: String

    let baseUrl: String

    let contentUrl: String

    let frequency: InappFrequency?

    let isPriority: Bool

    let tags: [String: String]?

    let params: [String: JSONValue]

    let delayTime: String?

    init(inAppId: String,
         baseUrl: String,
         contentUrl: String,
         frequency: InappFrequency?,
         isPriority: Bool = false,
         tags: [String: String]?,
         params: [String: JSONValue],
         delayTime: String? = nil) {
        self.inAppId = inAppId
        self.baseUrl = baseUrl
        self.contentUrl = contentUrl
        self.frequency = frequency
        self.isPriority = isPriority
        self.tags = tags
        self.params = params
        self.delayTime = delayTime
    }

    func isSamePage(as other: EmbeddedBlockWebContent) -> Bool {
        inAppId == other.inAppId && baseUrl == other.baseUrl && contentUrl == other.contentUrl
    }
}
