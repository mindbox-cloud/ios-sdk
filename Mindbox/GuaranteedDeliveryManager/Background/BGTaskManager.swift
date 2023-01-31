//
//  BGTaskManger.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 15.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import UIKit
import BackgroundTasks


@available(iOS 13.0, *)
class BGTaskManager: BackgroundTaskManagerType {
    
    weak var gdManager: GuaranteedDeliveryManager?

    private var appGDRefreshIdentifier: String?
    private var appGDProcessingIdentifier: String?
    private var appDBCleanProcessingIdentifire: String?

    private var appGDRefreshTask: BGAppRefreshTask?
    private var appGDProcessingTask: BGProcessingTask?

    private let persistenceStorage: PersistenceStorage
    private let databaseRepository: MBDatabaseRepository
    
    init(persistenceStorage: PersistenceStorage, databaseRepository: MBDatabaseRepository) {
        self.persistenceStorage = persistenceStorage
        self.databaseRepository = databaseRepository
    }
    
    func registerBGTasks(
        appGDRefreshIdentifier: String,
        appGDProcessingIdentifier: String,
        appDBCleanProcessingIdentifire: String
    ) {
        self.appGDRefreshIdentifier = appGDRefreshIdentifier
        self.appGDProcessingIdentifier = appGDProcessingIdentifier
        self.appDBCleanProcessingIdentifire = appDBCleanProcessingIdentifire
        
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
        guard appGDRefreshTask != nil, appGDProcessingTask != nil else {
            return
        }
        
        Logger.common(message: "Did call EndBackgroundTask", level: .info, category: .background)
        appGDRefreshTask?.setTaskCompleted(success: success)
        appGDProcessingTask?.setTaskCompleted(success: success)
    }
    
    func applicationDidEnterBackground() {
        scheduleAppGDRefreshTask()
        scheduleAppGDProcessingTask()
        scheduleAppDBCleanProcessingTaskIfNeeded()
    }
    
    func applicationDidBecomeActive() {
        appGDRefreshTask?.setTaskCompleted(success: false)
        appGDProcessingTask?.setTaskCompleted(success: false)
    }
    
    // MARK: - Shedulers
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
            #else
            Logger.common(message: "Could not schedule app refresh task with error: \(error.localizedDescription)", level: .fault, category: .background)
            #endif
        }
    }
    
    private func scheduleAppGDProcessingTask() {
        guard let identifier = appGDProcessingIdentifier else {
            Logger.common(message: "appGDProcessingIdentifier is nil", level: .error, category: .background)
            return
        }
        let request = BGProcessingTaskRequest(identifier: identifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        do {
            try BGTaskScheduler.shared.submit(request)
            Logger.common(message: "Scheduled SendEventsBGProcessingTaskRequest", level: .info, category: .background)
        } catch {
            #if targetEnvironment(simulator)
            Logger.common(message: "Could not schedule app processing task for simulator", level: .info, category: .background)
            #else
            Logger.common(message: "Could not schedule app processing task with error: \(error.localizedDescription)", level: .fault, category: .background)
            #endif
        }
    }
    
    private func scheduleAppDBCleanProcessingTaskIfNeeded() {
        guard let identifier = appDBCleanProcessingIdentifire else {
            Logger.common(message: "appDBCleanProcessingIdentifire is nil", level: .error, category: .background)
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
            #else
            Logger.common(message: "Could not schedule app processing task with error: \(error.localizedDescription)", level: .info, category: .background)
            #endif
            
        }
    }
    
    // MARK: - Handlers
    private func appGDRefreshHandler(task: BGTask) {
        Logger.common(message: "Invoked appGDRefreshHandler", level: .info, category: .background)
        guard let task = task as? BGAppRefreshTask else {
            return
        }
        self.appGDRefreshTask = task
        let backgroudExecution = BackgroudExecution(
            taskID: appGDRefreshIdentifier ?? "appGDRefreshIdentifier nil",
            taskName: appGDRefreshTask.debugDescription,
            dateString: Date().toFullString(),
            info: "System call"
        )
        persistenceStorage.setBackgroundExecution(backgroudExecution)
        scheduleAppGDRefreshTask()
        task.expirationHandler = { [weak self] in
            guard let self = self else { return }
            Logger.common(message: "System calls expirationHandler for BGAppRefreshTask: \(task.debugDescription)", level: .info, category: .background)
            let backgroudExecution = BackgroudExecution(
                taskID: self.appGDRefreshIdentifier ?? "appGDRefreshIdentifier nil",
                taskName: self.appGDRefreshTask.debugDescription,
                dateString: Date().toFullString(),
                info: "System calls expirationHandler for BGAppRefreshTask: \(task.debugDescription)"
            )
            self.persistenceStorage.setBackgroundExecution(backgroudExecution)
            if self.appGDRefreshTask != nil {
                self.appGDRefreshTask?.setTaskCompleted(success: false)
                self.appGDRefreshTask = nil
            }
        }
        Mindbox.shared.coreController?.checkNotificationStatus()
        Logger.common(message: "GDAppRefresh task started", level: .info, category: .background)
    }
    
    private func appGDProcessingHandler(task: BGTask) {
        Logger.common(message: "Invoked appGDAppProcessingHandler", level: .info, category: .background)
        guard let task = task as? BGProcessingTask else {
            return
        }
        self.appGDProcessingTask = task
        let backgroudExecution = BackgroudExecution(
            taskID: appGDProcessingIdentifier ?? "appGDProcessingIdentifier nil",
            taskName: appGDProcessingIdentifier.debugDescription,
            dateString: Date().toFullString(),
            info: "System call"
        )
        persistenceStorage.setBackgroundExecution(backgroudExecution)
        task.expirationHandler = { [weak self] in
            guard let self = self else { return }
            Logger.common(message: "System calls expirationHandler for BGProcessingTask: \(task.debugDescription)", level: .info, category: .background)
            let backgroudExecution = BackgroudExecution(
                taskID: self.appGDProcessingIdentifier ?? "appGDRefreshIdentifier nil",
                taskName: self.appGDProcessingIdentifier.debugDescription,
                dateString: Date().toFullString(),
                info: "System calls expirationHandler for BGProcessingTask: \(task.debugDescription)"
            )
            self.persistenceStorage.setBackgroundExecution(backgroudExecution)
            if self.appGDProcessingTask != nil {
                self.appGDProcessingTask?.setTaskCompleted(success: false)
                self.appGDProcessingTask = nil
            }
        }
        Mindbox.shared.coreController?.checkNotificationStatus()
        Logger.common(message: "GDAppProcessing task started", level: .info, category: .background)
    }
    
    private func appDBCleanProcessingHandler(task: BGTask) {
        Logger.common(message: "Invoked removeDeprecatedEventsProcessing", level: .info, category: .background)
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
