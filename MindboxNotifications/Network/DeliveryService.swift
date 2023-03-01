//
//  DeliveryService.swift
//  MindboxNotifications
//
//  Created by Ihor Kandaurov on 22.06.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import UserNotifications

public class DeliveryService {
    private let networkService: NetworkService
    private let utilitiesFetcher: MBUtilitiesFetcher

    init(utilitiesFetcher: MBUtilitiesFetcher, networkService: NetworkService) {
        self.utilitiesFetcher = utilitiesFetcher
        self.networkService = networkService
    }

    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.name = "MindboxNotifications-DeliveryServiceQueue"
        return queue
    }()

    private let semaphore = DispatchSemaphore(value: 0)

    private let timeout: TimeInterval = 5.0

    @discardableResult
    func track(uniqueKey: String) throws -> Bool {
        let pushDelivered = PushDelivered(uniqKey: uniqueKey)
        let event = Event(type: .pushDelivered, body: BodyEncoder(encodable: pushDelivered).body)
        track(event: event)
        return performSemaphoreWait()
    }

    @discardableResult
    func track(request: UNNotificationRequest) throws -> Bool {
        guard let decoder = NotificationDecoder<NotificationsPayloads.Delivery>(request: request) else {
            return false
        }
        guard decoder.isMindboxNotification else {
            return false
        }
        let payload = try decoder.decode()
        return try track(uniqueKey: payload.uniqueKey)
    }

    private func performSemaphoreWait() -> Bool {
        let methodStart = Date()
        switch semaphore.wait(wallTimeout: .now() + timeout) {
        case .success:
            let methodEnd = Date()
            Logger.common(message: "Finished operation in \(methodEnd.timeIntervalSince(methodStart)) sec", level: .debug, category: .delivery)
            return true
        case .timedOut:
            let methodEnd = Date()
            Logger.common(message: "Finished operation in \(methodEnd.timeIntervalSince(methodStart)) sec", level: .debug, category: .delivery)
            queue.cancelAllOperations()
            return false
        }
    }

    private func track(event: Event) {
        let isConfigurationSet = utilitiesFetcher.configuration != nil
        guard isConfigurationSet else {
            semaphore.signal()
            Logger.common(message: "Can't find configuration", level: .info, category: .delivery)
            return
        }
        let deliverOperation = PushDeliveryOperation(
            event: event,
            service: networkService
        )
        deliverOperation.onCompleted = { [weak self] _, _ in
            Logger.common(message: "Operation completed", level: .info, category: .delivery)
            self?.semaphore.signal()
        }
        queue.addOperations([deliverOperation], waitUntilFinished: false)
    }
}
