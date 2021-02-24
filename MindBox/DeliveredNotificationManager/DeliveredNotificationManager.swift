//
//  DeliveredNotificationManager.swift
//  MindBox
//
//  Created by Maksim Kazachkov on 20.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import UserNotifications

final class DeliveredNotificationManager {
    
    @Injected var databaseRepository: MBDatabaseRepository

    init() {
        // TODO: - handle init for db
    }
    
    func track(userInfo: [AnyHashable : Any]) throws {
        Log("Track request with userInfo: \(userInfo)")
            .inChanel(.notification).withType(.info).make()
        let payload = try parse(userInfo: userInfo)
        let event = makeEvent(with: payload)
        try databaseRepository.create(event: event)
        Log("Successfully tracked event:\(event)")
            .inChanel(.notification).withType(.info).make()
    }

    func track(request: UNNotificationRequest) throws {
        guard let userInfo = (request.content.mutableCopy() as? UNMutableNotificationContent)?.userInfo else {
            throw DeliveredNotificationManagerError.unableToFetchUserInfo
        }
        try track(userInfo: userInfo)
    }
    
    private func parse(userInfo: [AnyHashable: Any]) throws -> Payload {
        do {
            let data = try JSONSerialization.data(withJSONObject: userInfo, options: .prettyPrinted)
            let decoder = JSONDecoder()
            do {
                let payload = try decoder.decode(Payload.self, from: data)
                Log("Did parse payload: \(payload)")
                    .inChanel(.notification).withType(.info).make()
                return payload
            } catch {
                Log("Did fail to decode Payload with error: \(error.localizedDescription)")
                    .inChanel(.notification).withType(.error).make()
                throw error
            }
        } catch {
            Log("Did fail to serialize userInfo with error: \(error.localizedDescription)")
                .inChanel(.notification).withType(.error).make()
            throw error
        }
    }
    
    private func makeEvent(with payload: Payload) -> Event {
        let pushDelivered = PushDelivered(uniqKey: payload.uniqueKey)
        let event = Event(type: .pushDelivered, body: BodyEncoder(encodable: pushDelivered).body)
        return event
    }
    
}

fileprivate struct Payload: Codable, CustomDebugStringConvertible {
    
    let uniqueKey: String
    
    var debugDescription: String {
        "uniqueKey: \(uniqueKey)"
    }
    
}
