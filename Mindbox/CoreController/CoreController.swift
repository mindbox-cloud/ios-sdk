//
//  CoreController.swift
//  Mindbox
//
//  Created by Mikhail Barilov on 13.01.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation
import UIKit
import MindboxLogger
import MindboxCommon

final class CoreController {
    private let persistenceStorage: PersistenceStorage
    private let utilitiesFetcher: UtilitiesFetcher
    private let databaseRepository: DatabaseRepositoryProtocol
    private let guaranteedDeliveryManager: GuaranteedDeliveryManager
    private let uuidDebugService: UUIDDebugService
    private var configValidation = ConfigValidation()
    private let userVisitManager: UserVisitManagerProtocol
    private let sessionManager: SessionManager
    private let inAppMessagesManager: InAppCoreManagerProtocol

    var controllerQueue: DispatchQueue

    func initialization(configuration: MBConfiguration) {

        controllerQueue.async {
            MindboxUtils.Stopwatch.shared.start(tag: MindboxUtils.Stopwatch.shared.INIT_SDK)
            SessionTemporaryStorage.shared.isInstalledFromPersistenceStorageBeforeInitSDK = self.persistenceStorage.isInstalled
            SessionTemporaryStorage.shared.isInitializationCalled = true

            DI.injectOrFail(MigrationManagerProtocol.self).migrate()

            self.configValidation.compare(configuration, self.persistenceStorage.configuration)
            self.persistenceStorage.configuration = configuration
            if !self.persistenceStorage.isInstalled {
                self.primaryInitialization(with: configuration)
            } else {
                self.repeatInitialization(with: configuration)
            }
            
            if let duration = MindboxUtils.Stopwatch.shared.stop(tag: MindboxUtils.Stopwatch.shared.INIT_SDK) {
                Logger.common(message: "Mindbox SDK initialized in \(duration). Version \(MindboxCommon.shared.VERSION)", level: .info, category: .general)
            }

            self.guaranteedDeliveryManager.canScheduleOperations = true

            let appStateMessage = "[App State]: \(UIApplication.shared.appStateDescription)"
            Logger.common(message: appStateMessage, level: .info, category: .general)
            Logger.common(message: "[Configuration]: \(configuration)", level: .info, category: .general)
            Logger.common(message: "[SDK Version]: \(self.utilitiesFetcher.sdkVersion ?? "null")", level: .info, category: .general)
            Logger.common(message: "[APNS Token]: \(self.persistenceStorage.apnsToken ?? "null")", level: .info, category: .general)
            Logger.common(message: "[DeviceUUID]: \(self.persistenceStorage.deviceUUID ?? "null")", level: .info, category: .general)
            Logger.common(message: "[CommonSdkVersion]: \(MindboxCommon.shared.VERSION_NAME)", level: .info, category: .general)
        }
    }

    func apnsTokenDidUpdate(token: String) {
        controllerQueue.async {
            let isNotificationsEnabled = self.notificationStatus()

            if self.persistenceStorage.needUpdateInfoOnce ?? true {
                self.updateInfo(apnsToken: token, isNotificationsEnabled: isNotificationsEnabled)
                self.persistenceStorage.isNotificationsEnabled = isNotificationsEnabled
                self.persistenceStorage.apnsToken = token
                self.persistenceStorage.needUpdateInfoOnce = false
                return
            }

            if self.persistenceStorage.isInstalled {
                self.updateInfo(
                    apnsToken: token,
                    isNotificationsEnabled: isNotificationsEnabled
                )
                self.persistenceStorage.isNotificationsEnabled = isNotificationsEnabled
            }
            self.persistenceStorage.apnsToken = token
        }
    }

    func checkNotificationStatus(granted: Bool? = nil,
                                 completion: (() -> Void)? = nil) {
        controllerQueue.async {
            defer { DispatchQueue.main.async { completion?() } }
            
            let isNotificationsEnabled = granted ?? self.notificationStatus()
            guard self.persistenceStorage.isNotificationsEnabled != isNotificationsEnabled else {
                return
            }
            guard self.persistenceStorage.isInstalled else {
                return
            }
            self.updateInfo(
                apnsToken: self.persistenceStorage.apnsToken,
                isNotificationsEnabled: isNotificationsEnabled
            )
            self.persistenceStorage.isNotificationsEnabled = isNotificationsEnabled
        }
    }

    // MARK: - Private
    private func notificationStatus() -> Bool {
        let notificationStatusProvider = DI.injectOrFail(UNAuthorizationStatusProviding.self)
        let lock = DispatchSemaphore(value: 0)
        var isNotificationsEnabled = false
        notificationStatusProvider.getStatus {
            isNotificationsEnabled = $0
            lock.signal()
        }
        lock.wait()
        return isNotificationsEnabled
    }

