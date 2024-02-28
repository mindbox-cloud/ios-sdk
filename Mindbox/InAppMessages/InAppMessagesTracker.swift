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
    func trackView(id: String) throws
    func trackClick(id: String) throws

}

class InAppMessagesTracker: InAppMessagesTrackerProtocol, InappTargetingTrackProtocol {

    struct InAppBody: Codable {
        let inappId: String
    }

    private let databaseRepository: MBDatabaseRepository

    init(databaseRepository: MBDatabaseRepository) {
        self.databaseRepository = databaseRepository
    }

    func trackView(id: String) throws {
        let encodable = InAppBody(inappId: id)
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
