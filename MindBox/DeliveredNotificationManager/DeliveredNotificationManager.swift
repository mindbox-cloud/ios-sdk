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
    
    private let persistenceStorage: PersistenceStorage
    private let databaseRepository: MBDatabaseRepository
    private let eventRepository: EventRepository
    
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.name = "MindBox-DeliveredNotificationQueue"
        return queue
    }()
    
    private let semaphore = DispatchSemaphore(value: 0)
    
    private let timeout: TimeInterval = 5.0
    
    let mindBoxIdentifireKey = "uniqueKey"
    
    init(
        persistenceStorage: PersistenceStorage,
        databaseRepository: MBDatabaseRepository,
        eventRepository: EventRepository
    ) {
        self.persistenceStorage = persistenceStorage
        self.databaseRepository = databaseRepository
        self.eventRepository = eventRepository
    }
    
    @discardableResult
    func track(uniqueKey: String) throws -> Bool {
        Log("Track started")
            .inChanel(.notification).withType(.info).make()
        let pushDelivered = PushDelivered(uniqKey: uniqueKey)
        let event = Event(type: .pushDelivered, body: BodyEncoder(encodable: pushDelivered).body)
        track(event: event)
        return performSemaphoreWait()
    }

    @discardableResult
    func track(request: UNNotificationRequest) throws -> Bool {
        let userInfo = try getUserInfo(from: request)
        guard userInfo[mindBoxIdentifireKey] != nil else {
            Log("Push notification is not from MindBox")
                .inChanel(.notification).withType(.info).make()
            return false
        }
        let payload = try parse(userInfo: userInfo)
        return try track(uniqueKey: payload.uniqueKey)
    }
    
    private func performSemaphoreWait() -> Bool {
        switch semaphore.wait(wallTimeout: .now() + timeout) {
        case .success:
            Log("Track succeeded")
                .inChanel(.notification).withType(.info).make()
            return true
        case .timedOut:
            queue.cancelAllOperations()
            Log("Track time expired")
                .inChanel(.notification).withType(.info).make()
            return false
        }
    }
    
    private func track(event: Event) {
        let isConfigurationSet = persistenceStorage.configuration != nil
        try? databaseRepository.create(event: event)
        guard isConfigurationSet else {
            semaphore.signal()
            return
        }
        let deliverOperation = DeliveryOperation(
            databaseRepository: databaseRepository,
            eventRepository: eventRepository,
            event: event
        )
        deliverOperation.onCompleted = { [weak self] (_, _) in
            self?.semaphore.signal()
        }
        Log("Started DeliveryOperation")
            .inChanel(.notification).withType(.info).make()
        queue.addOperations([deliverOperation], waitUntilFinished: false)
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
    
    private func getUserInfo(from request: UNNotificationRequest) throws -> [AnyHashable: Any] {
        guard let userInfo = (request.content.mutableCopy() as? UNMutableNotificationContent)?.userInfo else {
            throw DeliveredNotificationManagerError.unableToFetchUserInfo
        }
        if userInfo[mindBoxIdentifireKey] != nil {
            return userInfo
        } else if let innerUserInfo = userInfo["aps"] as? [AnyHashable: Any] {
            return innerUserInfo
        } else {
            return userInfo
        }
    }
    
}


