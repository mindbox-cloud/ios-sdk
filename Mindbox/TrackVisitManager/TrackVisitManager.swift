//
//  TrackVistiManager.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 15.04.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import UIKit

final class TrackVisitManager {
    
    private let databaseRepository: MBDatabaseRepository

    init(
        databaseRepository: MBDatabaseRepository
    ) {
        self.databaseRepository = databaseRepository
    }
    
    func trackLaunch() throws {
        let encodable = TrackVisit()
        let event = Event(type: .trackVisit, body: BodyEncoder(encodable: encodable).body)
        try databaseRepository.create(event: event)
    }
    
    func track(with userActivity: NSUserActivity) throws {
        // TODO: - Implement handle userActivity
        let encodable = TrackVisit()
        let event = Event(type: .trackVisit, body: BodyEncoder(encodable: encodable).body)
        try databaseRepository.create(event: event)
    }
    
    func track(with url: URL) throws {
        // TODO: - Implement handle url
        let encodable = TrackVisit()
        let event = Event(type: .trackClick, body: BodyEncoder(encodable: encodable).body)
        try databaseRepository.create(event: event)
    }
     
}
