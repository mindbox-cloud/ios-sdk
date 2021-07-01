//
//  DeliveredNotificationManager.swift
//  Mindbox
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
        queue.name = "Mindbox-DeliveredNotificationQueue"
        return queue
    }()
    
    private let semaphore = DispatchSemaphore(value: 0)
    
    private let timeout: TimeInterval = 5.0
        
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
            .category(.notification).level(.info).make()
        let pushDelivered = PushDelivered(uniqKey: uniqueKey)
        let event = Event(type: .pushDelivered, body: BodyEncoder(encodable: pushDelivered).body)
        track(event: event)
        return performSemaphoreWait()
    }

    @discardableResult
    func track(request: UNNotificationRequest) throws -> Bool {
        let decoder = try NotificationDecoder<NotificationsPayloads.Delivery>(request: request)
        guard decoder.isMindboxNotification else {
            Log("Push notification is not from Mindbox")
                .category(.notification).level(.info).make()
            return false
        }
        let payload = try decoder.decode()
        Log("Mindbox notification uniqueKey: \(payload.uniqueKey)")
            .category(.notification).level(.info).make()
        return try track(uniqueKey: payload.uniqueKey)
    }
    
    private func performSemaphoreWait() -> Bool {
        switch semaphore.wait(wallTimeout: .now() + timeout) {
        case .success:
            Log("Track succeeded")
                .category(.notification).level(.info).make()
            return true
        case .timedOut:
            queue.cancelAllOperations()
            Log("Track time expired")
                .category(.notification).level(.info).make()
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
            .category(.notification).level(.info).make()
        queue.addOperations([deliverOperation], waitUntilFinished: false)
    }
    
}


