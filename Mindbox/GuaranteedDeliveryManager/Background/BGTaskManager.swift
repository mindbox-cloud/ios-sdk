//
//  BGTaskManger.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 15.02.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation
import UIKit
import BackgroundTasks
import MindboxLogger

@available(iOS 13.0, *)
final class BGTaskManager: BackgroundTaskManagerType {

    weak var gdManager: GuaranteedDeliveryManager?

    private var appGDRefreshIdentifier: String?
    private var appGDProcessingIdentifier: String?
    private var appDBCleanProcessingIdentifier: String?

    private var appGDRefreshTask: BGAppRefreshTask?
    private var appGDProcessingTask: BGProcessingTask?
    private var backgroundGate: BackgroundDeliveryGate?

    private let persistenceStorage: PersistenceStorage
    private let databaseRepository: DatabaseRepositoryProtocol
    
    // MARK: BGTasks synchronizer
    
    private var bgTaskRunning = false
    private let lock = NSLock()
    
    @discardableResult
    private func beginBGSession() -> Bool {
        lock.withLock {
            guard !bgTaskRunning else { return false }
            bgTaskRunning = true
            return true
        }
    }
    
    private func clearBGSessionFlag() {
        lock.withLock {
            bgTaskRunning = false
        }
    }
    
    // MARK: Initializer

    init(persistenceStorage: PersistenceStorage, databaseRepository: DatabaseRepositoryProtocol) {
        self.persistenceStorage = persistenceStorage
        self.databaseRepository = databaseRepository
    }
    
    // MARK: BackgroundTaskManagerType

    func registerBGTasks(
        appGDRefreshIdentifier: String,
        appGDProcessingIdentifier: String,
        appDBCleanProcessingIdentifire: String
    ) {
        self.appGDRefreshIdentifier = appGDRefreshIdentifier
        self.appGDProcessingIdentifier = appGDProcessingIdentifier
        self.appDBCleanProcessingIdentifier = appDBCleanProcessingIdentifire

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: appGDRefreshIdentifier,
            using: nil,
            launchHandler: appGDRefreshHandler
        )
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: appGDProcessingIdentifier,
            using: nil,
            launchHandler: appGDProcessingHandler
        )
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: appDBCleanProcessingIdentifire,
            using: nil,
            launchHandler: appDBCleanProcessingHandler
        )
    }

    func endBackgroundTask(success: Bool) {
        if let gate = currentGate {
            gate.eventsFinished(success: success)
            return
        }

        clearBGSessionFlag()
        
        var refresh: BGAppRefreshTask?
        var processing: BGProcessingTask?
        lock.withLock {
            refresh = appGDRefreshTask
            processing = appGDProcessingTask
            appGDRefreshTask = nil
            appGDProcessingTask = nil
        }
        
        if let task = refresh {
            task.setTaskCompleted(success: success)
        }
        
        if let task = processing {
            task.setTaskCompleted(success: success)
        }
    }

    func applicationDidEnterBackground() {
        scheduleAppGDRefreshTask()
        scheduleAppGDProcessingTask()
        scheduleAppDBCleanProcessingTaskIfNeeded()
    }

    func applicationDidBecomeActive() {
        if let gate = currentGate {
            gate.finishNow(success: false)
            return
        }
        self.endBackgroundTask(success: false)
    }
}

// MARK: - Delivery confirmations

@available(iOS 13.0, *)
extension BGTaskManager {

    private var confirmationQueue: PushDeliveryConfirmationQueue? {
        DI.inject(PushDeliveryConfirmationQueue.self)
    }

    private var currentGate: BackgroundDeliveryGate? {
        lock.withLock { backgroundGate }
    }

    private func makeBackgroundGate() -> BackgroundDeliveryGate {
        BackgroundDeliveryGate { [weak self] success in
            self?.finishBackgroundSession(success: success)
        }
    }

    private func finishBackgroundSession(success: Bool) {
        let tasks: (refresh: BGAppRefreshTask?, processing: BGProcessingTask?) = lock.withLock {
            defer {
                appGDRefreshTask = nil
                appGDProcessingTask = nil
                backgroundGate = nil
            }
            return (appGDRefreshTask, appGDProcessingTask)
        }

        clearBGSessionFlag()

        tasks.refresh?.setTaskCompleted(success: success)
        tasks.processing?.setTaskCompleted(success: success)
    }

    private func startBackgroundDelivery(gate: BackgroundDeliveryGate, queue: PushDeliveryConfirmationQueue?) {
        if let queue {
            queue.wake { gate.confirmationsFinished() }
        } else {
            gate.confirmationsFinished()
        }
        gdManager?.enqueueCheckNotificationsIfNeeded()
    }
}

// MARK: - Schedulers

@available(iOS 13.0, *)
extension BGTaskManager {
    
