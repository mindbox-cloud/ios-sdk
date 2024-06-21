//
//  Mindbox.swift
//  Mindbox
//
//  Created by Mikhail Barilov on 12.01.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation
import UIKit
import MindboxLogger

@objcMembers
public class Mindbox: NSObject {
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
      By default _logLevel_: __.error__
     */
    public static let logger = MBLogger.shared

    // MARK: - Dependencies

    private var persistenceStorage: PersistenceStorage?
    private var utilitiesFetcher: UtilitiesFetcher?
    private var guaranteedDeliveryManager: GuaranteedDeliveryManager?
    private var databaseRepository: MBDatabaseRepository?
    private var inAppMessagesManager: InAppCoreManagerProtocol?
    private var sessionTemporaryStorage: SessionTemporaryStorage?
    private var inappMessageEventSender: InappMessageEventSender?

    private let queue = DispatchQueue(label: "com.Mindbox.initialization", attributes: .concurrent)

    var coreController: CoreController?
    var containerOLD: DependencyContainer?

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
     A delegate for handling in-app messages.

     This property allows the conforming object to respond to in-app message related events. Setting this delegate enables the SDK to notify the conforming object about in-app message behaviors, updates, or user interactions.

     - Note: If you use default implementation of in-app messaging provided by the SDK, subscribing to this delegate is not necessary. The default implementation will handle in-app message events automatically.

     - However, if the user wishes to customize the handling of in-app messages, it is mandatory to subscribe to this delegate. Customization can include handling specific user interactions, presenting messages in a custom format, or integrating more complex in-app message logic.
     */
    
