//
//  MindBox.swift
//  MindBox
//
//  Created by Mikhail Barilov on 12.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import UIKit

let diManager = DIManager.shared

public class MindBox {
    
    /// Singleton value for interaction with sdk
    /// It has setup DI container  as side effect  on init
    /// - Warning: All calls which use DI containers objects, mast go through `MindBox.shared`
    public static var shared: MindBox = {
        DIManager.shared.registerServices()
        return MindBox()
    }()
    
    // MARK: - Elements
    
    @Injected private var persistenceStorage: PersistenceStorage
    @Injected private var utilitiesFetcher: UtilitiesFetcher
    @Injected private var gdManager: GuaranteedDeliveryManager
    @Injected private var notificationStatusProvider: UNAuthorizationStatusProviding
    @Injected private var databaseRepository: MBDatabaseRepository

    /// Internal process controller
    let coreController = CoreController()
        
    /// Delegate for sending events
    weak var delegate: MindBoxDelegate?
    
    // MARK: - Init
    
    private init() {
        persistenceStorage.storeToFileBackgroundExecution()
    }
    
    // MARK: - MindBox
    
    /// This function starting initialization case using `configuration`.
    /// - Parameter configuration: MBConfiguration struct with configuration
    public func initialization(configuration: MBConfiguration) {
        coreController.initialization(configuration: configuration)
    }
    
    /// Method to get deviceUUID used for first initialization
    /// - Throws: MindBox.Errors.invalidAccess until first initialization did success
    public func deviceUUID() throws -> String {
        if let value = persistenceStorage.deviceUUID {
            return value
        } else {
            throw MindBox.Errors.invalidAccess(
                reason: "deviceUUID unavailable until first initialization did success",
                suggestion: "Try later"
            )
        }
    }
    
    /// - Returns: apnsToken sent to the analytics system
    public var apnsToken: String? {
        persistenceStorage.apnsToken
    }
    
    /// - Returns: version from bundle
    public var sdkVersion: String {
        utilitiesFetcher.sdkVersion ?? "unknown"
    }
    
    /// Method for keeping apnsTokenUpdate actuality
    public func apnsTokenUpdate(token: String) {
        coreController.apnsTokenDidUpdate(token: token)
    }
    
    @discardableResult
    public func pushDelivered(request: UNNotificationRequest) -> Bool {
        coreController.checkNotificationStatus()
        let traker = DeliveredNotificationManager()
        do {
            return try traker.track(request: request)
        } catch {
            Log("Track UNNotificationRequest failed with error: \(error)")
                .inChanel(.notification).withType(.error).make()
            return false
        }
    }
    
    @discardableResult
    public func pushDelivered(uniqueKey: String) -> Bool {
        coreController.checkNotificationStatus()
        let traker = DeliveredNotificationManager()
        do {
            return try traker.track(uniqueKey: uniqueKey)
        } catch {
            Log("Track UNNotificationRequest failed with error: \(error)")
                .inChanel(.notification).withType(.error).make()
            return false
        }
    }

    @available(iOS 13.0, *)
    public func registerBGTasks() {
        guard let identifiers = Bundle.main.object(forInfoDictionaryKey: "BGTaskSchedulerPermittedIdentifiers") as? [String] else {
            return
        }
        guard let appGDRefreshIdentifier = identifiers.first(where: { $0.contains("GDAppRefresh") }) else  {
            return
        }
        guard let appGDProcessingIdentifier = identifiers.first(where: { $0.contains("GDAppProcessing") }) else  {
            return
        }
        guard let appDBCleanProcessingIdentifier = identifiers.first(where: { $0.contains("DBCleanAppProcessing") }) else  {
            return
        }
        gdManager.backgroundTaskManager.registerBGTasks(
            appGDRefreshIdentifier: appGDRefreshIdentifier,
            appGDProcessingIdentifier: appGDProcessingIdentifier,
            appDBCleanProcessingIdentifire: appDBCleanProcessingIdentifier
        )
    }
    
    public func application(
        _ application: UIApplication,
        performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        gdManager.backgroundTaskManager.application(application, performFetchWithCompletionHandler: completionHandler)
    }
    
}
