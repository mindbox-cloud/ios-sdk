//
//  InAppMessagesTracker.swift
//  Mindbox
//
//  Created by Максим Казаков on 21.10.2022.
//  Copyright © 2022 Mikhail Barilov. All rights reserved.
//

import Foundation

protocol InappTargetingTrackProtocol: AnyObject {
    func trackTargeting(id: String) throws
}

protocol InAppMessagesTrackerProtocol: AnyObject {
    func trackView(id: String, timeToDisplay: String?, tags: [String: String]?) throws
    func trackClick(id: String) throws
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

    struct InAppBody: Codable {
        let inappId: String
    }

    private let databaseRepository: DatabaseRepositoryProtocol

    init(databaseRepository: DatabaseRepositoryProtocol) {
        self.databaseRepository = databaseRepository
    }

    func trackView(id: String, timeToDisplay: String?, tags: [String: String]?) throws {
        let encodable = InAppShowBody(inappId: id, timeToDisplay: timeToDisplay, tags: tags)
        let event = Event(type: .inAppViewEvent, body: BodyEncoder(encodable: encodable).body)
        try databaseRepository.create(event: event)
    }

    func trackClick(id: String) throws {
        let encodable = InAppBody(inappId: id)
        let event = Event(type: .inAppClickEvent, body: BodyEncoder(encodable: encodable).body)
        try databaseRepository.create(event: event)
    }

    func trackTargeting(id: String) throws {
        let encodable = InAppBody(inappId: id)
        let event = Event(type: .inAppTargetingEvent, body: BodyEncoder(encodable: encodable).body)
        try databaseRepository.create(event: event)
    }
}
