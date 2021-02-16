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

    var appRefreshIdentifier: String?
    var appProcessingIdentifier: String?

    private var appRefreshTask: BGAppRefreshTask?
    
    @Injected
    private var databaseRepository: MBDatabaseRepository
    
    func registerBackgroundTasks(appRefreshIdentifier: String, appProcessingIdentifier: String) {
        self.appRefreshIdentifier = appRefreshIdentifier
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: appRefreshIdentifier,
            using: nil,
            launchHandler: appRefreshHandler
        )
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: appProcessingIdentifier,
            using: nil,
            launchHandler: removeDeprecatedEventsProcessingHandler
        )
        Log("Did register BGAppRefreshTask with identifier: \(appRefreshIdentifier)")
            .inChanel(.background).withType(.info).make()
    }
    
    func endBackgroundTask(success: Bool) {
        Log("Did end Background task with identifire:\(String(describing: appRefreshIdentifier)) ")
            .inChanel(.background).withType(.info).make()
        appRefreshTask?.setTaskCompleted(success: success)
    }
    
    func applicationDidEnterBackground() {
        scheduleAppRefreshTask()
        scheduleRemoveDeprecatedEventsAppProcessingTaskIfNeeded()
    }
    
    func applicationDidBecomeActive() {
        BGTaskScheduler.shared.cancelAllTaskRequests()
        appRefreshTask?.setTaskCompleted(success: false)
    }
    
    private func appRefreshHandler(task: BGTask) {
        Log("Invoked AppRefreshTaskHandler")
            .inChanel(.background).withType(.info).make()
        guard let task = task as? BGAppRefreshTask else {
            return
        }
        self.appRefreshTask = task
        scheduleAppRefreshTask()
        task.expirationHandler = {
            Log("System calls expirationHandler for BGAppRefreshTask: \(task.debugDescription)")
                .inChanel(.background).withType(.warning).make()
            self.appRefreshTask = nil
        }
        Log("AppRefresh task started")
            .inChanel(.background).withType(.info).make()
    }
    
    private func scheduleAppRefreshTask() {
        guard let identifier = appRefreshIdentifier else {
            return
        }
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 1 * 60) // Fetch no earlier than 1 minute from now
        do {
            try BGTaskScheduler.shared.submit(request)
            Log("Scheduled BGAppRefreshTaskRequest with beginDate: \(String(describing: request.earliestBeginDate))")
                .inChanel(.background).withType(.info).make()
        } catch {
            Log("Could not schedule app refresh task with error: \(error.localizedDescription)")
                .inChanel(.background).withType(.warning).make()
        }
    }
    
    private func scheduleRemoveDeprecatedEventsAppProcessingTaskIfNeeded() {
        guard let identifier = appProcessingIdentifier else {
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
        request.requiresExternalPower = true
        do {
            try BGTaskScheduler.shared.submit(request)
            Log("Scheduled BGProcessingTaskRequest")
                .inChanel(.background).withType(.info).make()
        } catch {
            Log("Could not schedule app processing task with error: \(error.localizedDescription)")
                .inChanel(.background).withType(.warning).make()
        }
    }
    
    private func removeDeprecatedEventsProcessingHandler(task: BGTask) {
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
        operation.completionBlock = {
            task.setTaskCompleted(success: !operation.isCancelled)
        }
        task.expirationHandler = {
            Log("System calls expirationHandler for BGAppRefreshTask: \(task.debugDescription)")
                .inChanel(.background).withType(.warning).make()
            queue.cancelAllOperations()
        }
        queue.addOperation(operation)
        Log("removeDeprecatedEventsProcessing task started")
            .inChanel(.background).withType(.info).make()
    }
    
}
