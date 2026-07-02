//
//  InAppMessagesTracker.swift
//  Mindbox
//
//  Created by Максим Казаков on 21.10.2022.
//  Copyright © 2022 Mikhail Barilov. All rights reserved.
//

import Foundation

protocol InappTargetingTrackProtocol: AnyObject {
    func trackTargeting(id: String, tags: [String: String]?) throws
}

protocol InAppMessagesTrackerProtocol: AnyObject {
    func trackView(id: String, timeToDisplay: String?, tags: [String: String]?) throws
    func trackClick(id: String, tags: [String: String]?) throws
}

class InAppMessagesTracker: InAppMessagesTrackerProtocol, InappTargetingTrackProtocol {

    struct InAppShowBody: Encodable {
        let inappId: String
        let timeToDisplay: String?
        let tags: [String: String]?

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(inappId, forKey: .inappId)
            try container.encodeIfPresent(timeToDisplay, forKey: .timeToDisplay)
            if let tags = tags, !tags.isEmpty {
                try container.encode(tags, forKey: .tags)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case inappId, timeToDisplay, tags
        }
    }

    struct InAppBody: Encodable {
        let inappId: String
        let tags: [String: String]?

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(inappId, forKey: .inappId)
            if let tags = tags, !tags.isEmpty {
                try container.encode(tags, forKey: .tags)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case inappId, tags
        }
    }

    private let databaseRepository: DatabaseRepositoryProtocol
    private let featureToggleManager: FeatureToggleManager

    init(databaseRepository: DatabaseRepositoryProtocol, featureToggleManager: FeatureToggleManager) {
        self.databaseRepository = databaseRepository
        self.featureToggleManager = featureToggleManager
    }

    func trackView(id: String, timeToDisplay: String?, tags: [String: String]?) throws {
        let gatedTags = tags.gatedTags(isTagsFeatureEnabled: featureToggleManager.isFeatureEnabled(.shouldSendInAppTags))
        let encodable = InAppShowBody(inappId: id, timeToDisplay: timeToDisplay, tags: gatedTags)
        let event = Event(type: .inAppViewEvent, body: BodyEncoder(encodable: encodable).body)
        try databaseRepository.create(event: event)
    }

    func trackClick(id: String, tags: [String: String]?) throws {
        let gatedTags = tags.gatedTags(isTagsFeatureEnabled: featureToggleManager.isFeatureEnabled(.shouldSendInAppTags))
        let encodable = InAppBody(inappId: id, tags: gatedTags)
        let event = Event(type: .inAppClickEvent, body: BodyEncoder(encodable: encodable).body)
        try databaseRepository.create(event: event)
    }

    func trackTargeting(id: String, tags: [String: String]?) throws {
        let gatedTags = tags.gatedTags(isTagsFeatureEnabled: featureToggleManager.isFeatureEnabled(.shouldSendInAppTags))
        let encodable = InAppBody(inappId: id, tags: gatedTags)
        let event = Event(type: .inAppTargetingEvent, body: BodyEncoder(encodable: encodable).body)
        try databaseRepository.create(event: event)
    }
}
