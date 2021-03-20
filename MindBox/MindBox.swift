//
//  MindBox.swift
//  MindBox
//
//  Created by Mikhail Barilov on 12.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import UIKit

public class MindBox {
    
    /// Singleton value for interaction with sdk
    /// It has setup DI container  as side effect  on init
    /// - Warning: All calls which use DI containers objects, mast go through `MindBox.shared`
    public static let shared = MindBox()
    
    // MARK: - Elements
    
    private var persistenceStorage: PersistenceStorage?
    private var utilitiesFetcher: UtilitiesFetcher?
    private var guaranteedDeliveryManager: GuaranteedDeliveryManager?
    private var notificationStatusProvider: UNAuthorizationStatusProviding?
    private var databaseRepository: MBDatabaseRepository?
    
    /// Internal process controller
    var coreController: CoreController?
    var container: DIContainer?

    /// Delegate for sending events
    weak var delegate: MindBoxDelegate? {
        didSet {
            guard let error = initError else { return }
            delegate?.mindBox(self, failedWithError: error)
        }
    }
        
    // MARK: - MindBox
    
    /// This function starting initialization case using `configuration`.
    /// - Parameter configuration: MBConfiguration struct with configuration
    public func initialization(configuration: MBConfiguration) {
        coreController?.initialization(configuration: configuration)
    }
    
    /// Method to get deviceUUID used for first initialization
    /// - Throws: MindBox.Errors.invalidAccess until first initialization did success
    public func deviceUUID() throws -> String {
        if let value = persistenceStorage?.deviceUUID {
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
        persistenceStorage?.apnsToken
    }
    
    /// - Returns: version from bundle
    public var sdkVersion: String {
        utilitiesFetcher?.sdkVersion ?? "unknown"
    }
    
    /// Method for keeping apnsTokenUpdate actuality
    public func apnsTokenUpdate(token: String) {
        if let persistenceAPNSToken = persistenceStorage?.apnsToken {
            guard persistenceAPNSToken != token else {
                return
            }
            coreController?.apnsTokenDidUpdate(token: token)
        } else {
            coreController?.apnsTokenDidUpdate(token: token)
        }
    }
    
    public func notificationsRequestAuthorization(granted: Bool) {
        coreController?.checkNotificationStatus(granted: granted)
    }
    
    @discardableResult
    public func pushDelivered(request: UNNotificationRequest) -> Bool {
        coreController?.checkNotificationStatus()
        guard let container = container else { return false }
        let traker = DeliveredNotificationManager(
            persistenceStorage: container.persistenceStorage,
            databaseRepository: container.databaseRepository,
            eventRepository: container.newInstanceDependency.makeEventRepository()
        )
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
        coreController?.checkNotificationStatus()
        guard let container = container else { return false }
        let traker = DeliveredNotificationManager(
            persistenceStorage: container.persistenceStorage,
            databaseRepository: container.databaseRepository,
            eventRepository: container.newInstanceDependency.makeEventRepository()
        )
        do {
            return try traker.track(uniqueKey: uniqueKey)
        } catch {
            Log("Track UNNotificationRequest failed with error: \(error)")
                .inChanel(.notification).withType(.error).make()
            return false
        }
    }
    
    // FixMe: - Change to click event later. Now its for GD testing
    public func pushClicked(uniqueKey: String) {
        let pushDelivered = PushDelivered(uniqKey: uniqueKey)
        let event = Event(type: .pushDelivered, body: BodyEncoder(encodable: pushDelivered).body)
        try? databaseRepository?.create(event: event)
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
        guaranteedDeliveryManager?.backgroundTaskManager.registerBGTasks(
            appGDRefreshIdentifier: appGDRefreshIdentifier,
            appGDProcessingIdentifier: appGDProcessingIdentifier,
            appDBCleanProcessingIdentifire: appDBCleanProcessingIdentifier
        )
    }
    
    public func application(
        _ application: UIApplication,
        performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guaranteedDeliveryManager?.backgroundTaskManager.application(application, performFetchWithCompletionHandler: completionHandler)
    }
    
    private var initError: Error?
    
    private init() {
        do {
            let container = try DIManager()
            self.container = container

            persistenceStorage = container.persistenceStorage
            utilitiesFetcher = container.utilitiesFetcher
            guaranteedDeliveryManager = container.guaranteedDeliveryManager
            notificationStatusProvider = container.authorizationStatusProvider
            databaseRepository = container.databaseRepository

            coreController = CoreController(
                persistenceStorage: container.persistenceStorage,
                utilitiesFetcher: container.utilitiesFetcher,
                notificationStatusProvider: container.authorizationStatusProvider,
                databaseRepository: container.databaseRepository,
                guaranteedDeliveryManager: container.guaranteedDeliveryManager
            )
        } catch {
            initError = error
        }
        persistenceStorage?.storeToFileBackgroundExecution()
    }
    
}