    private func generateDeviceUUID() -> String {
        let lock = DispatchSemaphore(value: 0)
        var deviceUUID = String()
        let start = CFAbsoluteTimeGetCurrent()
        utilitiesFetcher.getDeviceUUID {
            deviceUUID = $0
            lock.signal()
        }
        lock.wait()
        Logger.common(message: "[Core] It took \(CFAbsoluteTimeGetCurrent() - start) seconds to generate deviceUUID", level: .debug, category: .general)
        return deviceUUID
    }

    private func primaryInitialization(with configutaion: MBConfiguration) {
        // May take up to 3 sec, see utilitiesFetcher.getDeviceUUID implementation
        let deviceUUID = generateDeviceUUID()
        startUUIDDebugServiceIfNeeded(deviceUUID: deviceUUID, configuration: configutaion)
        install(
            deviceUUID: deviceUUID,
            configuration: configutaion
        )
    }

    private func repeatInitialization(with configutaion: MBConfiguration) {
        guard let deviceUUID = persistenceStorage.deviceUUID else {
            Logger.common(message: "[Core] Unable to find deviceUUID in persistenceStorage", level: .error, category: .general)
            return
        }

        if configValidation.changedState != .none {
            Logger.common(message: "[Core] Mindbox Configuration changed", level: .info, category: .general)
            install(
                deviceUUID: deviceUUID,
                configuration: configutaion
            )
        } else {
            Logger.common(message: "[Core] Mindbox Configuration has no changes", level: .info, category: .general)
            checkNotificationStatus()
            persistenceStorage.configuration?.previousDeviceUUID = deviceUUID
        }
        startUUIDDebugServiceIfNeeded(deviceUUID: deviceUUID, configuration: configutaion)
    }

    private func startUUIDDebugServiceIfNeeded(deviceUUID: String, configuration: MBConfiguration) {
        guard configuration.uuidDebugEnabled else { return }
        uuidDebugService.start(with: deviceUUID)
    }

    private func install(deviceUUID: String, configuration: MBConfiguration) {
        persistenceStorage.eraseMetadata()
        try? databaseRepository.erase()
        
        guaranteedDeliveryManager.cancelAllOperations()
        let newVersion = 0 // Variable from an older version of this framework
        persistenceStorage.deviceUUID = deviceUUID
        persistenceStorage.installationId = configuration.previousInstallationId
        persistenceStorage.imageLoadingMaxTimeInSeconds = configuration.imageLoadingMaxTimeInSeconds
        let apnsToken = persistenceStorage.apnsToken
        let isNotificationsEnabled = notificationStatus()
        let instanceId = UUID().uuidString
        self.persistenceStorage.applicationInstanceId = instanceId
        let encodable = MobileApplicationInstalled(
            token: apnsToken,
            isNotificationsEnabled: isNotificationsEnabled,
            installationId: configuration.previousInstallationId,
            subscribe: configuration.subscribeCustomerIfCreated,
            externalDeviceUUID: configuration.previousDeviceUUID,
            version: newVersion,
            instanceId: instanceId,
            ianaTimeZone: self.customerTimeZone(for: configuration)
        )
        do {
            try installEvent(encodable, config: configuration)
            persistenceStorage.isNotificationsEnabled = isNotificationsEnabled
            persistenceStorage.installationDate = Date()
            Logger.common(message: "[Core] Mobile application has been installed", level: .default, category: .general)
            updateLastInfoUpdateDate()
        } catch {
            Logger.common(message: "[Core] Installing mobile application failed with an error: \(error.localizedDescription)", level: .error, category: .general)
        }
    }

    private func customerTimeZone(for config: MBConfiguration) -> String? {
        return config.shouldCreateCustomer ? TimeZone.current.identifier : nil
    }

    private func installEvent<T: Encodable>(_ body: T, config: MBConfiguration) throws {
        guard let event: Event = {
            let body = BodyEncoder(encodable: body).body
            if config.shouldCreateCustomer {
                return Event(
                    type: .installed,
                    body: body
                )
            } else if !persistenceStorage.isInstalled || configValidation.changedState == .rest {
                return Event(
                    type: .installedWithoutCustomer,
                    body: body
                )
            } else {
                return nil
            }
        }() else { return }

        try databaseRepository.create(event: event)
    }

    private func updateInfo(apnsToken: String?, isNotificationsEnabled: Bool, eventType: Constants.InfoUpdateVersions = .infoUpdated) {
        let previousVersion = persistenceStorage.applicationInfoUpdateVersion ?? 0
        let newVersion = previousVersion + 1
        let infoUpdated = MobileApplicationInfoUpdated(
            token: apnsToken,
            isNotificationsEnabled: isNotificationsEnabled,
            version: newVersion,
            instanceId: persistenceStorage.applicationInstanceId ?? ""
        )
        let event = Event(
            type: eventType.operation,
            body: BodyEncoder(encodable: infoUpdated).body
        )
        do {
            try databaseRepository.create(event: event)
            persistenceStorage.applicationInfoUpdateVersion = newVersion
            Logger.common(message: "[Core] Mobile application info has been updated", level: .default, category: .general)
            updateLastInfoUpdateDate()
        } catch {
            Logger.common(message: "[Core] Updating mobile application info failed with an error: \(error.localizedDescription)", level: .error, category: .general)
        }
    }

