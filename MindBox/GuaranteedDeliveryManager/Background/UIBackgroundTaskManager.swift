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
    
    @Injected private var databaseRepository: MBDatabaseRepository
    @Injected private var persistenceStorage: PersistenceStorage
    weak var gdManager: GuaranteedDeliveryManager?
    
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
        removeDeprecatedEventsIfNeeded()
    }
    
    private func removeDeprecatedEventsIfNeeded() {
        guard !removingDeprecatedEventsInProgress else {
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
    
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        guard let gdManager = gdManager else {
            completionHandler(.noData)
            return
        }
        
        switch gdManager.state {
        case .idle:
            Log("completionHandler(.noData): idle")
                .inChanel(.background).withType(.info).make()
            completionHandler(.noData)
        case .delivering:
            observationToken = gdManager.observe(\.stateObserver, options: [.new]) { (observed, change) in
                Log("change.newValue \(String(describing: change.newValue))")
                    .inChanel(.background).withType(.info).make()
                let idleString = NSString(string: GuaranteedDeliveryManager.State.idle.rawValue)
                if change.newValue == idleString {
                    Log("completionHandler(.newData): delivering")
                        .inChanel(.background).withType(.info).make()
                    completionHandler(.newData)
                }
            }
        case .waitingForRetry:
            Log("completionHandler(.newData): waitingForRetry")
                .inChanel(.background).withType(.info).make()
            completionHandler(.newData)
        }
    }
    
}
