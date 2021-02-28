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
    
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.name = "MindBox-DeliveredNotificationQueue"
        return queue
    }()
    
    private let semaphore = DispatchSemaphore(value: 0)
    
    private let timeout: TimeInterval = 5.0
    
    func track(userInfo: [AnyHashable : Any]) throws {
        Log("Track started")
            .inChanel(.notification).withType(.info).make()
        let prepareConfigurationStorageOperation = PrepareConfigurationStorageOperation()
        let parseEventOperation = ParseEventOperation(userInfo: userInfo)
        parseEventOperation.onCompleted = { [weak self] result in
            guard let self = self else {
                return
            }
            do {
                let event = try result.get()
                self.track(event: event)
            } catch {
                Log("Track failed with error: \(error.localizedDescription)")
                    .inChanel(.notification).withType(.info).make()
            }
        }
        parseEventOperation.addDependency(prepareConfigurationStorageOperation)
        queue.addOperations([prepareConfigurationStorageOperation, parseEventOperation], waitUntilFinished: false)
        switch semaphore.wait(wallTimeout: .now() + timeout) {
        case .success:
            Log("Track succeeded")
                .inChanel(.notification).withType(.info).make()
        case .timedOut:
            queue.cancelAllOperations()
            Log("Track time expired")
                .inChanel(.notification).withType(.info).make()
        }
    }
    
    func track(request: UNNotificationRequest) throws {
        guard let userInfo = (request.content.mutableCopy() as? UNMutableNotificationContent)?.userInfo else {
            throw DeliveredNotificationManagerError.unableToFetchUserInfo
        }
        try track(userInfo: userInfo)
    }
    
    private func track(event: Event) {
        let saveOperation = SaveEventOperation(event: event)
        let deliverOperation = DeliveryOperation(event: event)
        deliverOperation.addDependency(saveOperation)
        saveOperation.onCompleted = { [weak self] (_) in
            self?.semaphore.signal()
        }
        Log("Started DeliveryOperation")
            .inChanel(.notification).withType(.info).make()
        self.queue.addOperations([saveOperation, deliverOperation], waitUntilFinished: false)
    }
    
}
