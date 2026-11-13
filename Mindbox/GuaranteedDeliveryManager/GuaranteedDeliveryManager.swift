//
//  GuaranteedDeliveryManager.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 08.02.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation
import CoreData
import UIKit
import BackgroundTasks
import MindboxLogger

final class GuaranteedDeliveryManager: NSObject {

    private let databaseRepository: DatabaseRepositoryProtocol
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
    private var isScheduleRequestedWhileDelivering = false

    private let pauseManager = DeliveryPauseManager()

    var onCompletedEvent: ((_ event: Event, _ error: MindboxError?) -> Void)?

    @objc dynamic var stateObserver: NSString

    @Locked private(set) var state: State = .idle {
        didSet {
            stateObserver = NSString(string: state.rawValue)
            Logger.common(message: "[GD] State did set to value: \(state.description)", level: .info, category: .delivery)
        }
    }

    @Locked var canScheduleOperations = false {
        didSet {
            Logger.common(message: "[GD] Scheduling of operations is now \(canScheduleOperations ? "enabled" : "disabled")", level: .info, category: .delivery)
            performScheduleIfNeeded()
        }
    }

    private let fetchLimit: Int

    init(
        persistenceStorage: PersistenceStorage,
        databaseRepository: DatabaseRepositoryProtocol,
        eventRepository: EventRepository,
        retryDeadline: TimeInterval = 60,
        maxRetryDeadline: TimeInterval = 3600,
        fetchLimit: Int = 20
    ) {
        self.databaseRepository = databaseRepository
        self.eventRepository = eventRepository
        self.backgroundTaskManager = BackgroundTaskManagerProxy(
            persistenceStorage: persistenceStorage,
            databaseRepository: databaseRepository
        )
        self.retryDelayManager = DeliveryRetryDelayManager(firstDelay: retryDeadline, maxDelay: maxRetryDeadline)
        self.fetchLimit = fetchLimit
        stateObserver = NSString(string: State.idle.description)
        super.init()
        databaseRepository.onObjectsDidChange = performScheduleIfNeeded
        performScheduleIfNeeded()
        backgroundTaskManager.gdManager = self
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: nil) { [weak self] _ in
            self?.performScheduleIfNeeded()
        }
    }

    private let retryDelayManager: DeliveryRetryDelayManager

    func performScheduleIfNeeded() {
        guard canScheduleOperations else {
            return
        }
        guard let events = try? databaseRepository.countEvents() else {
            return
        }
        guard events != 0 else {
            retryDelayManager.reset()
            backgroundTaskManager.endBackgroundTask(success: true)
            return
        }
        scheduleOperations(fetchLimit: events <= fetchLimit ? events : fetchLimit)
    }

    private func scheduleOperations(fetchLimit: Int) {
        semaphore.wait()
        guard !state.isDelivering else {
            Logger.common(message: "[GD] Delivering. Ignore another schedule operation.", level: .info, category: .delivery)
            isScheduleRequestedWhileDelivering = true
            semaphore.signal()
            return
        }

        state = .delivering
        isScheduleRequestedWhileDelivering = false
        semaphore.signal()
        deliverEvents(fetchLimit: fetchLimit)
    }

    private func deliverEvents(fetchLimit: Int) {
        guard let events = try? databaseRepository.query(fetchLimit: fetchLimit, retryDeadline: retryDelayManager.current) else {
            Logger.common(message: "[GD] Database Repository query events is nil", level: .info, category: .delivery)
            state = .idle
            return
        }
        guard !events.isEmpty else {
            forgetEventsMissingFromDatabase()
            semaphore.wait()
            let isScheduleRequested = isScheduleRequestedWhileDelivering
            isScheduleRequestedWhileDelivering = false
            let retryDelay = isScheduleRequested ? nil : retryDelayManager.completeRound()
            if !isScheduleRequested {
                state = .waitingForRetry
            }
            semaphore.signal()
            guard let retryDelay else {
                deliverEvents(fetchLimit: self.fetchLimit)
                return
            }
            Logger.common(message: "[GD] Schedule next call of performScheduleIfNeeded after TimeInterval: \(retryDelay)", level: .info, category: .delivery)
            backgroundTaskManager.endBackgroundTask(success: false)
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + retryDelay, execute: performScheduleIfNeeded)
            return
        }
        
        let completion = BlockOperation()
        completion.completionBlock = { [weak self, weak completion] in
            guard let self = self, let completion = completion else { return }
            
            self.state = .idle
            
            guard !completion.isCancelled else {
                Logger.common(message: "[GD] Queue was cancelled", level: .info, category: .background)
                return
            }
            
            Logger.common(message: "[GD] Completion of GuaranteedDelivery queue with events count \(events.count)", level: .info, category: .background)
            self.performScheduleIfNeeded()
        }
        let delivery = events.map {
            DeliveryOperation(
                databaseRepository: databaseRepository,
                eventRepository: eventRepository,
                event: $0,
                pauseManager: pauseManager,
                retryDelayManager: retryDelayManager
            )
        }
        Logger.common(message: "[GD] Enqueued events count: \(delivery.count)", level: .info, category: .delivery)
        delivery.forEach {
            completion.addDependency($0)
            $0.onCompleted = onCompletedEvent
        }
        let operations = delivery + [completion]
        queue.addOperations(operations, waitUntilFinished: false)
    }

    private func forgetEventsMissingFromDatabase() {
        let trackedTransactionIds = retryDelayManager.trackedTransactionIds
        guard !trackedTransactionIds.isEmpty,
              let storedTransactionIds = try? databaseRepository.storedTransactionIds(among: trackedTransactionIds) else {
            return
        }
        retryDelayManager.forget(transactionIds: trackedTransactionIds.subtracting(storedTransactionIds))
    }

    func cancelAllOperations() {
        queue.cancelAllOperations()
        eventRepository.cancelAllRequests()
    }

    func resetDeliveryPausesAndRetryDelay() {
        pauseManager.reset()
        retryDelayManager.reset()
    }
}

