//
//  GuaranteedDeliveryManager.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 08.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import CoreData
import UIKit
import BackgroundTasks

final class GuaranteedDeliveryManager: NSObject {
    
    private let databaseRepository: MBDatabaseRepository
    private let eventRepository: EventRepository
    
    let backgroundTaskManager: BackgroundTaskManagerProxy
    
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.qualityOfService = .utility
        queue.maxConcurrentOperationCount = 1
        queue.name = "Mindbox-GuaranteedDeliveryQueue"
        return queue
    }()
    
    private let semaphore = DispatchSemaphore(value: 1)
    
    var onCompletedEvent: ((_ event: Event, _ error: ErrorModel?) -> Void)?
    
    @objc dynamic var stateObserver: NSString
    
    private(set) var state: State = .idle {
        didSet {
            stateObserver = NSString(string: state.rawValue)
            Log("State didSet to value: \(state.description)")
                .category(.delivery).level(.info).make()
        }
    }
    
    var canScheduleOperations = false {
        didSet {
            Log("canScheduleOperation didSet to value: \(canScheduleOperations)")
                .category(.delivery).level(.info).make()
            performScheduleIfNeeded()
        }
    }
    
    private let fetchLimit: Int
    
    init(
        persistenceStorage: PersistenceStorage,
        databaseRepository: MBDatabaseRepository,
        eventRepository: EventRepository,
        retryDeadline: TimeInterval = 60,
        fetchLimit: Int = 20
    ) {
        self.databaseRepository = databaseRepository
        self.eventRepository = eventRepository
        self.backgroundTaskManager = BackgroundTaskManagerProxy(
            persistenceStorage: persistenceStorage,
            databaseRepository: databaseRepository
        )
        self.retryDeadline = retryDeadline
        self.fetchLimit = fetchLimit
        stateObserver = NSString(string: state.description)
        super.init()
        databaseRepository.onObjectsDidChange = performScheduleIfNeeded
        performScheduleIfNeeded()
        backgroundTaskManager.gdManager = self
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: nil) { [weak self] (_) in
            self?.performScheduleIfNeeded()
        }
    }
    
    private let retryDeadline: TimeInterval
    
    func performScheduleIfNeeded() {
        guard canScheduleOperations else {
            return
        }
        guard let count = try? databaseRepository.countEvents() else {
            return
        }
        guard count != 0 else {
            backgroundTaskManager.endBackgroundTask(success: true)
            return
        }
        scheduleOperations(fetchLimit: count <= fetchLimit ? count : fetchLimit)
    }
    
    private func scheduleOperations(fetchLimit: Int) {
        semaphore.wait()
        guard !state.isDelivering else {
            Log("Delivering. Ignore another schedule operation.")
                .category(.delivery).level(.info).make()
            semaphore.signal()
            return
        }
        Log("Start enqueueing events")
            .category(.delivery).level(.info).make()
        state = .delivering
        semaphore.signal()
        guard let events = try? databaseRepository.query(fetchLimit: fetchLimit, retryDeadline: retryDeadline) else {
            state = .idle
            return
        }
        guard !events.isEmpty else {
            state = .waitingForRetry
            Log("Schedule next call of performScheduleIfNeeded after TimeInterval: \(retryDeadline)")
                .category(.delivery).level(.info).make()
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + retryDeadline, execute: performScheduleIfNeeded)
            return
        }
        let completion = BlockOperation { [weak self] in
            Log("Completion of GuaranteedDelivery queue with events count \(events.count)")
                .category(.delivery).level(.info).make()
            self?.state = .idle
            self?.performScheduleIfNeeded()
        }
        let delivery = events.map {
            DeliveryOperation(
                databaseRepository: databaseRepository,
                eventRepository: eventRepository,
                event: $0
            )
        }
        Log("Enqueued events count: \(delivery.count)")
            .category(.delivery).level(.info).make()
        delivery.forEach {
            completion.addDependency($0)
            $0.onCompleted = onCompletedEvent // TODO: - remove
        }
        let operations = delivery + [completion]
        queue.addOperations(operations, waitUntilFinished: false)
    }
    
}

