//
//  UIBackgroundTaskManager.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 15.02.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation
import UIKit
import MindboxLogger

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
                Logger.common(message: "Did begin BackgroundTaskID: \(backgroundTaskID)", level: .info, category: .background)
            } else {
                Logger.common(message: "Did become invalid BackgroundTaskID", level: .info, category: .background)
            }
        }
    }

    private var removingDeprecatedEventsInProgress = false

    func applicationDidEnterBackground() {
        if #unavailable(iOS 13.0) {
            beginBackgroundTask()
        }
    }

    func applicationDidBecomeActive() {
        endBackgroundTask(success: false)
    }

    private func beginBackgroundTask() {
        guard backgroundTaskID == .invalid else {
            Logger.common(message: "BackgroundTask already in progress. Skip call of beginBackgroundTask", level: .info, category: .background)
            return
        }
        Logger.common(message: "Beginnig BackgroundTask", level: .info, category: .background)
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(
            withName: UUID().uuidString,
            expirationHandler: { [weak self] in
                guard let self = self else { return }
                Logger.common(message: "System calls expirationHandler for BackgroundTaskID: \(self.backgroundTaskID)", level: .info, category: .background)
                self.removingDeprecatedEventsInProgress = false
                self.endBackgroundTask(success: true)
                Logger.common(message: "BackgroundTimeRemaining after system calls expirationHandler: \(UIApplication.shared.backgroundTimeRemaining)", level: .info, category: .background)
            })
        Logger.common(message: "BackgroundTimeRemaining: \(UIApplication.shared.backgroundTimeRemaining)", level: .info, category: .background)

        removeDeprecatedEventsIfNeeded()
    }

    private func removeDeprecatedEventsIfNeeded() {
        let deprecatedEventsRemoveDate = persistenceStorage.deprecatedEventsRemoveDate ?? .distantPast
        guard !removingDeprecatedEventsInProgress,
              Date() > deprecatedEventsRemoveDate + Constants.Background.removeDeprecatedEventsInterval,
              let count = try? databaseRepository.countDeprecatedEvents(),
              count > databaseRepository.deprecatedLimit
        else {
            endBackgroundTask(success: true)
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
        Logger.common(message: "removeDeprecatedEventsProcessing task started", level: .info, category: .background)
    }

    func endBackgroundTask(success: Bool) {
        guard backgroundTaskID != .invalid else { return }
        guard !removingDeprecatedEventsInProgress else { return }
        Logger.common(message: "Ending BackgroundTaskID \(backgroundTaskID)", level: .info, category: .background)
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
        Logger.common(message: "completionHandler(.noData): idle. taskID \(taskID)", level: .info, category: .background)
        completionHandler(.noData)
    }

    private func delivering(taskID: String, completionHandler: @escaping CompletionHandler) {
        observationToken = gdManager?.observe(\.stateObserver, options: [.new]) { [weak self] _, change in
            Logger.common(message: "change.newValue \(String(describing: change.newValue))", level: .info, category: .background)
            let idleString = NSString(string: GuaranteedDeliveryManager.State.idle.rawValue)
            if change.newValue == idleString {
                Logger.common(message: "completionHandler(.newData): delivering. taskID \(taskID)", level: .info, category: .background)
                
                self?.observationToken?.invalidate()
                self?.observationToken = nil
                completionHandler(.newData)
            }
        }
    }

    private func waitingForRetry(taskID: String, completionHandler: @escaping CompletionHandler) {
        Logger.common(message: "completionHandler(.newData): waitingForRetry. taskID \(taskID)", level: .info, category: .background)
        completionHandler(.newData)
    }
}