class AsyncOperation: Operation, @unchecked Sendable {
    private let lockQueue = DispatchQueue(label: "com.mindbox.asyncoperation", attributes: .concurrent)

    override var isAsynchronous: Bool {
        return true
    }

    private var _isExecuting: Bool = false
    override private(set) var isExecuting: Bool {
        get {
            return lockQueue.sync { () -> Bool in
                return _isExecuting
            }
        }
        set {
            if #available(iOS 13.0, *) {
                willChangeValue(for: \.isExecuting)
                lockQueue.sync(flags: [.barrier]) {
                    _isExecuting = newValue
                }
                didChangeValue(for: \.isExecuting)
            } else {
                willChangeValue(forKey: "isExecuting")
                lockQueue.sync(flags: [.barrier]) {
                    _isExecuting = newValue
                }
                didChangeValue(forKey: "isExecuting")
            }
        }
    }

    private var _isFinished: Bool = false
    override private(set) var isFinished: Bool {
        get {
            return lockQueue.sync { () -> Bool in
                return _isFinished
            }
        }
        set {
            if #available(iOS 13.0, *) {
                willChangeValue(for: \.isFinished)
                lockQueue.sync(flags: [.barrier]) {
                    _isFinished = newValue
                }
                didChangeValue(for: \.isFinished)
            } else {
                willChangeValue(forKey: "isFinished")
                lockQueue.sync(flags: [.barrier]) {
                    _isFinished = newValue
                }
                didChangeValue(forKey: "isFinished")
            }
        }
    }

    override func start() {
        guard !isCancelled else { return finish() }

        isFinished = false
        isExecuting = true
        main()
    }

    override func main() {
        fatalError("Subclasses must implement `main` without overriding super.")
    }

    func finish() {
        isExecuting = false
        isFinished = true
    }
}

extension GuaranteedDeliveryManager {

    func enqueueCheckNotificationsIfNeeded() {
        semaphore.wait()
        defer { semaphore.signal() }

        guard !state.isDelivering else { return }

        let op = CheckNotificationsOperation(
            work: DI.injectOrFail(CheckNotifWork.self))
        op.completionBlock = { [weak self] in self?.performScheduleIfNeeded() }
        queue.addOperation(op)
    }
}
