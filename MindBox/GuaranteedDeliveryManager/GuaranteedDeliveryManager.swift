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
    
    private var isDelivering = false
    
    init() {
        databaseRepository.onCount = { [weak self] in
            self?.scheduleOperations(fetchLimit: $0)
        }
        scheduleOperations(fetchLimit: databaseRepository.count)
    }
    
    func scheduleOperations(fetchLimit: Int = 20) {
        guard !isDelivering else {
            return
        }
        isDelivering = true
        guard let events = try? databaseRepository.query(fetchLimit: fetchLimit) else {
            return
        }
        guard !events.isEmpty else {
            return
        }
        let completion = BlockOperation { [weak self] in
            self?.isDelivering = false
            self?.scheduleOperations()
        }
        let delivery = events.map {
            DeliveryOperation(event: $0)
        }
        delivery.forEach {
            completion.addDependency($0)
        }
        let operations = delivery + [completion]
        queue.addOperations(operations, waitUntilFinished: false)
    }
    
}
