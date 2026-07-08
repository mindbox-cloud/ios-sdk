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
    }

    struct InAppBody: Encodable {
        let inappId: String
        let tags: [String: String]?
    }

    private let databaseRepository: DatabaseRepositoryProtocol
    private let featureToggleManager: FeatureToggleManager

    init(databaseRepository: DatabaseRepositoryProtocol, featureToggleManager: FeatureToggleManager) {
        self.databaseRepository = databaseRepository
        self.featureToggleManager = featureToggleManager
    }

    func trackView(id: String, timeToDisplay: String?, tags: [String: String]?) throws {
        let encodable = InAppShowBody(inappId: id, timeToDisplay: timeToDisplay, tags: featureToggleManager.gatedTags(tags))
        let event = Event(type: .inAppViewEvent, body: BodyEncoder(encodable: encodable).body)
        try databaseRepository.create(event: event)
    }

    func trackClick(id: String, tags: [String: String]?) throws {
        try track(id: id, tags: tags, type: .inAppClickEvent)
    }

    func trackTargeting(id: String, tags: [String: String]?) throws {
        try track(id: id, tags: tags, type: .inAppTargetingEvent)
    }

    private func track(id: String, tags: [String: String]?, type: Event.Operation) throws {
        let encodable = InAppBody(inappId: id, tags: featureToggleManager.gatedTags(tags))
        let event = Event(type: type, body: BodyEncoder(encodable: encodable).body)
        try databaseRepository.create(event: event)
    }
}
