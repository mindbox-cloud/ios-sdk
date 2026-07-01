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
    private var databaseRepository: DatabaseRepositoryProtocol?
    private var inappScheduleManager: InappScheduleManagerProtocol?
    private var sessionTemporaryStorage: SessionTemporaryStorage?
    private var trackVisitManager: TrackVisitCommonTrackProtocol?

    /// Serial queue for off-main event creation/persistence so public operation calls return
    /// without blocking the caller (main) thread. Serial preserves event ordering.
    private let eventQueue = DispatchQueue(label: "com.Mindbox.eventQueue")

    var coreController: CoreController?

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
            inappScheduleManager?.delegate = inAppMessagesDelegate
        }
    }

    /**
     Method to instruct sdk of its initialization.

     - Parameters:
        - configuration: MBConfiguration struct with configuration
     */
    public func initialization(configuration: MBConfiguration) {
        coreController?.initialization(configuration: configuration)
        // MEASUREMENT (throwaway): warm the WebView web-content process as early as possible.
        // Safe here — assembly() (in init) has already built DI, so UtilitiesFetcher is available;
        // and the cacher hardcodes its URLs, so it needs neither the in-app config nor session-active.
        WebViewShowProfiler.prewarmIfRequested()
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
                // Resolve under the lock, invoke the host completion AFTER unlocking: the
                // non-recursive semaphore would self-deadlock if the callback re-enters
                // getDeviceUUID/getAPNSToken. Delivery stays synchronous on the notifying
                // thread - long-standing public contract (encoded in MindboxTests).
                let resolved: String? = self.observeSemaphore.lock {
                    guard let value = value(), let index = self.observeTokens.firstIndex(of: token) else { return nil }
                    self.observeTokens.remove(at: index)
                    return value
                }
                if let resolved {
                    completion(resolved)
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
        Logger.common(message: "Did register for remote notifications with device token: \(token)", level: .info, category: .notification)
        if let persistenceAPNSToken = persistenceStorage?.apnsToken {

            if persistenceStorage?.needUpdateInfoOnce ?? true {
                Logger.common(message: "APNS Token forced to update", category: .notification)
                coreController?.apnsTokenDidUpdate(token: token)
                return
            }

            guard persistenceAPNSToken != token else {
                Logger.common(message: "APNS token hasn't changed", level: .info, category: .notification)
                return
            }
            coreController?.apnsTokenDidUpdate(token: token)
        } else {
            coreController?.apnsTokenDidUpdate(token: token)
        }
    }

    /// Deprecated. Use ``Mindbox/Mindbox/refreshNotificationPermissionStatus()`` instead.
    ///
    /// This method is kept for backward compatibility. The `granted` argument is ignored.
    /// The SDK reads the current system authorization status and, if it differs
    /// from the last known value, sends an update to the backend.
    @available(*, deprecated, message: "Use refreshNotificationPermissionStatus() instead.", renamed: "refreshNotificationPermissionStatus()")
    public func notificationsRequestAuthorization(granted: Bool) {
        coreController?.checkNotificationStatus()
    }
    
    /// Checks the current system authorization status for push notifications
    /// and reports any changes to Mindbox.
    ///
    /// The SDK retrieves the current `UNAuthorizationStatus` from
    /// `UNUserNotificationCenter`, compares it with the last known value,
    /// and, if it has changed, sends the update to the backend.
    /// 
    /// - Important: This method does **not** prompt the system permission alert.
    public func refreshNotificationPermissionStatus() {
        coreController?.checkNotificationStatus()
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
        enqueueClickTracking { try $0.track(uniqueKey: uniqueKey, buttonUniqueKey: buttonUniqueKey) }
    }

    /**
     Method for register a custom event.

     - Parameters:
        - operationSystemName: Name of custom operation. Only "A-Z", "a-z", ".", "-" characters are allowed.
        - operationBody: Provided `OperationBodyRequestBase` payload to send.
     */
    public func executeAsyncOperation<T: OperationBodyRequestType>(operationSystemName: String, operationBody: T) {
        guard validateOperationName(operationSystemName) else { return }
        // Encode on the caller: operation bodies are mutable classes, so the snapshot
        // must be taken before the queue hop or it races host mutations. Only the
        // immutable JSON string crosses to the queue.
        let operationBodyJSON = BodyEncoder(encodable: operationBody).body
        enqueueAsyncEvent(operationSystemName: operationSystemName, payloadJSON: operationBodyJSON)
    }

    /**
     Method for register a custom event.

     - Parameters:
        - operationSystemName: Name of custom operation. Only "A-Z", "a-z", ".", "-" characters are allowed.
        - json: String which contains JSON to send.
     */
    public func executeAsyncOperation(operationSystemName: String, json: String) {
        guard validateOperationName(operationSystemName) else { return }
        enqueueAsyncEvent(operationSystemName: operationSystemName, payloadJSON: json, validatePayloadAsJSON: true)
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
        guard validateOperationName(operationSystemName) else {
            failSyncOperation(reason: "Invalid operation name: \(operationSystemName)", completion: completion)
            return
        }
        // Caller-side encode: same mutable-body snapshot contract as executeAsyncOperation.
        let operationBodyJSON = BodyEncoder(encodable: operationBody).body
        enqueueSyncEvent(operationSystemName: operationSystemName, payloadJSON: operationBodyJSON, completion: completion)
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
        guard validateOperationName(operationSystemName) else {
            failSyncOperation(reason: "Invalid operation name: \(operationSystemName)", completion: completion)
            return
        }
        enqueueSyncEvent(operationSystemName: operationSystemName, payloadJSON: json, validatePayloadAsJSON: true, completion: completion)
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
        guard validateOperationName(operationSystemName) else {
            failSyncOperation(reason: "Invalid operation name: \(operationSystemName)", completion: completion)
            return
        }
        // Caller-side encode: same mutable-body snapshot contract as executeAsyncOperation.
        let operationBodyJSON = BodyEncoder(encodable: operationBody).body
        enqueueSyncEvent(operationSystemName: operationSystemName, payloadJSON: operationBodyJSON, completion: completion)
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
        guard validateOperationName(operationSystemName) else { return }
        // Caller-side encode: same mutable-body snapshot contract as the generic overload.
        let operationBodyJSON = BodyEncoder(encodable: operationBody).body
        enqueueAsyncEvent(operationSystemName: operationSystemName, payloadJSON: operationBodyJSON)
    }

    // MARK: - Operations pipeline

    /// Shared tail of the pushClicked overloads: resolve the tracker on the caller,
    /// persist the click off-main on eventQueue.
    private func enqueueClickTracking(_ track: @escaping (ClickNotificationManager) throws -> Void) {
        guard let tracker = DI.inject(ClickNotificationManager.self) else {
            Logger.common(message: "Track Click dropped: ClickNotificationManager is nil", level: .error, category: .notification)
            return
        }
        eventQueue.async {
            do {
                try track(tracker)
                Logger.common(message: "Track Click", level: .info, category: .notification)
            } catch {
                Logger.common(message: "Track UNNotificationResponse failed with error: \(error)", level: .error, category: .notification)
            }
        }
    }

    /// Shared validation guard of every operation overload; logs the drop reason once.
    private func validateOperationName(_ operationSystemName: String) -> Bool {
        guard OperationNameValidator.isValid(operationSystemName) else {
            Logger.common(message: "Invalid operation name: \(operationSystemName)", level: .error, category: .notification)
            return false
        }
        return true
    }

    /// Delivers a `.validationError` failure on the main thread for sync operation overloads
    /// that detect an invalid input before reaching the event queue.
    private func failSyncOperation<P>(
        reason: String,
        location: String = "operationSystemName",
        completion: @escaping (Result<P, MindboxError>) -> Void
    ) {
        let error = MindboxError.validationError(ValidationError(
            status: .validationError,
            validationMessages: [ValidationMessage(message: reason, location: location)]
        ))
        DispatchQueue.main.async { completion(.failure(error)) }
    }

    /// Off-main tail of the executeAsyncOperation overloads: build the event on eventQueue
    /// and persist it for guaranteed delivery. `payloadJSON` must be an immutable snapshot
    /// taken on the caller; host-provided JSON strings are validated here, off-main.
    private func enqueueAsyncEvent(operationSystemName: String, payloadJSON: String, validatePayloadAsJSON: Bool = false) {
        eventQueue.async { [self] in
            if validatePayloadAsJSON, !Self.isValidJSON(payloadJSON) {
                Logger.common(message: "Operation body is not valid JSON", level: .error, category: .notification)
                return
            }
            let customEvent = CustomEvent(name: operationSystemName, payload: payloadJSON)
            let event = Event(type: .customEvent, body: BodyEncoder(encodable: customEvent).body)
            self.sendCustomEventInapps(operationSystemName, jsonString: payloadJSON)
            guard let databaseRepository = self.databaseRepository else {
                Logger.common(message: "Track executeAsyncOperation dropped: databaseRepository is nil", level: .error, category: .notification)
                return
            }
            do {
                try databaseRepository.create(event: event)
                Logger.common(message: "Track executeAsyncOperation", level: .info, category: .notification)
            } catch {
                Logger.common(message: "Track executeAsyncOperation failed with error: \(error)", level: .error, category: .notification)
            }
        }
    }

    /// Off-main tail of the executeSyncOperation overloads: build the sync event on
    /// eventQueue and hand it to EventRepository, which delivers `completion` on main.
    /// Invalid JSON fails the operation with a `.validationError` delivered on main, so the
    /// completion contract holds on every path. The repository is resolved at call time on purpose.
    private func enqueueSyncEvent<P: OperationResponseType>(
        operationSystemName: String,
        payloadJSON: String,
        validatePayloadAsJSON: Bool = false,
        completion: @escaping (Result<P, MindboxError>) -> Void
    ) {
        let eventRepository = DI.injectOrFail(EventRepository.self)
        eventQueue.async { [self] in
            if validatePayloadAsJSON, !Self.isValidJSON(payloadJSON) {
                Logger.common(message: "Operation body is not valid JSON", level: .error, category: .notification)
                self.failSyncOperation(reason: "Operation body is not valid JSON", location: "operationBody", completion: completion)
                return
            }
            let customEvent = CustomEvent(name: operationSystemName, payload: payloadJSON)
            let event = Event(type: .syncEvent, body: BodyEncoder(encodable: customEvent).body)
            eventRepository.send(type: P.self, event: event, completion: completion)
            self.sendCustomEventInapps(operationSystemName, jsonString: payloadJSON)
            Logger.common(message: "Track executeSyncOperation", level: .info, category: .notification)
        }
    }

    private static func isValidJSON(_ json: String) -> Bool {
        guard let jsonData = json.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: jsonData)) != nil
    }

    /**
     Method for transmitting the fact of a click on a push notification.

     - Parameters:
        - response: The entire notification response object of UNNotificationResponse class

     */
    public func pushClicked(response: UNNotificationResponse) {
        enqueueClickTracking { try $0.track(response: response) }
    }

    /**
     Method for tracking application activities.

     - Parameters:
        - type: `TrackVisitType`

     */
    public func track(_ type: TrackVisitType) {
        guard let trackVisitManager = trackVisitManager else {
            Logger.common(message: "Track Visit dropped: trackVisitManager is nil", level: .error, category: .visit)
            return
        }
        // Deliberately NOT deferred to eventQueue: handlePush/handleUniversalLink set
        // skipNextDirectTrackVisit, which trackDirect consumes on controllerQueue. The
        // flag write must happen-before that dispatch, or a queued track(.push) races it:
        // duplicate direct visit now, the next legitimate one wrongly skipped.
        do {
            try trackVisitManager.track(type)
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
        guard let trackVisitManager = trackVisitManager else {
            Logger.common(message: "Track Visit dropped: trackVisitManager is nil", level: .error, category: .visit)
            return
        }
        // Synchronous on purpose: same skipNextDirectTrackVisit contract as track(_:) above.
        do {
            try trackVisitManager.track(data: data)
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

    override private init() {
        super.init()
        self.assembly()
    }

    func assembly() {
        persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
        utilitiesFetcher = DI.injectOrFail(UtilitiesFetcher.self)
        guaranteedDeliveryManager = DI.injectOrFail(GuaranteedDeliveryManager.self)
        databaseRepository = DI.injectOrFail(DatabaseRepositoryProtocol.self)
        inappScheduleManager = DI.injectOrFail(InappScheduleManagerProtocol.self)
        inAppMessagesDelegate = self
        coreController = DI.injectOrFail(CoreController.self)
        trackVisitManager = DI.injectOrFail(TrackVisitManagerProtocol.self)
    }

    private func sendCustomEventInapps(_ operationSystemName: String, jsonString: String?) {
        // Reached only from the eventQueue operation blocks - i.e. off the main thread.
        guard let inappMessageEventSender = DI.inject(InappMessageEventSender.self) else {
            return
        }

        Logger.common(message: "[Mindbox] Send event to InApp messages if needed. Operation system name: \(operationSystemName)", category: .inAppMessages)

        inappMessageEventSender.sendEventIfEnabled(operationSystemName, jsonString: jsonString)
    }

    @objc
    private func resetShownInApps() {
        persistenceStorage?.shownDatesByInApp = [:]
    }

    @objc
    private func eraseSessionStorage() {
        sessionTemporaryStorage?.erase()
    }
}

extension Mindbox: DefaultInappMessageDelegate {}