    private func scheduleAppGDRefreshTask() {
        guard let identifier = appGDRefreshIdentifier else {
            Logger.common(message: "appGDRefreshIdentifier is nil", level: .error, category: .background)
            return
        }
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: Constants.Background.refreshTaskInterval)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            Logger.common(message: "Scheduled BGAppRefreshTaskRequest with beginDate: \(String(describing: request.earliestBeginDate))", level: .info, category: .background)
        } catch {
            #if targetEnvironment(simulator)
            Logger.common(message: "Could not schedule app refresh task for simulator", level: .info, category: .background)
            #endif
        }
    }

    private func scheduleAppGDProcessingTask() {
        guard let identifier = appGDProcessingIdentifier else {
            Logger.common(message: "appGDProcessingIdentifier is nil", level: .error, category: .background)
            return
        }
        
        let hasEvents = (try? databaseRepository.countEvents()).map { $0 > 0 } ?? false
        guard hasEvents || confirmationQueue?.hasRecords == true else { return }
        
        let request = BGProcessingTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: Constants.Background.processingTaskInterval)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        
        do {
            try BGTaskScheduler.shared.submit(request)
            Logger.common(message: "Scheduled SendEventsBGProcessingTaskRequest. Earliest date: \(String(describing: request.earliestBeginDate))", level: .info, category: .background)
        } catch {
            #if targetEnvironment(simulator)
            Logger.common(message: "Could not schedule app processing task for simulator", level: .info, category: .background)
            #endif
        }
    }

    private func scheduleAppDBCleanProcessingTaskIfNeeded() {
        guard let identifier = appDBCleanProcessingIdentifier else {
            Logger.common(message: "appDBCleanProcessingIdentifier is nil", level: .error, category: .background)
            return
        }
        let deprecatedEventsRemoveDate = persistenceStorage.deprecatedEventsRemoveDate ?? .distantPast
        guard Date() > deprecatedEventsRemoveDate + Constants.Background.removeDeprecatedEventsInterval else {
            return
        }
        guard let count = try? databaseRepository.countDeprecatedEvents() else {
            return
        }
        guard count > databaseRepository.deprecatedLimit else {
            return
        }
        let request = BGProcessingTaskRequest(identifier: identifier)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        do {
            try BGTaskScheduler.shared.submit(request)
            Logger.common(message: "Scheduled BGProcessingTaskRequest", level: .info, category: .background)
        } catch {
            #if targetEnvironment(simulator)
            Logger.common(message: "Could not schedule app processing task for simulator", level: .info, category: .background)
            #endif
        }
    }
}

// MARK: - Handlers

@available(iOS 13.0, *)
extension BGTaskManager {
    
    private func appGDRefreshHandler(task: BGTask) {
        guard let task = task as? BGAppRefreshTask else {
            return
        }
        
        scheduleAppGDRefreshTask()
        
        guard beginBGSession() else {
            task.setTaskCompleted(success: false)
            return
        }

        let gate = makeBackgroundGate()
        lock.withLock {
            self.appGDRefreshTask = task
            self.backgroundGate = gate
        }

        let queue = confirmationQueue
        task.expirationHandler = { [weak self] in
            self?.gdManager?.cancelAllOperations(restartsRequestedPass: false)
            queue?.suspendPass()
            gate.finishNow(success: false)
        }
        
        Logger.common(message: "\(task.debugDescription) started. BackgroundTimeRemaining: \(UIApplication.shared.backgroundTimeRemaining)", level: .info, category: .background)
        startBackgroundDelivery(gate: gate, queue: queue)
    }

    private func appGDProcessingHandler(task: BGTask) {
        guard let task = task as? BGProcessingTask else {
            return
        }
        guard beginBGSession() else {
            task.setTaskCompleted(success: false)
            return
        }
        
        let gate = makeBackgroundGate()
        lock.withLock {
            self.appGDProcessingTask = task
            self.backgroundGate = gate
        }

        let queue = confirmationQueue
        task.expirationHandler = { [weak self] in
            self?.gdManager?.cancelAllOperations(restartsRequestedPass: false)
            queue?.suspendPass()
            gate.finishNow(success: false)
        }

        Logger.common(message: "\(task.debugDescription) started. BackgroundTimeRemaining: \(UIApplication.shared.backgroundTimeRemaining)", level: .info, category: .background)
        startBackgroundDelivery(gate: gate, queue: queue)
    }

    private func appDBCleanProcessingHandler(task: BGTask) {
        Logger.common(message: "Invoked removeDeprecatedEventsProcessing. Task: \(task.debugDescription)", level: .info, category: .background)
        guard let task = task as? BGProcessingTask else {
            return
        }
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .background
        let operation = BlockOperation { [self] in
            try? databaseRepository.removeDeprecatedEventsIfNeeded()
        }
        operation.completionBlock = { [self] in
            persistenceStorage.deprecatedEventsRemoveDate = Date()
            task.setTaskCompleted(success: !operation.isCancelled)
        }
        task.expirationHandler = { [self] in
            Logger.common(message: "System calls expirationHandler for BGProcessingTask: \(task.debugDescription)", level: .info, category: .background)
            persistenceStorage.deprecatedEventsRemoveDate = Date()
            queue.cancelAllOperations()
        }
        queue.addOperation(operation)
        Mindbox.shared.coreController?.checkNotificationStatus()
        Logger.common(message: "removeDeprecatedEventsProcessing task started", level: .info, category: .background)
    }
}
