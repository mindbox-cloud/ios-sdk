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
    
    public func track(uniqueKey: String, buttonUniqueKey: String? = nil) throws {
        let trackMobilePushClick = TrackClick(messageUniqueKey: uniqueKey, buttonUniqueKey: buttonUniqueKey)
        let event = Event(type: .trackClick, body: BodyEncoder(encodable: trackMobilePushClick).body)
        try databaseRepository.create(event: event)
    }
    
    public func track(response: UNNotificationResponse) throws {
        let decoder = try NotificationDecoder<NotificationsPayloads.Click>(response: response)
        let payload = try decoder.decode()
        var trackMobilePushClick: TrackClick?
        if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            trackMobilePushClick = TrackClick(messageUniqueKey: payload.uniqueKey)
        } else if response.actionIdentifier != UNNotificationDismissActionIdentifier {
            trackMobilePushClick = TrackClick(messageUniqueKey: payload.uniqueKey, buttonUniqueKey: response.actionIdentifier)
        }
        guard let encodable = trackMobilePushClick else {
            return
        }
        let event = Event(type: .trackClick, body: BodyEncoder(encodable: encodable).body)
        try databaseRepository.create(event: event)
    }
    
}
