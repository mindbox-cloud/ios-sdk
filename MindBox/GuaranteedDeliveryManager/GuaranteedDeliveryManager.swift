//
//  GuaranteedDeliveryManager.swift
//  MindBox
//
//  Created by Maksim Kazachkov on 08.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import CoreData
import UIKit

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
    
    enum State: String, CustomStringConvertible {
        
        case idle, delivering, waitingForRetry
         
        var isDelivering: Bool {
            self == .delivering
        }
        
        var isIdle: Bool {
            self == .idle
        }
        
        var isWaitingForRetry: Bool {
            self == .waitingForRetry
        }
        
        var description: String {
            rawValue
        }
        
    }
    
    var onCompletedEvent: ((_ event: Event, _ error: ErrorModel?) -> Void)?
    
    private(set) var state: State = .idle {
        didSet {
            Log("State didSet to value: \(state.description)")
                .inChanel(.delivery).withType(.info).make()
        }
    }
    
    var canScheduleOperations = true {
        didSet {
            Log("canScheduleOperation didSet to value: \(canScheduleOperations)")
                .inChanel(.delivery).withType(.info).make()
            performScheduleIfNeeded()
        }
    }
    
    init(retryDeadline: TimeInterval = 60) {
        self.retryDeadline = retryDeadline
        databaseRepository.onObjectsDidChange = performScheduleIfNeeded
        performScheduleIfNeeded()
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: nil) { [weak self] (_) in
            Log("UIApplication.didEnterBackgroundNotification")
                .inChanel(.system).withType(.info).make()
            self?.applicationDidEnterBackground()
        }
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: nil) { [weak self] (_) in
            Log("UIApplication.didBecomeActiveNotification")
                .inChanel(.system).withType(.info).make()
            self?.applicationDidBecomeActive()
        }
    }
    
    deinit {
      NotificationCenter.default.removeObserver(self)
    }
    
    private let retryDeadline: TimeInterval

    func performScheduleIfNeeded() {
        Log("Did call performScheduleIfNeeded after TimeInterval")
            .inChanel(.delivery).withType(.info).make()
        guard canScheduleOperations else { return }
        let count = databaseRepository.count
        guard count != 0 else {
            endBackgroundTask()
            return
        }
        scheduleOperations(fetchLimit: count <= 20 ? count : 20)
    }
    
    func scheduleOperations(fetchLimit: Int) {
        semaphore.wait()
        guard !state.isDelivering else {
            Log("Delivering. Ignore another schedule operation.")
                .inChanel(.delivery).withType(.info).make()
            semaphore.signal()
            return
        }
        Log("Start enqueueing events")
            .inChanel(.delivery).withType(.info).make()
        state = .delivering
        semaphore.signal()
        guard let events = try? databaseRepository.query(fetchLimit: fetchLimit, retryDeadline: retryDeadline) else {
            state = .idle
            return
        }
        guard !events.isEmpty else {
            state = .waitingForRetry
            Log("Schedule next call of performScheduleIfNeeded after TimeInterval: \(retryDeadline)")
                .inChanel(.delivery).withType(.info).make()
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + retryDeadline, execute: performScheduleIfNeeded)
            return
        }
        let completion = BlockOperation { [weak self] in
            Log("Completion of GuaranteedDelivery queue with events count \(events.count)")
                .inChanel(.delivery).withType(.info).make()
            self?.state = .idle
            self?.performScheduleIfNeeded()
        }
        let delivery = events.map {
            DeliveryOperation(event: $0)
        }
        Log("Enqueued events count: \(delivery.count)")
            .inChanel(.delivery).withType(.info).make()
        delivery.forEach {
            completion.addDependency($0)
            $0.onCompleted = onCompletedEvent
        }
        let operations = delivery + [completion]
        queue.addOperations(operations, waitUntilFinished: false)
    }
    
    // MARK: - Background
    
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid {
        didSet {
            if backgroundTaskID != .invalid {
                Log("Did begin BackgroundTaskID: \(backgroundTaskID)")
                    .inChanel(.background).withType(.info).make()
            } else {
                Log("Did become invalid BackgroundTaskID")
                    .inChanel(.background).withType(.info).make()
            }
        }
    }
    
    private func applicationDidEnterBackground() {
        guard backgroundTaskID == .invalid else {
            Log("BackgroundTask already in progress. Skip call of beginBackgroundTask")
                .inChanel(.background).withType(.info).make()
            return
        }
        Log("Beginnig BackgroundTask")
            .inChanel(.background).withType(.info).make()
        beginBackgroundTask()
    }
    
    private func applicationDidBecomeActive() {
        endBackgroundTask()
    }
    
    private func beginBackgroundTask() {
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: UUID().uuidString, expirationHandler: { [weak self] in
            guard let self = self else { return }
            Log("System calls expirationHandler for BackgroundTaskID: \(self.backgroundTaskID)")
                .inChanel(.background).withType(.info).make()
            self.endBackgroundTask()
            Log("BackgroundTimeRemaining after system calls expirationHandler: \(UIApplication.shared.backgroundTimeRemaining)")
                .inChanel(.background).withType(.info).make()
        })
        Log("BackgroundTimeRemaining: \(UIApplication.shared.backgroundTimeRemaining)")
            .inChanel(.background).withType(.info).make()
    
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 2*60) {
            Log("LOG TIMELINE")
                .inChanel(.background).withType(.info).make()

        }
    }
    
    func endBackgroundTask() {
        guard backgroundTaskID != .invalid else { return }
        Log("Ending BackgroundTaskID \(backgroundTaskID)")
            .inChanel(.background).withType(.info).make()
        UIApplication.shared.endBackgroundTask(self.backgroundTaskID)
        self.backgroundTaskID = .invalid
    }
    
}

