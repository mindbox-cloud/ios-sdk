//
//  Mindbox.swift
//  Mindbox
//
//  Created by Mikhail Barilov on 12.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import UIKit

public class Mindbox {
    /**
     Singleton for interaction with sdk.

     - Imporatant: All sdk calls should go through `Mindbox.shared` invocation
     */
    public static let shared = Mindbox()

    /**
     Singleton for iteraction with logger.

     - Important:
     Logs can be viewed via Console.app or Xcode output in runtime
     To filter SDK logs in Console.app use subsystem: cloud.Mindbox
        - In __DEBUG__ schema logs writes _sync_
        - In __RELEASE__ schema logs writes _async_ on queue with __qos: .utility__

     - Warninig:
      By default _logLevel_: __.none__
     */
    public static let logger = MBLogger()

    // MARK: - Dependencies

    private var persistenceStorage: PersistenceStorage?
    private var utilitiesFetcher: UtilitiesFetcher?
    private var guaranteedDeliveryManager: GuaranteedDeliveryManager?
    private var notificationStatusProvider: UNAuthorizationStatusProviding?
    private var databaseRepository: MBDatabaseRepository?

    private let queue = DispatchQueue(label: "com.Mindbox.initialization", attributes: .concurrent)

    var coreController: CoreController?
    var container: DependencyContainer?

    /**
     A set of methods that sdk uses to notify you of its behavior.
     */
    weak var delegate: MindboxDelegate? {
        didSet {
            guard let error = initError else { return }
            delegate?.mindBox(self, failedWithError: error)
        }
    }

    /**
     Method to instruct sdk of its initialization.

     - Parameters:
        - configuration: MBConfiguration struct with configuration
     */
    public func initialization(configuration: MBConfiguration) {
        coreController?.initialization(configuration: configuration)
    }

    private var observeTokens: [UUID] = []

    /**
     Method to obtain deviceUUID.

     - Returns:
     -  completion: @escaping closure of apnsToken string

     - Important:
     The block to execute asynchronously with the results

     */
    public func getDeviceUUID(_ completion: @escaping (String) -> Void) {
        if let value = persistenceStorage?.deviceUUID {
            completion(value)
        } else {
            observe(value: self.persistenceStorage?.deviceUUID, with: completion)
        }
    }

    /**
     Method to obtain apnsToken.

     - Returns:
     -  completion: @escaping closure of apnsToken string

     - Important:
     The block to execute asynchronously with the results

     */
    public func getAPNSToken(_ completion: @escaping (String) -> Void) {
        if let value = persistenceStorage?.apnsToken {
            completion(value)
        } else {
            observe(value: self.persistenceStorage?.apnsToken, with: completion)
        }

        let body = OperationBodyRequest()

        body.customAction = CustomerActionRequest(customFields: ["id1": 1234, "id2": "1234"])
    }

    private func observe(value: @escaping @autoclosure () -> String?, with completion: @escaping (String) -> Void) {
        let token = UUID()
        persistenceStorage?.onDidChange = { [weak self] in
            guard let value = value(), let index = self?.observeTokens.firstIndex(of: token) else {
                return
            }
            self?.observeTokens.remove(at: index)
            completion(value)
        }
        observeTokens.append(token)
    }

    /**
     Property to obtain current sdkVersion.

     - returns:
     Version from bundle

     - Important:
     If sdk can't initialize its dependencies, will return unknown

     */
    public var sdkVersion: String {
        utilitiesFetcher?.sdkVersion ?? "unknown"
    }

    /**
     Method for keeping apnsTokenUpdate actual.

     - Parameters:
        - deviceToken: A globally unique token that identifies this device to APNs
     */
    public func apnsTokenUpdate(deviceToken: Data) {
        let token = deviceToken
            .map { String(format: "%02.2hhx", $0) }
            .joined()
        Log("Did register for remote notifications with token: \(token)")
            .category(.notification).level(.info).make()
        if let persistenceAPNSToken = persistenceStorage?.apnsToken {
            guard persistenceAPNSToken != token else {
                return
            }
            coreController?.apnsTokenDidUpdate(token: token)
        } else {
            coreController?.apnsTokenDidUpdate(token: token)
        }
    }

    /// Use this method to notify Mindbox for notification request authorization changes.
    public func notificationsRequestAuthorization(granted: Bool) {
        coreController?.checkNotificationStatus(granted: granted)
    }

