//
//  BGTaskManger.swift
//  MindBox
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

    var appGDRefreshIdentifier: String?
    var appGDProcessingIdentifier: String?
    var appDBCleanProcessingIdentifire: String?

    private var appGDRefreshTask: BGAppRefreshTask?
    private var appGDProcessingTask: BGProcessingTask?

    @Injected private var databaseRepository: MBDatabaseRepository
    @Injected private var persistenceStorage: PersistenceStorage
    
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
        Log("Did call EndBackgroundTask")
            .inChanel(.background).withType(.info).make()
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
            return
        }
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 2 * 60) // Fetch no earlier than 2 minute from now
        do {
            try BGTaskScheduler.shared.submit(request)
            Log("Scheduled BGAppRefreshTaskRequest with beginDate: \(String(describing: request.earliestBeginDate))")
                .inChanel(.background).withType(.info).make()
        } catch {
            Log("Could not schedule app refresh task with error: \(error.localizedDescription)")
                .inChanel(.background).withType(.warning).make()
        }
    }
    
    private func scheduleAppGDProcessingTask() {
        guard let identifier = appGDProcessingIdentifier else {
            return
        }
        let request = BGProcessingTaskRequest(identifier: identifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        do {
            try BGTaskScheduler.shared.submit(request)
            Log("Scheduled SendEventsBGProcessingTaskRequest")
                .inChanel(.background).withType(.info).make()
        } catch {
            Log("Could not schedule app processing task with error: \(error.localizedDescription)")
                .inChanel(.background).withType(.warning).make()
        }
    }
    
    private func scheduleAppDBCleanProcessingTaskIfNeeded() {
        guard let identifier = appDBCleanProcessingIdentifire else {
            return
        }
        let deprecatedEventsRemoveDate = persistenceStorage.deprecatedEventsRemoveDate ?? .distantPast
        guard Date() > deprecatedEventsRemoveDate + TimeInterval(7 * 24 * 60 * 60) else {
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
            Log("Scheduled BGProcessingTaskRequest")
                .inChanel(.background).withType(.info).make()
        } catch {
            Log("Could not schedule app processing task with error: \(error.localizedDescription)")
                .inChanel(.background).withType(.warning).make()
        }
    }
    
    // MARK: - Handlers
    private func appGDRefreshHandler(task: BGTask) {
        Log("Invoked appGDRefreshHandler")
            .inChanel(.background).withType(.info).make()
        guard let task = task as? BGAppRefreshTask else {
            return
        }
        self.appGDRefreshTask = task
        let backgroudExecution = BackgroudExecution(
            taskID: appGDRefreshIdentifier ?? "appGDRefreshIdentifier nil",
            taskName: appGDRefreshTask.debugDescription,
            dateString: Date().fullToString(),
            info: "System call"
        )
        persistenceStorage.setBackgroundExecution(backgroudExecution)
        scheduleAppGDRefreshTask()
        task.expirationHandler = { [weak self] in
            guard let self = self else { return }
            Log("System calls expirationHandler for BGAppRefreshTask: \(task.debugDescription)")
                .inChanel(.background).withType(.warning).make()
            let backgroudExecution = BackgroudExecution(
                taskID: self.appGDRefreshIdentifier ?? "appGDRefreshIdentifier nil",
                taskName: self.appGDRefreshTask.debugDescription,
                dateString: Date().fullToString(),
                info: "System calls expirationHandler for BGAppRefreshTask: \(task.debugDescription)"
            )
            self.persistenceStorage.setBackgroundExecution(backgroudExecution)
            if self.appGDRefreshTask != nil {
                self.appGDRefreshTask?.setTaskCompleted(success: false)
                self.appGDRefreshTask = nil
            }
        }
        Log("GDAppRefresh task started")
            .inChanel(.background).withType(.info).make()
    }
    
    private func appGDProcessingHandler(task: BGTask) {
        Log("Invoked appGDAppProcessingHandler")
            .inChanel(.background).withType(.info).make()
        guard let task = task as? BGProcessingTask else {
            return
        }
        self.appGDProcessingTask = task
        let backgroudExecution = BackgroudExecution(
            taskID: appGDProcessingIdentifier ?? "appGDProcessingIdentifier nil",
            taskName: appGDProcessingIdentifier.debugDescription,
            dateString: Date().fullToString(),
            info: "System call"
        )
        persistenceStorage.setBackgroundExecution(backgroudExecution)
        task.expirationHandler = { [weak self] in
            guard let self = self else { return }
            Log("System calls expirationHandler for BGProcessingTask: \(task.debugDescription)")
                .inChanel(.background).withType(.warning).make()
            let backgroudExecution = BackgroudExecution(
                taskID: self.appGDProcessingIdentifier ?? "appGDRefreshIdentifier nil",
                taskName: self.appGDProcessingIdentifier.debugDescription,
                dateString: Date().fullToString(),
                info: "System calls expirationHandler for BGProcessingTask: \(task.debugDescription)"
            )
            self.persistenceStorage.setBackgroundExecution(backgroudExecution)
            if self.appGDProcessingTask != nil {
                self.appGDProcessingTask?.setTaskCompleted(success: false)
                self.appGDProcessingTask = nil
            }
        }
        Log("GDAppProcessing task started")
            .inChanel(.background).withType(.info).make()
    }
    
    private func appDBCleanProcessingHandler(task: BGTask) {
        Log("Invoked removeDeprecatedEventsProcessing")
            .inChanel(.background).withType(.info).make()
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
            Log("System calls expirationHandler for BGProcessingTask: \(task.debugDescription)")
                .inChanel(.background).withType(.warning).make()
            persistenceStorage.deprecatedEventsRemoveDate = Date()
            queue.cancelAllOperations()
        }
        queue.addOperation(operation)
        Log("removeDeprecatedEventsProcessing task started")
            .inChanel(.background).withType(.info).make()
    }

}
