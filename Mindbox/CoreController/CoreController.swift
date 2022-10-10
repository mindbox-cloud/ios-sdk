//
//  CoreController.swift
//  Mindbox
//
//  Created by Mikhail Barilov on 13.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import UIKit

class CoreController {
    private let persistenceStorage: PersistenceStorage
    private let utilitiesFetcher: UtilitiesFetcher
    private let notificationStatusProvider: UNAuthorizationStatusProviding
    private let databaseRepository: MBDatabaseRepository
    private let guaranteedDeliveryManager: GuaranteedDeliveryManager
    private let trackVisitManager: TrackVisitManager
    private var configValidation = ConfigValidation()

    private let controllerQueue = DispatchQueue(label: "com.Mindbox.controllerQueue")

    func initialization(configuration: MBConfiguration) {
        controllerQueue.async {
            self.configValidation.compare(configuration, self.persistenceStorage.configuration)
            self.persistenceStorage.configuration = configuration
            if !self.persistenceStorage.isInstalled {
                self.primaryInitialization(with: configuration)
            } else {
                self.repeatInitialization(with: configuration)
            }
            self.guaranteedDeliveryManager.canScheduleOperations = true
        }
    }

    func apnsTokenDidUpdate(token: String) {
        controllerQueue.async {
            let isNotificationsEnabled = self.notificationStatus()
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
        Log("It took \(CFAbsoluteTimeGetCurrent() - start) seconds to generate deviceUUID")
            .category(.general).level(.debug).make()
        return deviceUUID!
    }

    private func primaryInitialization(with configutaion: MBConfiguration) {
        // May take up to 3 sec, see utilitiesFetcher.getDeviceUUID implementation
        let deviceUUID = generateDeviceUUID()
        install(
            deviceUUID: deviceUUID,
            configuration: configutaion
        )
    }

    private func repeatInitialization(with configutaion: MBConfiguration) {
        guard let deviceUUID = persistenceStorage.deviceUUID else {
            Log("Unable to find deviceUUID in persistenceStorage")
                .category(.general).level(.error).make()
            return
        }
        
        if configValidation.changedState != .none {
            install(
                deviceUUID: deviceUUID,
                configuration: configutaion
            )
        } else {
            checkNotificationStatus()
            persistenceStorage.configuration?.previousDeviceUUID = deviceUUID
        }
    }

    private func install(deviceUUID: String, configuration: MBConfiguration) {
        try? databaseRepository.erase()
        guaranteedDeliveryManager.cancelAllOperations()
        let newVersion = 0 // Variable from an older version of this framework
        persistenceStorage.deviceUUID = deviceUUID
        persistenceStorage.installationId = configuration.previousInstallationId
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
            Log("MobileApplicationInstalled")
                .category(.general).level(.default).make()
        } catch {
            Log("MobileApplicationInstalled failed with error: \(error.localizedDescription)")
                .category(.general).level(.error).make()
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
            Log("MobileApplicationInfoUpdated")
                .category(.general).level(.default).make()
        } catch {
            Log("MobileApplicationInfoUpdated failed with error: \(error.localizedDescription)")
                .category(.general).level(.error).make()
        }
    }

    private func trackDirect() {
        do {
            try trackVisitManager.trackDirect()
        } catch {
            Log("Track Visit failed with error: \(error)")
                .category(.visit).level(.info).make()
        }
    }

    init(
        persistenceStorage: PersistenceStorage,
        utilitiesFetcher: UtilitiesFetcher,
        notificationStatusProvider: UNAuthorizationStatusProviding,
        databaseRepository: MBDatabaseRepository,
        guaranteedDeliveryManager: GuaranteedDeliveryManager,
        trackVisitManager: TrackVisitManager,
        sessionManager: SessionManager
    ) {
        self.persistenceStorage = persistenceStorage
        self.utilitiesFetcher = utilitiesFetcher
        self.notificationStatusProvider = notificationStatusProvider
        self.databaseRepository = databaseRepository
        self.guaranteedDeliveryManager = guaranteedDeliveryManager
        self.trackVisitManager = trackVisitManager

        sessionManager.sessionHandler = { [weak self] isActive in
            if isActive {
                self?.checkNotificationStatus()
            }
        }

        TimerManager.shared.configurate(trackEvery: 20 * 60) {
            sessionManager.trackForeground()
        }
        TimerManager.shared.setupTimer()
    }
}
