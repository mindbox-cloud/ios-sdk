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

final class CoreController {
    private let persistenceStorage: PersistenceStorage
    private let utilitiesFetcher: UtilitiesFetcher
    private let databaseRepository: MBDatabaseRepository
    private let guaranteedDeliveryManager: GuaranteedDeliveryManager
    private let trackVisitManager: TrackVisitManager
    private let uuidDebugService: UUIDDebugService
    private var configValidation = ConfigValidation()
    private let userVisitManager: UserVisitManagerProtocol
    private let sessionManager: SessionManager
    private let inAppMessagesManager: InAppCoreManagerProtocol

    var controllerQueue: DispatchQueue

    func initialization(configuration: MBConfiguration) {
        
        controllerQueue.async {
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
            
            self.guaranteedDeliveryManager.canScheduleOperations = true
            
            let appStateMessage = "[App State]: \(UIApplication.shared.appStateDescription)"
            Logger.common(message: appStateMessage, level: .info, category: .general)
        }
        
        Logger.common(message: "[Configuration]: \(configuration)", level: .info, category: .general)
        Logger.common(message: "[SDK Version]: \(self.utilitiesFetcher.sdkVersion ?? "null")", level: .info, category: .general)
        Logger.common(message: "[APNS Token]: \(self.persistenceStorage.apnsToken ?? "null")", level: .info, category: .general)
        Logger.common(message: "[IDFA]: \(self.persistenceStorage.deviceUUID ?? "null")", level: .info, category: .general)
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

    func checkNotificationStatus(granted: Bool? = nil) {
        controllerQueue.async {
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
        var deviceUUID: String?
        let start = CFAbsoluteTimeGetCurrent()
        utilitiesFetcher.getDeviceUUID {
            deviceUUID = $0
            lock.signal()
        }
        lock.wait()
        Logger.common(message: "It took \(CFAbsoluteTimeGetCurrent() - start) seconds to generate deviceUUID", level: .debug, category: .general)
        return deviceUUID!
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
            Logger.common(message: "Unable to find deviceUUID in persistenceStorage", level: .error, category: .general)
            return
        }
        
        if configValidation.changedState != .none {
            Logger.common(message: "Mindbox Configuration changed", level: .info, category: .general)
            install(
                deviceUUID: deviceUUID,
                configuration: configutaion
            )
        } else {
            Logger.common(message: "Mindbox Configuration has no changes", level: .info, category: .general)
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
        try? databaseRepository.erase()
        guaranteedDeliveryManager.cancelAllOperations()
        let newVersion = 0 // Variable from an older version of this framework
        persistenceStorage.deviceUUID = deviceUUID
        persistenceStorage.installationId = configuration.previousInstallationId
        persistenceStorage.imageLoadingMaxTimeInSeconds = configuration.imageLoadingMaxTimeInSeconds
        let apnsToken = persistenceStorage.apnsToken
        let isNotificationsEnabled = notificationStatus()
        let instanceId = UUID().uuidString
        self.databaseRepository.instanceId = instanceId
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
            self.trackDirect()
            try installEvent(encodable, config: configuration)
            persistenceStorage.isNotificationsEnabled = isNotificationsEnabled
            persistenceStorage.installationDate = Date()
            Logger.common(message: "MobileApplicationInstalled", level: .default, category: .general)
        } catch {
            Logger.common(message: "MobileApplicationInstalled failed with error: \(error.localizedDescription)", level: .error, category: .general)
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

    private func updateInfo(apnsToken: String?, isNotificationsEnabled: Bool) {
        let previousVersion = databaseRepository.infoUpdateVersion ?? 0
        let newVersion = previousVersion + 1
        let infoUpdated = MobileApplicationInfoUpdated(
            token: apnsToken,
            isNotificationsEnabled: isNotificationsEnabled,
            version: newVersion,
            instanceId: databaseRepository.instanceId ?? ""
        )
        let event = Event(
            type: .infoUpdated,
            body: BodyEncoder(encodable: infoUpdated).body
        )
        do {
            try databaseRepository.create(event: event)
            databaseRepository.infoUpdateVersion = newVersion
            Logger.common(message: "MobileApplicationInfoUpdated", level: .default, category: .general)
        } catch {
            Logger.common(message: "MobileApplicationInfoUpdated failed with error: \(error.localizedDescription)", level: .error, category: .general)
        }
    }

    private func trackDirect() {
        do {
            try trackVisitManager.trackDirect()
        } catch {
            Logger.common(message: "Track Visit failed with error: \(error)", level: .info, category: .visit)
        }
    }

    init(
        persistenceStorage: PersistenceStorage,
        utilitiesFetcher: UtilitiesFetcher,
        databaseRepository: MBDatabaseRepository,
        guaranteedDeliveryManager: GuaranteedDeliveryManager,
        trackVisitManager: TrackVisitManager,
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
        self.trackVisitManager = trackVisitManager
        self.uuidDebugService = uuidDebugService
        self.controllerQueue = controllerQueue
        self.inAppMessagesManager = inAppMessagesManager
        self.sessionManager = sessionManager
        self.userVisitManager = userVisitManager

        sessionManager.sessionHandler = { [weak self] isActive in
            if isActive && SessionTemporaryStorage.shared.isInitializationCalled {
                self?.checkNotificationStatus()
                self?.controllerQueue.async {
                    self?.userVisitManager.saveUserVisit()
                    self?.inAppMessagesManager.start()
                }
            }
        }
        
        let timer = DI.injectOrFail(TimerManager.self)
        timer.configurate(trackEvery: 20 * 60) {
            Logger.common(message: "Scheduled Time tracker started")
            sessionManager.trackForeground()
        }
        
        timer.setupTimer()
    }
}
