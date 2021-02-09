//
//  GuaranteedDeliveryManager.swift
//  MindBox
//
//  Created by Maksim Kazachkov on 08.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import CoreData

final class GuaranteedDeliveryManager {
    
    @Injected var databaseRepository: MBDatabaseRepository
    
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.qualityOfService = .background
        queue.maxConcurrentOperationCount = 1
        queue.name = "MindBox-GuaranteedDeliveryQueue"
        return queue
    }()
    let semaphore = DispatchSemaphore(value: 1)
    private(set) var isDelivering = false {
        didSet {
            Log("isDelivering didSet to value: \(isDelivering)")
                .inChanel(.delivery).withType(.info).make()
        }
    }
    
    init() {
        databaseRepository.onObjectsDidChange = scheduleIfNeeded
        scheduleIfNeeded()
    }
    
    func scheduleIfNeeded() {
        let count = databaseRepository.count
        guard count != 0 else { return }
        scheduleOperations(fetchLimit: count)
    }
    
    func scheduleOperations(fetchLimit: Int = 20) {
        semaphore.wait()
        guard !isDelivering else {
            Log("Delivering. Ignore another schedule operation.")
                .inChanel(.delivery).withType(.info).make()
            semaphore.signal()
            return
        }
        Log("Start enqueueing events")
            .inChanel(.delivery).withType(.info).make()
        isDelivering = true
        semaphore.signal()
        guard let events = try? databaseRepository.query(fetchLimit: fetchLimit) else {
            isDelivering = false
            return
        }
        guard !events.isEmpty else {
            isDelivering = false
            return
        }
        let completion = BlockOperation { [weak self] in
            Log("Completion of GuaranteedDelivery queue with events count \(events.count)")
                .inChanel(.delivery).withType(.info).make()
            self?.isDelivering = false
            self?.scheduleIfNeeded()
        }
        let delivery = events.map {
            DeliveryOperation(event: $0)
        }
        Log("Enqueued events count: \(delivery.count)")
            .inChanel(.delivery).withType(.info).make()
        delivery.forEach {
            completion.addDependency($0)
        }
        let operations = delivery + [completion]
        queue.addOperations(operations, waitUntilFinished: false)
    }
    
}
