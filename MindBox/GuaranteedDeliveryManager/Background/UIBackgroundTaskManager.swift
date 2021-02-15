//
//  UIBackgroundTaskManager.swift
//  MindBox
//
//  Created by Maksim Kazachkov on 15.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import UIKit

class UIBackgroundTaskManager: BackgroundTaskManagerType {
    
    @Injected
    private var databaseRepository: MBDatabaseRepository
    
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid {
        didSet {
            if backgroundTaskID != .invalid {
                Log("Did begin BackgroundTaskID: \(backgroundTaskID)")
                    .inChanel(.background).withType(.info).make()
            } else {
                Log("Did become invalid BackgroundTaskID")
                    .inChanel(.background).withType(.info).make()
            }
        }
    }
    
    var removingDeprecatedEventsInProgress = false
    
    func applicationDidEnterBackground() {
        guard backgroundTaskID == .invalid else {
            Log("BackgroundTask already in progress. Skip call of beginBackgroundTask")
                .inChanel(.background).withType(.info).make()
            return
        }
        Log("Beginnig BackgroundTask")
            .inChanel(.background).withType(.info).make()
        beginBackgroundTask()
    }
    
    func applicationDidBecomeActive() {
        endBackgroundTask(success: false)
    }
    
    private func beginBackgroundTask() {
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: UUID().uuidString, expirationHandler: { [weak self] in
            guard let self = self else { return }
            Log("System calls expirationHandler for BackgroundTaskID: \(self.backgroundTaskID)")
                .inChanel(.background).withType(.warning).make()
            self.removingDeprecatedEventsInProgress = false
            self.endBackgroundTask(success: true)
            Log("BackgroundTimeRemaining after system calls expirationHandler: \(UIApplication.shared.backgroundTimeRemaining)")
                .inChanel(.background).withType(.info).make()
        })
        Log("BackgroundTimeRemaining: \(UIApplication.shared.backgroundTimeRemaining)")
            .inChanel(.background).withType(.info).make()
        removeDeprecatedEventsIfNeeded()
    }
    
    private func removeDeprecatedEventsIfNeeded() {
        guard removingDeprecatedEventsInProgress else {
            return
        }
        guard let count = try? databaseRepository.countDeprecatedEvents() else {
            return
        }
        guard count > databaseRepository.deprecatedLimit else {
            return
        }
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .background
        let operation = BlockOperation { [self] in
            try? databaseRepository.removeDeprecatedEventsIfNeeded()
        }
        operation.completionBlock = { [weak self] in
            self?.removingDeprecatedEventsInProgress = false
            self?.endBackgroundTask(success: true)
        }
        removingDeprecatedEventsInProgress = true
        queue.addOperation(operation)
        Log("removeDeprecatedEventsProcessing task started")
            .inChanel(.background).withType(.info).make()
    }
    
    func endBackgroundTask(success: Bool) {
        guard backgroundTaskID != .invalid else { return }
        guard !removingDeprecatedEventsInProgress else { return }
        Log("Ending BackgroundTaskID \(backgroundTaskID)")
            .inChanel(.background).withType(.info).make()
        UIApplication.shared.endBackgroundTask(self.backgroundTaskID)
        self.backgroundTaskID = .invalid
    }
    
    func registerBackgroundTasks(appRefreshIdentifier: String, appProcessingIdentifier: String) {
        
    }
    
}
