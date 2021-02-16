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

    var appGDRefreshIdentifier: String?
    var appGDProcessingIdentifier: String?
    var appRemoveDeprecatedEventsProcessingIdentifier: String?

    private var appGDRefreshTask: BGAppRefreshTask?
    private var appGDProcessingTask: BGProcessingTask?

    @Injected private var databaseRepository: MBDatabaseRepository
    @Injected private var persistenceStorage: PersistenceStorage
    
    func registerBackgroundTasks(appRefreshIdentifier: String, appProcessingIdentifier: String) {
        self.appGDRefreshIdentifier = appRefreshIdentifier
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: appRefreshIdentifier,
            using: nil,
            launchHandler: appGDRefreshHandler
        )
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: appProcessingIdentifier,
            using: nil,
            launchHandler: appGDProcessingHandler
        )
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: appProcessingIdentifier,
            using: nil,
            launchHandler: removeDeprecatedEventsProcessingHandler
        )
    }
    
    func endBackgroundTask(success: Bool) {
        Log("Did end Background task with identifire:\(String(describing: appGDRefreshIdentifier)) ")
            .inChanel(.background).withType(.info).make()
        appGDRefreshTask?.setTaskCompleted(success: success)
        appGDProcessingTask?.setTaskCompleted(success: success)
    }
    
    func applicationDidEnterBackground() {
        scheduleGDAppRefreshTask()
        scheduleGDAppProcessingTask()
        scheduleRemoveDeprecatedEventsAppProcessingTaskIfNeeded()
    }
    
    func applicationDidBecomeActive() {
        appGDRefreshTask?.setTaskCompleted(success: false)
        appGDProcessingTask?.setTaskCompleted(success: false)
    }
    
    // MARK: - Shedulers
    private func scheduleGDAppRefreshTask() {
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
    
    private func scheduleGDAppProcessingTask() {
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
    
    private func scheduleRemoveDeprecatedEventsAppProcessingTaskIfNeeded() {
        guard let identifier = appRemoveDeprecatedEventsProcessingIdentifier else {
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
    
    // MARK: - Handlers
    private func appGDRefreshHandler(task: BGTask) {
        Log("Invoked appGDRefreshHandler")
            .inChanel(.background).withType(.info).make()
        guard let task = task as? BGAppRefreshTask else {
            return
        }
        self.appGDRefreshTask = task
        scheduleGDAppRefreshTask()
        task.expirationHandler = {
            Log("System calls expirationHandler for BGAppRefreshTask: \(task.debugDescription)")
                .inChanel(.background).withType(.warning).make()
            self.appGDRefreshTask = nil
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
        task.expirationHandler = {
            Log("System calls expirationHandler for BGProcessingTask: \(task.debugDescription)")
                .inChanel(.background).withType(.warning).make()
            self.appGDProcessingTask = nil
        }
        Log("GDAppProcessing task started")
            .inChanel(.background).withType(.info).make()
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
            Log("System calls expirationHandler for BGProcessingTask: \(task.debugDescription)")
                .inChanel(.background).withType(.warning).make()
            queue.cancelAllOperations()
        }
        queue.addOperation(operation)
        Log("removeDeprecatedEventsProcessing task started")
            .inChanel(.background).withType(.info).make()
    }
    
}