    public weak var inAppMessagesDelegate: InAppMessagesDelegate? {
        didSet {
            inAppMessagesManager?.delegate = inAppMessagesDelegate
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
    }

    private var observeSemaphore = DispatchSemaphore(value: 1)

    private func observe(value: @escaping @autoclosure () -> String?, with completion: @escaping (String) -> Void) {
        observeSemaphore.lock {
            let token = UUID()
            persistenceStorage?.onDidChange = { [weak self] in
                guard let self = self else { return }
                self.observeSemaphore.lock {
                    guard let value = value(), let index = self.observeTokens.firstIndex(of: token) else { return }
                    self.observeTokens.remove(at: index)
                    completion(value)
                }
            }
            observeTokens.append(token)
        }
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
        Logger.common(message: "Did register for remote notifications with token: \(token)", level: .info, category: .notification)
        if let persistenceAPNSToken = persistenceStorage?.apnsToken {
            
            if persistenceStorage?.needUpdateInfoOnce ?? true {
                Logger.common(message: "APNS Token forced to update")
                coreController?.apnsTokenDidUpdate(token: token)
                return
            }
            
            guard persistenceAPNSToken != token else {
                Logger.common(message: "persistenceAPNSToken is equal to deviceToken. persistenceAPNSToken: \(persistenceAPNSToken)", level: .error, category: .notification)
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
    @available(*, deprecated, message: "")
    @discardableResult
    public func pushDelivered(request: UNNotificationRequest) -> Bool { return false }

    /**
     Method of transmitting the fact of receiving a push on the device.

     - Returns:
     The bool as a result of success delivery within 5sec

     - Parameters:
        - uniqueKey: The uniqueKey string of the notification

     - Important:
     Blockes calling thread no more than by 5sec

     */
    @available(*, deprecated, message: "")
    @discardableResult
    public func pushDelivered(uniqueKey: String) -> Bool { return false }

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
        guard let containerOLD = containerOLD else { return }
        let tracker = ClickNotificationManager(databaseRepository: containerOLD.databaseRepository)
        do {
            try tracker.track(uniqueKey: uniqueKey, buttonUniqueKey: buttonUniqueKey)
            Logger.common(message: "Track Click", level: .info, category: .notification)
        } catch {
            Logger.common(message: "Track UNNotificationResponse failed with error: \(error)", level: .error, category: .notification)
        }
    }

    /**
     Method for register a custom event.

     - Parameters:
        - operationSystemName: Name of custom operation. Only "A-Z", "a-z", ".", "-" characters are allowed.
        - operationBody: Provided `OperationBodyRequestBase` payload to send.
     */
    public func executeAsyncOperation<T: OperationBodyRequestType>(operationSystemName: String, operationBody: T) {
        guard operationSystemName.operationNameIsValid else {
            Logger.common(message: "Invalid operation name: \(operationSystemName)", level: .error, category: .notification)
            return
        }
        let operationBodyJSON = BodyEncoder(encodable: operationBody).body
        let customEvent = CustomEvent(name: operationSystemName, payload: operationBodyJSON)

        let event = Event(type: .customEvent, body: BodyEncoder(encodable: customEvent).body)
        sendEventToInAppMessagesIfNeeded(operationSystemName, jsonString: operationBodyJSON)
        do {
            try databaseRepository?.create(event: event)
            Logger.common(message: "Track executeAsyncOperation", level: .info, category: .notification)
        } catch {
            Logger.common(message: "Track executeAsyncOperation failed with error: \(error)", level: .error, category: .notification)
        }
    }

    /**
     Method for register a custom event.

     - Parameters:
        - operationSystemName: Name of custom operation. Only "A-Z", "a-z", ".", "-" characters are allowed.
        - json: String which contains JSON to send.
     */
    public func executeAsyncOperation(operationSystemName: String, json: String) {
        guard operationSystemName.operationNameIsValid else {
            Logger.common(message: "Invalid operation name: \(operationSystemName)", level: .error, category: .notification)
            return
        }
        guard let jsonData = json.data(using: .utf8),
              let _ = try? JSONSerialization.jsonObject(with: jsonData) else {
            Logger.common(message: "Operation body is not valid JSON", level: .error, category: .notification)
            return
        }
        let customEvent = CustomEvent(name: operationSystemName, payload: json)
        let event = Event(type: .customEvent, body: BodyEncoder(encodable: customEvent).body)
        sendEventToInAppMessagesIfNeeded(operationSystemName, jsonString: json)
        do {
            try databaseRepository?.create(event: event)
            Logger.common(message: "Track executeAsyncOperation", level: .info, category: .notification)
        } catch {
            Logger.common(message: "Track executeAsyncOperation failed with error: \(error)", level: .error, category: .notification)
        }
    }

    /**
     Method for executing an operation synchronously.

     - Parameters:
        - operationSystemName: Name of custom operation. Only "A-Z", "a-z", ".", "-" characters are allowed.
        - operationBody: Provided `OperationBodyRequestType` payload to send
        - completion: Result of sending operation. Contains `OperationResponse` or `MindboxError`.
     */
    public func executeSyncOperation<T>(
        operationSystemName: String,
        operationBody: T,
        completion: @escaping (Result<OperationResponse, MindboxError>) -> Void
    ) where T: OperationBodyRequestType {
        guard operationSystemName.operationNameIsValid else {
            Logger.common(message: "Invalid operation name: \(operationSystemName)", level: .error, category: .notification)
            return
        }
        let operationBodyJSON = BodyEncoder(encodable: operationBody).body
        let customEvent = CustomEvent(name: operationSystemName, payload: operationBodyJSON)
        let event = Event(type: .syncEvent, body: BodyEncoder(encodable: customEvent).body)
        containerOLD?.instanceFactory.makeEventRepository().send(type: OperationResponse.self, event: event, completion: completion)
        sendEventToInAppMessagesIfNeeded(operationSystemName, jsonString: operationBodyJSON)
        Logger.common(message: "Track executeSyncOperation", level: .info, category: .notification)
    }

    /**
     Method for executing an operation synchronously.

     - Parameters:
        - operationSystemName: Name of custom operation. Only "A-Z", "a-z", ".", "-" characters are allowed.
        - json: String which contains JSON to send.
        - completion: Result of sending operation. Contains `OperationResponse` or `MindboxError`.
     */
    public func executeSyncOperation(
        operationSystemName: String,
        json: String,
        completion: @escaping (Result<OperationResponse, MindboxError>) -> Void
    ) {
        guard operationSystemName.operationNameIsValid else {
            Logger.common(message: "Invalid operation name: \(operationSystemName)", level: .error, category: .notification)
            return
        }
        guard let jsonData = json.data(using: .utf8),
              let _ = try? JSONSerialization.jsonObject(with: jsonData) else {
            Logger.common(message: "Operation body is not valid JSON", level: .error, category: .notification)
            return
        }
        let customEvent = CustomEvent(name: operationSystemName, payload: json)
        let event = Event(type: .syncEvent, body: BodyEncoder(encodable: customEvent).body)
        containerOLD?.instanceFactory.makeEventRepository().send(type: OperationResponse.self, event: event, completion: completion)
        sendEventToInAppMessagesIfNeeded(operationSystemName, jsonString: json)
        Logger.common(message: "Track executeSyncOperation", level: .info, category: .notification)
    }

    /**
     Method for executing an operation synchronously.
     
     - Note: use this method if you have your own object that extends `OperationResponseType`.

     - Parameters:
        - operationSystemName: Name of custom operation. Only "A-Z", "a-z", ".", "-" characters are allowed.
        - operationBody: Provided `OperationBodyRequestType` payload to send.
        - customResponseType: Expected result type in completion.
        - completion: Result of sending operation. Contains `OperationResponseType` or `MindboxError`.
     */
    public func executeSyncOperation<T, P>(
        operationSystemName: String,
        operationBody: T,
        customResponseType: P.Type,
        completion: @escaping (Result<P, MindboxError>) -> Void
    ) where T: OperationBodyRequestType, P: OperationResponseType {
        guard operationSystemName.operationNameIsValid else {
            Logger.common(message: "Invalid operation name: \(operationSystemName)", level: .error, category: .notification)
            return
        }
        let operationBodyJSON = BodyEncoder(encodable: operationBody).body
        let customEvent = CustomEvent(name: operationSystemName, payload: operationBodyJSON)
        let event = Event(type: .syncEvent, body: BodyEncoder(encodable: customEvent).body)
        containerOLD?.instanceFactory.makeEventRepository().send(type: P.self, event: event, completion: completion)
        sendEventToInAppMessagesIfNeeded(operationSystemName, jsonString: operationBodyJSON)
        Logger.common(message: "Track executeSyncOperation", level: .info, category: .notification)
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
            Logger.common(message: "Invalid operation name: \(operationSystemName)", level: .error, category: .notification)
            return
        }
        let operationBodyJSON = BodyEncoder(encodable: operationBody).body
        let customEvent = CustomEvent(name: operationSystemName, payload: operationBodyJSON)
        let event = Event(type: .customEvent, body: BodyEncoder(encodable: customEvent).body)
        sendEventToInAppMessagesIfNeeded(operationSystemName, jsonString: operationBodyJSON)
        do {
            try databaseRepository?.create(event: event)
            Logger.common(message: "Track executeAsyncOperation", level: .info, category: .notification)
        } catch {
            Logger.common(message: "Track executeAsyncOperation failed with error: \(error)", level: .error, category: .notification)
        }
    }

    /**
     Method for transmitting the fact of a click on a push notification.

     - Parameters:
        - response: The entire notification response object of UNNotificationResponse class

     */
    public func pushClicked(response: UNNotificationResponse) {
        guard let containerOLD = containerOLD else { return }
        let tracker = ClickNotificationManager(databaseRepository: containerOLD.databaseRepository)
        do {
            try tracker.track(response: response)
            Logger.common(message: "Track Click", level: .info, category: .notification)
        } catch {
            Logger.common(message: "Track UNNotificationResponse failed with error: \(error)", level: .error, category: .notification)
        }
    }

    /**
     Method for tracking application activities.

     - Parameters:
        - type: `TrackVisitType`

     */
    public func track(_ type: TrackVisitType) {
        guard let containerOLD = containerOLD else { return }
        let tracker = containerOLD.instanceFactory.makeTrackVisitManager()
        do {
            try tracker.track(type)
        } catch {
            Logger.common(message: "Track Visit failed with error: \(error)", level: .error, category: .visit)
        }
    }
    
    /**
     Objc method for tracking application activities.

     - Parameters:
        - type: `TrackVisitType`

     */
    public func track(data: TrackVisitData) {
        guard let containerOLD = containerOLD else { return }
        let tracker = containerOLD.instanceFactory.makeTrackVisitManager()
        do {
            try tracker.track(data: data)
        } catch {
            Logger.common(message: "Track Visit failed with error: \(error)", level: .error, category: .visit)
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
    
    /**
     Determines whether the given notification is a Mindbox push notification.

     This method checks if the notification received is related to Mindbox by validating its content.

     - Parameter notification: The `UNNotification` instance representing the received push notification.

     - Returns: A Boolean value indicating whether the notification is related to Mindbox.
    */
    public func isMindboxPush(userInfo: [AnyHashable: Any]) -> Bool {
        let pushValidator = DI.injectOrFail(MindboxPushValidator.self)
        return pushValidator.isValid(item: userInfo)
    }
    
    /**
     Converts a `UNNotification` to a `MBPushNotification` model for Mindbox push notifications.

     This method simplifies handling different Mindbox push notification formats. It takes a `UNNotification` as input, processes its content, and outputs a structured `MBPushNotification`. This allows applications to work with Mindbox notifications without concerning themselves with the underlying format details.

     - Parameter notification: The `UNNotification` with the raw notification data.

     - Returns: An optional `MBPushNotification` containing the notification's formatted data, or `nil` if the data cannot be formatted.
     
     Note: Mindbox manages various push notification formats internally. Just pass the `UNNotification` to this method to receive a formatted `MBPushNotification`.
    */
    public func getMindboxPushData(userInfo: [AnyHashable: Any]) -> MBPushNotification? {
        return NotificationFormatter.formatNotification(userInfo)
    }

    private var initError: Error?

    private override init() {
        super.init()
        queue.sync(flags: .barrier) {
            do {
                let containerOLD = try DependencyProvider()
                self.containerOLD = containerOLD
                self.assembly(with: containerOLD)
                Logger.common(message: "Did assembly dependencies with containerOLD", level: .info, category: .general)
            } catch {
                Logger.common(message: "Did fail to assembly dependencies with containerOLD with error: \(error.localizedDescription)", level: .fault, category: .general)
                self.initError = error
            }
            self.persistenceStorage?.storeToFileBackgroundExecution()            
        }
    }

    func assembly(with containerOLD: DependencyContainer) {
        persistenceStorage = containerOLD.persistenceStorage
        utilitiesFetcher = containerOLD.utilitiesFetcher
        guaranteedDeliveryManager = containerOLD.guaranteedDeliveryManager
        databaseRepository = containerOLD.databaseRepository
        inAppMessagesManager = containerOLD.inAppMessagesManager
        inAppMessagesDelegate = self
        inappMessageEventSender = containerOLD.inappMessageEventSender

        coreController = CoreController(
            persistenceStorage: containerOLD.persistenceStorage,
            utilitiesFetcher: containerOLD.utilitiesFetcher,
            databaseRepository: containerOLD.databaseRepository,
            guaranteedDeliveryManager: containerOLD.guaranteedDeliveryManager,
            trackVisitManager: containerOLD.instanceFactory.makeTrackVisitManager(),
            sessionManager: containerOLD.sessionManager,
            inAppMessagesManager: containerOLD.inAppMessagesManager,
            uuidDebugService: DI.injectOrFail(UUIDDebugService.self),
            userVisitManager: containerOLD.userVisitManager
        )
    }

    private func sendEventToInAppMessagesIfNeeded(_ operationSystemName: String, jsonString: String?) {
        inappMessageEventSender?.sendEventIfEnabled(operationSystemName, jsonString: jsonString)
    }

    @objc private func resetShownInApps() {
        persistenceStorage?.shownInappsDictionary = [:]
    }
    
    @objc private func eraseSessionStorage() {
        sessionTemporaryStorage?.erase()
    }
}

extension Mindbox: DefaultInappMessageDelegate {
    
}