    /**
     Method of transmitting the fact of receiving a push on the device.

     - Returns:
     The bool as a result of success delivery within 5sec

     - Parameters:
        - request: The entire notification object of UNNotificationRequest class

     - Important:
     Blockes calling thread no more than by 5sec

     */
    @discardableResult
    public func pushDelivered(request: UNNotificationRequest) -> Bool {
        coreController?.checkNotificationStatus()
        guard let container = container else { return false }
        let tracker = DeliveredNotificationManager(
            persistenceStorage: container.persistenceStorage,
            databaseRepository: container.databaseRepository,
            eventRepository: container.instanceFactory.makeEventRepository()
        )
        do {
            Log("Track delivery")
                .category(.notification).level(.info).make()
            return try tracker.track(request: request)
        } catch {
            Log("Track UNNotificationRequest failed with error: \(error)")
                .category(.notification).level(.error).make()
            return false
        }
    }

    /**
     Method of transmitting the fact of receiving a push on the device.

     - Returns:
     The bool as a result of success delivery within 5sec

     - Parameters:
        - uniqueKey: The uniqueKey string of the notification

     - Important:
     Blockes calling thread no more than by 5sec

     */
    @discardableResult
    public func pushDelivered(uniqueKey: String) -> Bool {
        coreController?.checkNotificationStatus()
        guard let container = container else { return false }
        let tracker = DeliveredNotificationManager(
            persistenceStorage: container.persistenceStorage,
            databaseRepository: container.databaseRepository,
            eventRepository: container.instanceFactory.makeEventRepository()
        )
        do {
            Log("Track delivery")
                .category(.notification).level(.info).make()
            return try tracker.track(uniqueKey: uniqueKey)
        } catch {
            Log("Track UNNotificationRequest failed with error: \(error)")
                .category(.notification).level(.error).make()
            return false
        }
    }

    /**
     Method for transmitting the fact of a click on a push notification.

     - Parameters:
        - uniqueKey: The uniqueKey string of the notification
        - buttonUniqueKey: The buttonUniqueKey string that's describes which button was pressed

     - Important:
     In the case of a click on the push body, you only need to pass the uniqueKey string.
     If there was a click on the button, then the uniqueKey and buttonUniqueKey (of the button that the user clicked on)

     */
    public func pushClicked(uniqueKey: String, buttonUniqueKey: String? = nil) {
        guard let container = container else { return }
        let tracker = ClickNotificationManager(databaseRepository: container.databaseRepository)
        do {
            try tracker.track(uniqueKey: uniqueKey, buttonUniqueKey: buttonUniqueKey)
            Log("Track Click")
                .category(.notification).level(.info).make()
        } catch {
            Log("Track UNNotificationResponse failed with error: \(error)")
                .category(.notification).level(.error).make()
        }
    }

    /**
     Method for register a custom event.

     - Parameters:
        - operationSystemName: Name of custom operation. Only "A-Z", "a-z", ".", "-" characters are allowed.
        - operationBody: Provided `OperationBodyRequestBase` payload to send
     */
    public func executeAsyncOperation<T: OperationBodyRequestType>(operationSystemName: String, operationBody: T) {
        guard operationSystemName.operationNameIsValid else {
            Log("Invalid operation name: \(operationSystemName)")
                .category(.notification).level(.error).make()
            return
        }
        let customEvent = CustomEvent(name: operationSystemName, payload: BodyEncoder(encodable: operationBody).body)
        let event = Event(type: .customEvent, body: BodyEncoder(encodable: customEvent).body)
        do {
            try databaseRepository?.create(event: event)
            Log("Track executeAsyncOperation")
                .category(.notification).level(.info).make()
        } catch {
            Log("Track executeAsyncOperation failed with error: \(error)")
                .category(.notification).level(.error).make()
        }
    }

