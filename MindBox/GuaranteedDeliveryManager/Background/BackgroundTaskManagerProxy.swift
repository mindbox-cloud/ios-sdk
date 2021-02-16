//
//  BackgroundTaskManager.swift
//  MindBox
//
//  Created by Maksim Kazachkov on 15.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import UIKit

class BackgroundTaskManagerProxy {
    
    static let shared = BackgroundTaskManagerProxy()
    
    private var taskManagers: [BackgroundTaskManagerType] = []
    
    private init() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: nil) { [weak self] (_) in
            Log("UIApplication.didEnterBackgroundNotification")
                .inChanel(.system).withType(.info).make()
            self?.taskManagers.forEach { $0.applicationDidEnterBackground() }
        }
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: nil) { [weak self] (_) in
            Log("UIApplication.didBecomeActiveNotification")
                .inChanel(.system).withType(.info).make()
            self?.taskManagers.forEach { $0.applicationDidBecomeActive() }
        }
        if #available(iOS 13, *) {
            taskManagers = [UIBackgroundTaskManager(), BGTaskManager()]
        } else {
            taskManagers = [UIBackgroundTaskManager()]
        }
    }
    
    func endBackgroundTask(success: Bool) {
        taskManagers.forEach { $0.endBackgroundTask(success: success) }
    }
    
    func registerTask(appRefreshIdentifier: String, appProcessingIdentifier: String) {
        taskManagers.forEach {
            $0.registerBackgroundTasks(
                appRefreshIdentifier: appRefreshIdentifier,
                appProcessingIdentifier: appProcessingIdentifier
            )
        }
    }
    
}
