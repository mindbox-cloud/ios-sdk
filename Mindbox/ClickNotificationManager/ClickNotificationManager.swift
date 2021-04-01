//
//  ClickNotificationManager.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 31.03.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import UserNotifications

final class ClickNotificationManager {
    
    private let databaseRepository: MBDatabaseRepository
    
    init(
        databaseRepository: MBDatabaseRepository
    ) {
        self.databaseRepository = databaseRepository
    }
    
    func track(uniqueKey: String, buttonUniqueKey: String? = nil) throws {
        var trackMobilePushClick: TrackClick?
        if let buttonUniqueKey = buttonUniqueKey {
            if buttonUniqueKey == UNNotificationDefaultActionIdentifier {
                trackMobilePushClick = TrackClick(messageUniqueKey: uniqueKey)
            } else if buttonUniqueKey != UNNotificationDismissActionIdentifier {
                trackMobilePushClick = TrackClick(messageUniqueKey: uniqueKey, buttonUniqueKey: buttonUniqueKey)
            }
        } else {
            trackMobilePushClick = TrackClick(messageUniqueKey: uniqueKey)
        }
        guard let encodable = trackMobilePushClick else {
            return
        }
        let event = Event(type: .trackClick, body: BodyEncoder(encodable: encodable).body)
        try databaseRepository.create(event: event)
    }
    
    func track(response: UNNotificationResponse) throws {
        let decoder = try NotificationDecoder<NotificationsPayloads.Click>(response: response)
        let payload = try decoder.decode()
        try track(uniqueKey: payload.uniqueKey, buttonUniqueKey: response.actionIdentifier)
    }
    
}
