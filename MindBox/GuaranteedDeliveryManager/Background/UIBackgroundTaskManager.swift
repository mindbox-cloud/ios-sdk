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
                    .inChanel(.background).withType(.info).make()
            } else {
                Log("Did become invalid BackgroundTaskID")
                    .inChanel(.background).withType(.info).make()
            }
        }
    }
    
    private var removingDeprecatedEventsInProgress = false
    
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
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(
            withName: UUID().uuidString,
            expirationHandler: { [weak self] in
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
    
    private typealias CompletionHandler = (UIBackgroundFetchResult) -> Void
    
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        guard let gdManager = gdManager else {
            completionHandler(.noData)
            return
        }
        let taskID = UUID().uuidString
        let backgroudExecution = BackgroudExecution(
            taskID: taskID,
            taskName: "performFetchWithCompletionHandler",
            dateString: Date().fullToString(),
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
            .inChanel(.background).withType(.info).make()
        let backgroudExecution = BackgroudExecution(
            taskID: taskID,
            taskName: "performFetchWithCompletionHandler",
            dateString: Date().fullToString(),
            info: "GuaranteedDeliveryManager.State.idle\ncompletionHandler(.noData)"
        )
        persistenceStorage.setBackgroundExecution(backgroudExecution)
        completionHandler(.noData)
    }
    
    private func delivering(taskID: String, completionHandler: @escaping CompletionHandler) {
        observationToken = gdManager?.observe(\.stateObserver, options: [.new]) { [weak self] (observed, change) in
            Log("change.newValue \(String(describing: change.newValue))")
                .inChanel(.background).withType(.info).make()
            let idleString = NSString(string: GuaranteedDeliveryManager.State.idle.rawValue)
            if change.newValue == idleString {
                Log("completionHandler(.newData): delivering")
                    .inChanel(.background).withType(.info).make()
                let backgroudExecution = BackgroudExecution(
                    taskID: taskID,
                    taskName: "performFetchWithCompletionHandler",
                    dateString: Date().fullToString(),
                    info: "Called after loop over GuaranteedDeliveryManager.State.delivering -> GuaranteedDeliveryManager.State.idle\ncompletionHandler(.newData)"
                )
                self?.persistenceStorage.setBackgroundExecution(backgroudExecution)
                completionHandler(.newData)
            }
        }
    }
    
    private func waitingForRetry(taskID: String, completionHandler: @escaping CompletionHandler) {
        Log("completionHandler(.newData): waitingForRetry")
            .inChanel(.background).withType(.info).make()
        let backgroudExecution = BackgroudExecution(
            taskID: taskID,
            taskName: "performFetchWithCompletionHandler",
            dateString: Date().fullToString(),
            info: "GuaranteedDeliveryManager.State.waitingForRetry\ncompletionHandler(.newData)"
        )
        persistenceStorage.setBackgroundExecution(backgroudExecution)
        completionHandler(.newData)
    }
    
}
