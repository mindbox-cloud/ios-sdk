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
    
    var bgAppRefreshTaskRequestIdentifier: String?

    private var bgAppRefreshTask: BGAppRefreshTask?
    
    init() {}
    
    func registerTask(with identifier: String) {
        self.bgAppRefreshTaskRequestIdentifier = identifier
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: identifier,
            using: nil,
            launchHandler: appRefreshTaskHandler
        )
        Log("Did register BGAppRefreshTask with identifier: \(identifier)")
            .inChanel(.background).withType(.info).make()
    }
    
    func endBackgroundTask(success: Bool) {
        Log("Did end Background task with identifire:\(String(describing: bgAppRefreshTaskRequestIdentifier)) ")
            .inChanel(.background).withType(.info).make()
//        bgAppRefreshTask?.setTaskCompleted(success: success)
//        BGTaskScheduler.shared.cancelAllTaskRequests()
    }
    
    func applicationDidEnterBackground() {
        scheduleBGBackgroundTask()
    }
    
    func applicationDidBecomeActive() {
        BGTaskScheduler.shared.cancelAllTaskRequests()
        bgAppRefreshTask?.setTaskCompleted(success: false)
    }
    
    private func appRefreshTaskHandler(task: BGTask) {
        Log("Called AppRefreshTaskHandler")
            .inChanel(.background).withType(.info).make()
        guard let task = task as? BGAppRefreshTask else {
            return
        }
        self.bgAppRefreshTask = task
        scheduleBGBackgroundTask()
        task.expirationHandler = {
            Log("System calls expirationHandler for BGAppRefreshTask: \(task.debugDescription)")
                .inChanel(.background).withType(.warning).make()
            self.bgAppRefreshTask = nil
        }
        Log("AppRefresh task started")
            .inChanel(.background).withType(.info).make()
    }
    
    private func scheduleBGBackgroundTask() {
        guard let identifier = bgAppRefreshTaskRequestIdentifier else {
            return
        }
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 0) // Fetch no earlier than 1 minute from now
        do {
            try BGTaskScheduler.shared.submit(request)
            Log("Scheduled BGAppRefreshTaskRequest with beginDate: \(String(describing: request.earliestBeginDate))")
                .inChanel(.background).withType(.info).make()
        } catch {
            Log("Could not schedule app refresh with error: \(error.localizedDescription)")
                .inChanel(.background).withType(.warning).make()
        }
    }
    
}
