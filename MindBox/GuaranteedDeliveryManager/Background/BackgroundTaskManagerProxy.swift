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
    
    private var taskManager: BackgroundTaskManagerType?
    
    private init() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: nil) { [weak self] (_) in
            Log("UIApplication.didEnterBackgroundNotification")
                .inChanel(.system).withType(.info).make()
            self?.taskManager?.applicationDidEnterBackground()
        }
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: nil) { [weak self] (_) in
            Log("UIApplication.didBecomeActiveNotification")
                .inChanel(.system).withType(.info).make()
            self?.taskManager?.applicationDidBecomeActive()
        }
        if #available(iOS 13, *) {
            taskManager = BGTaskManager()
        } else {
            taskManager = UIBackgroundTaskManager()
        }
    }
    
    func endBackgroundTask(success: Bool) {
        taskManager?.endBackgroundTask(success: success)
    }
    
    func registerTask(with identifier: String) {
        taskManager?.registerTask(with: identifier)
    }
    
}