    init(
        persistenceStorage: PersistenceStorage,
        utilitiesFetcher: UtilitiesFetcher,
        databaseRepository: DatabaseRepositoryProtocol,
        guaranteedDeliveryManager: GuaranteedDeliveryManager,
        sessionManager: SessionManager,
        inAppMessagesManager: InAppCoreManagerProtocol,
        uuidDebugService: UUIDDebugService,
        controllerQueue: DispatchQueue = DispatchQueue(label: "com.Mindbox.controllerQueue"),
        userVisitManager: UserVisitManagerProtocol
    ) {
        self.persistenceStorage = persistenceStorage
        self.utilitiesFetcher = utilitiesFetcher
        self.databaseRepository = databaseRepository
        self.guaranteedDeliveryManager = guaranteedDeliveryManager
        self.uuidDebugService = uuidDebugService
        self.controllerQueue = controllerQueue
        self.inAppMessagesManager = inAppMessagesManager
        self.sessionManager = sessionManager
        self.userVisitManager = userVisitManager
        
        registerPushTokenKeepaliveObserver()

        sessionManager.sessionHandler = { [weak self] isActive in
            if isActive && SessionTemporaryStorage.shared.isInitializationCalled {
                self?.checkNotificationStatus()
                self?.controllerQueue.async {
                    self?.sessionManager.trackDirect()
                    self?.userVisitManager.saveUserVisit()
                    self?.inAppMessagesManager.start()
                }
            }
        }

        let timer = DI.injectOrFail(TimerManager.self)
        timer.configurate(trackEvery: 20 * 60) {
            Logger.common(message: "[Core] Scheduled Time tracker started")
            sessionManager.trackForeground()
        }

        timer.setupTimer()
    }
}

// MARK: - For sending "ApplicationKeepalive" via Config

private extension CoreController {
    
    func registerPushTokenKeepaliveObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePushTokenKeepalive),
            name: .receivedPushTokenKeepaliveFromTheMobileConfig,
            object: nil
        )
    }
    
    @objc
    func handlePushTokenKeepalive(_ notification: Notification) {
        controllerQueue.async { [weak self] in
            guard let self, let timeSpanString = notification.userInfo?[Constants.Notification.pushTokenKeepalive] as? String else {
                Logger.common(
                    message: "[Keepalive] missing or wrong key in userInfo: \(String(describing: notification.userInfo))", level: .debug, category: .pushTokenKeepalive
                )
                return
            }
            guard let seconds = try? timeSpanString.parseTimeSpanToSeconds(), seconds > 0 else {
                Logger.common(
                    message: "[Keepalive] invalid time span - \(timeSpanString)", level: .debug, category: .pushTokenKeepalive
                )
                return
            }
            
            let interval = TimeInterval(seconds)
            if shouldSendKeepalive(after: interval) {
                Logger.common(
                    message: "[Keepalive] Sending keep-alive (interval \(timeSpanString))", level: .debug, category: .pushTokenKeepalive
                )

                updateInfo(
                    apnsToken: persistenceStorage.apnsToken,
                    isNotificationsEnabled: notificationStatus(),
                    eventType: .keepAlive
                )
            } else {
                Logger.common(
                    message: "[Keepalive] Skip sending (not expired yet)", level: .debug, category: .pushTokenKeepalive
                )
            }
        }
    }
    
    func shouldSendKeepalive(after interval: TimeInterval) -> Bool {
        guard let lastDate = persistenceStorage.lastInfoUpdateDate else {
            Logger.common(
                message: "[Keepalive] First run — no lastInfoUpdateDate, will send now",
                level: .debug, category: .pushTokenKeepalive
            )
            return true
        }
        
        let now = Date()
        let elapsed = now.timeIntervalSince(lastDate)
        let thresholdDate = lastDate.addingTimeInterval(interval)
        let isAllowed = elapsed > interval
        
        Logger.common(
            message: """
              [Keepalive] Last lastInfoUpdateDate: \(lastDate.toFullString()), \
              earliest next send allowed from: \(thresholdDate.toFullString()), \
              elapsed: \(Int(elapsed))s, \
              required: \(Int(interval))s, \
              allowed to send: \(isAllowed)
              """,
            level: .debug, category: .pushTokenKeepalive
          )
        
        return isAllowed
    }
    
    func updateLastInfoUpdateDate() {
        guard persistenceStorage.isInstalled else { return }
        let now = Date()
        persistenceStorage.lastInfoUpdateDate = now
        Logger.common(message: "[Keepalive] Updated lastInfoUpdateDate to \(now.toFullString())",
                      level: .debug, category: .pushTokenKeepalive)
    }
}
