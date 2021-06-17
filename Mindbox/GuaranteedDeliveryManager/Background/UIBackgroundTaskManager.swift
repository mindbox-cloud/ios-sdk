//
//  UIBackgroundTaskManager.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 15.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import UIKit

class UIBackgroundTaskManager: BackgroundTaskManagerType {
    
    weak var gdManager: GuaranteedDeliveryManager?
    
    private let persistenceStorage: PersistenceStorage
    private let databaseRepository: MBDatabaseRepository
    
    init(persistenceStorage: PersistenceStorage, databaseRepository: MBDatabaseRepository) {
        self.persistenceStorage = persistenceStorage
        self.databaseRepository = databaseRepository
    }
    
    private var observationToken: NSKeyValueObservation?
    
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid {
        didSet {
            if backgroundTaskID != .invalid {
                Log("Did begin BackgroundTaskID: \(backgroundTaskID)")
                    .category(.background).level(.info).make()
            } else {
                Log("Did become invalid BackgroundTaskID")
                    .category(.background).level(.info).make()
            }
        }
    }
    
    private var removingDeprecatedEventsInProgress = false
    
    func applicationDidEnterBackground() {
        guard backgroundTaskID == .invalid else {
            Log("BackgroundTask already in progress. Skip call of beginBackgroundTask")
                .category(.background).level(.info).make()
            return
        }
        Log("Beginnig BackgroundTask")
            .category(.background).level(.info).make()
        beginBackgroundTask()
    }
    
    func applicationDidBecomeActive() {
        endBackgroundTask(success: false)
    }
    
    private func beginBackgroundTask() {
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(
            withName: UUID().uuidString,
            expirationHandler: { [weak self] in
                guard let self = self else { return }
                Log("System calls expirationHandler for BackgroundTaskID: \(self.backgroundTaskID)")
                    .category(.background).level(.info).make()
                self.removingDeprecatedEventsInProgress = false
                self.endBackgroundTask(success: true)
                Log("BackgroundTimeRemaining after system calls expirationHandler: \(UIApplication.shared.backgroundTimeRemaining)")
                    .category(.background).level(.info).make()
            })
        Log("BackgroundTimeRemaining: \(UIApplication.shared.backgroundTimeRemaining)")
            .category(.background).level(.info).make()
        
        if #available(iOS 13.0, *) {
            // Do nothing cause BGProcessingTask will be called
        } else {
            removeDeprecatedEventsIfNeeded()
        }
    }
    
    private func removeDeprecatedEventsIfNeeded() {
        guard !removingDeprecatedEventsInProgress else {
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
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .background
        let operation = BlockOperation { [self] in
            try? databaseRepository.removeDeprecatedEventsIfNeeded()
        }
        operation.completionBlock = { [self] in
            persistenceStorage.deprecatedEventsRemoveDate = Date()
            removingDeprecatedEventsInProgress = false
            endBackgroundTask(success: true)
        }
        removingDeprecatedEventsInProgress = true
        queue.addOperation(operation)
        Log("removeDeprecatedEventsProcessing task started")
            .category(.background).level(.info).make()
    }
    
    func endBackgroundTask(success: Bool) {
        guard backgroundTaskID != .invalid else { return }
        guard !removingDeprecatedEventsInProgress else { return }
        Log("Ending BackgroundTaskID \(backgroundTaskID)")
            .category(.background).level(.info).make()
        UIApplication.shared.endBackgroundTask(self.backgroundTaskID)
        self.backgroundTaskID = .invalid
    }
    
    private typealias CompletionHandler = (UIBackgroundFetchResult) -> Void
    
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Mindbox.shared.coreController?.checkNotificationStatus()
        guard let gdManager = gdManager else {
            completionHandler(.noData)
            return
        }
        let taskID = UUID().uuidString
        let backgroudExecution = BackgroudExecution(
            taskID: taskID,
            taskName: "performFetchWithCompletionHandler",
            dateString: Date().toFullString(),
            info: "System call"
        )
        persistenceStorage.setBackgroundExecution(backgroudExecution)
        switch gdManager.state {
        case .idle:
            idle(taskID: taskID, completionHandler: completionHandler)
        case .delivering:
            delivering(taskID: taskID, completionHandler: completionHandler)
        case .waitingForRetry:
            waitingForRetry(taskID: taskID, completionHandler: completionHandler)
        }
    }
    
    private func idle(taskID: String, completionHandler: @escaping CompletionHandler) {
        Log("completionHandler(.noData): idle")
            .category(.background).level(.info).make()
        let backgroudExecution = BackgroudExecution(
            taskID: taskID,
            taskName: "performFetchWithCompletionHandler",
            dateString: Date().toFullString(),
            info: "GuaranteedDeliveryManager.State.idle\ncompletionHandler(.noData)"
        )
        persistenceStorage.setBackgroundExecution(backgroudExecution)
        completionHandler(.noData)
    }
    
    private func delivering(taskID: String, completionHandler: @escaping CompletionHandler) {
        observationToken = gdManager?.observe(\.stateObserver, options: [.new]) { [weak self] (observed, change) in
            Log("change.newValue \(String(describing: change.newValue))")
                .category(.background).level(.info).make()
            let idleString = NSString(string: GuaranteedDeliveryManager.State.idle.rawValue)
            if change.newValue == idleString {
                Log("completionHandler(.newData): delivering")
                    .category(.background).level(.info).make()
                let backgroudExecution = BackgroudExecution(
                    taskID: taskID,
                    taskName: "performFetchWithCompletionHandler",
                    dateString: Date().toFullString(),
                    info: "Called after loop over GuaranteedDeliveryManager.State.delivering -> GuaranteedDeliveryManager.State.idle\ncompletionHandler(.newData)"
                )
                self?.persistenceStorage.setBackgroundExecution(backgroudExecution)
                self?.observationToken?.invalidate()
                self?.observationToken = nil
                completionHandler(.newData)
            }
        }
    }
    
    private func waitingForRetry(taskID: String, completionHandler: @escaping CompletionHandler) {
        Log("completionHandler(.newData): waitingForRetry")
            .category(.background).level(.info).make()
        let backgroudExecution = BackgroudExecution(
            taskID: taskID,
            taskName: "performFetchWithCompletionHandler",
            dateString: Date().toFullString(),
            info: "GuaranteedDeliveryManager.State.waitingForRetry\ncompletionHandler(.newData)"
        )
        persistenceStorage.setBackgroundExecution(backgroudExecution)
        completionHandler(.newData)
    }
    
}
