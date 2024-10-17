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

    var onCompletedEvent: ((_ event: Event, _ error: MindboxError?) -> Void)?

    @objc dynamic var stateObserver: NSString

    private(set) var state: State = .idle {
        didSet {
            stateObserver = NSString(string: state.rawValue)
            Logger.common(message: "State didSet to value: \(state.description)", level: .info, category: .delivery)
        }
    }

    var canScheduleOperations = false {
        didSet {
            Logger.common(message: "canScheduleOperation didSet to value: \(canScheduleOperations)", level: .info, category: .delivery)
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
            queue: nil) { [weak self] _ in
            self?.performScheduleIfNeeded()
        }
    }

    private let retryDeadline: TimeInterval

    func performScheduleIfNeeded() {
        guard canScheduleOperations else {
            return
        }
        guard let events = try? databaseRepository.countEvents() else {
            return
        }
        guard events != 0 else {
            backgroundTaskManager.endBackgroundTask(success: true)
            return
        }
        scheduleOperations(fetchLimit: events <= fetchLimit ? events : fetchLimit)
    }

    private func scheduleOperations(fetchLimit: Int) {
        semaphore.wait()
        guard !state.isDelivering else {
            Logger.common(message: "Delivering. Ignore another schedule operation.", level: .info, category: .delivery)
            semaphore.signal()
            return
        }
        Logger.common(message: "Start enqueueing events", level: .info, category: .delivery)
        state = .delivering
        semaphore.signal()
        guard let events = try? databaseRepository.query(fetchLimit: fetchLimit, retryDeadline: retryDeadline) else {
            Logger.common(message: "Database Repository query events is nil", level: .info, category: .delivery)
            state = .idle
            return
        }
        guard !events.isEmpty else {
            state = .waitingForRetry
            Logger.common(message: "Schedule next call of performScheduleIfNeeded after TimeInterval: \(retryDeadline)", level: .info, category: .delivery)
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + retryDeadline, execute: performScheduleIfNeeded)
            return
        }
        let completion = BlockOperation()
        completion.completionBlock = { [weak self] in
            Logger.common(message: "Completion of GuaranteedDelivery queue with events count \(events.count)", level: .info, category: .background)
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
        Logger.common(message: "Enqueued events count: \(delivery.count)", level: .info, category: .delivery)
        delivery.forEach {
            completion.addDependency($0)
            $0.onCompleted = onCompletedEvent // TODO: - remove
        }
        let operations = delivery + [completion]
        queue.addOperations(operations, waitUntilFinished: false)
    }

    /// Cancels all queued and executing operations
    func cancelAllOperations() {
        queue.cancelAllOperations()
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