    /**
     - Warning:
     Deprecated. Use `executeAsyncOperation<T: OperationBodyRequestBase>(operationSystemName:operationBody:)` instead.

     - Note:
     Method for register a custom event.

     - Parameters:
        - operationSystemName: Name of custom operation. Only "A-Z", "a-z", ".", "-" characters are allowed.
        - operationBody: Provided `Encodable` payload to send
     */
    @available(*, deprecated, message: "Use `executeAsyncOperation<T: OperationBodyRequestBase>(operationSystemName: String, operationBody: T)` instead.")
    public func executeAsyncOperation<T: Encodable>(operationSystemName: String, operationBody: T) {
        guard operationSystemName.operationNameIsValid else {
            Log("Invalid operation name: \(operationSystemName)")
                .category(.notification).level(.error).make()
            return
        }
        let customEvent = CustomEvent(name: operationSystemName, payload: BodyEncoder(encodable: operationBody).body)
        let event = Event(type: .customEvent, body: BodyEncoder(encodable: customEvent).body)
        do {
            try databaseRepository?.create(event: event)
            Log("Track executeAsyncOperation")
                .category(.notification).level(.info).make()
        } catch {
            Log("Track executeAsyncOperation failed with error: \(error)")
                .category(.notification).level(.error).make()
        }
    }

    /**
     Method for transmitting the fact of a click on a push notification.

     - Parameters:
        - response: The entire notification response object of UNNotificationResponse class

     */
    public func pushClicked(response: UNNotificationResponse) {
        guard let container = container else { return }
        let tracker = ClickNotificationManager(databaseRepository: container.databaseRepository)
        do {
            try tracker.track(response: response)
            Log("Track Click")
                .category(.notification).level(.info).make()
        } catch {
            Log("Track UNNotificationResponse failed with error: \(error)")
                .category(.notification).level(.error).make()
        }
    }

    /**
     Method for tracking application activities.

     - Parameters:
        - type: `TrackVisitType`

     */
    public func track(_ type: TrackVisitType) {
        guard let container = container else { return }
        let tracker = container.instanceFactory.makeTrackVisitManager()
        do {
            try tracker.track(type)
        } catch {
            Log("Track Visit failed with error: \(error)")
                .category(.visit).level(.error).make()
        }
    }

    /**
     Method for registering background tasks for iOS 13 and higher.

     - Important:
     This method should be called after the app is launched.
     application(_:didFinishLaunchingWithOptions:) method is suitable to call registerBGTasks
     */
    @available(iOS 13.0, *)
    public func registerBGTasks() {
        guard let identifiers = Bundle.main.object(forInfoDictionaryKey: "BGTaskSchedulerPermittedIdentifiers") as? [String] else {
            return
        }
        guard let appGDRefreshIdentifier = identifiers.first(where: { $0.contains("GDAppRefresh") }) else {
            return
        }
        guard let appGDProcessingIdentifier = identifiers.first(where: { $0.contains("GDAppProcessing") }) else {
            return
        }
        guard let appDBCleanProcessingIdentifier = identifiers.first(where: { $0.contains("DBCleanAppProcessing") }) else {
            return
        }
        guaranteedDeliveryManager?.backgroundTaskManager.registerBGTasks(
            appGDRefreshIdentifier: appGDRefreshIdentifier,
            appGDProcessingIdentifier: appGDProcessingIdentifier,
            appDBCleanProcessingIdentifire: appDBCleanProcessingIdentifier
        )
    }

    /**
     Tells the sdk that it can begin a fetch operation if it has data to upload.

     - Important:
     This method is available beetween iOS10 - iOS12. For iOS13 sdk uses BackgroundTask native framework from apple

     - Parameters:
        - application: Your singleton app object
        - performFetchWithCompletionHandler: The block that's executes when the upload operation is completed
     */
    public func application(
        _ application: UIApplication,
        performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guaranteedDeliveryManager?.backgroundTaskManager.application(application, performFetchWithCompletionHandler: completionHandler)
    }

    private var initError: Error?

    private init() {
        queue.sync(flags: .barrier) {
            do {
                let container = try DependencyProvider()
                self.container = container
                self.assembly(with: container)
                Log("Did assembly dependencies with container")
                    .category(.general).level(.info).make()
            } catch {
                Log("Did fail to assembly dependencies with container with error: \(error.localizedDescription)")
                    .category(.general).level(.fault).make()
                self.initError = error
            }
            self.persistenceStorage?.storeToFileBackgroundExecution()
        }
    }

    func assembly(with container: DependencyContainer) {
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
            guaranteedDeliveryManager: container.guaranteedDeliveryManager,
            trackVisitManager: container.instanceFactory.makeTrackVisitManager(),
            sessionManager: container.sessionManager
        )
    }
}
