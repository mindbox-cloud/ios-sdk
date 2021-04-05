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
    
    func initialization(configuration: MBConfiguration) {
        persistenceStorage.configuration = configuration
        if !persistenceStorage.isInstalled {
            primaryInitialization(with: configuration)
        } else {
            repeatInitialization()
        }
        guaranteedDeliveryManager.canScheduleOperations = true
    }
    
    func apnsTokenDidUpdate(token: String) {
        notificationStatusProvider.getStatus { [weak self] isNotificationsEnabled in
            guard let self = self else { return }
            if self.persistenceStorage.isInstalled {
                self.updateInfo(
                    apnsToken: token,
                    isNotificationsEnabled: isNotificationsEnabled
                )
                self.persistenceStorage.isNotificationsEnabled = isNotificationsEnabled
            }
        }
        persistenceStorage.apnsToken = token
    }
    
    func checkNotificationStatus(granted: Bool? = nil) {
        notificationStatusProvider.getStatus { [weak self] isNotificationsEnabled in
            guard let self = self else { return }
            let isNotificationsEnabled = granted ?? isNotificationsEnabled
            guard self.persistenceStorage.isNotificationsEnabled != isNotificationsEnabled else {
                return
            }
            if self.persistenceStorage.isInstalled {
                self.updateInfo(
                    apnsToken: self.persistenceStorage.apnsToken,
                    isNotificationsEnabled: isNotificationsEnabled
                )
                self.persistenceStorage.isNotificationsEnabled = isNotificationsEnabled
            }
        }
    }
    
    // MARK: - Private
    private func primaryInitialization(with configutaion: MBConfiguration) {
        utilitiesFetcher.getDeviceUUID(completion: { [self] (deviceUUID) in
            install(
                deviceUUID: deviceUUID,
                configuration: configutaion
            )
        })
    }
    
    private func repeatInitialization() {
        guard let deviceUUID = persistenceStorage.deviceUUID else {
            Log("Unable to find deviceUUID in persistenceStorage")
                .category(.general).level(.error).make()
            return
        }
        persistenceStorage.configuration?.deviceUUID = deviceUUID
        checkNotificationStatus()
    }
    
    private func install(deviceUUID: String, configuration: MBConfiguration) {
        persistenceStorage.deviceUUID = deviceUUID
        persistenceStorage.installationId = configuration.installationId
        let apnsToken = persistenceStorage.apnsToken
        notificationStatusProvider.getStatus { [weak self] (isNotificationsEnabled) in
            guard let self = self else { return }
            let encodable = MobileApplicationInstalled(
                token: apnsToken,
                isNotificationsEnabled: isNotificationsEnabled,
                installationId: configuration.installationId,
                subscribe: configuration.subscribeCustomerIfCreated,
                lastDeviceUuid: configuration.deviceUUID
            )
            let body = BodyEncoder(encodable: encodable).body
            let event = Event(
                type: .installed,
                body: body
            )
            do {
                try self.databaseRepository.create(event: event)
                self.persistenceStorage.isNotificationsEnabled = isNotificationsEnabled
                self.persistenceStorage.installationDate = Date()
                Log("MobileApplicationInstalled")
                    .category(.general).level(.default).make()
            } catch {
                Log("MobileApplicationInstalled failed with error: \(error.localizedDescription)")
                    .category(.general).level(.error).make()
            }
        }
    }
    
    private func updateInfo(apnsToken: String?, isNotificationsEnabled: Bool) {
        let infoUpdated = MobileApplicationInfoUpdated(
            token: apnsToken,
            isNotificationsEnabled: isNotificationsEnabled
        )
        let event = Event(
            type: .infoUpdated,
            body: BodyEncoder(encodable: infoUpdated).body
        )
        do {
            try databaseRepository.create(event: event)
            Log("MobileApplicationInfoUpdated")
                .category(.general).level(.default).make()
        } catch {
            Log("MobileApplicationInfoUpdated failed with error: \(error.localizedDescription)")
                .category(.general).level(.error).make()
        }
    }
    
    init(
        persistenceStorage: PersistenceStorage,
        utilitiesFetcher: UtilitiesFetcher,
        notificationStatusProvider: UNAuthorizationStatusProviding,
        databaseRepository: MBDatabaseRepository,
        guaranteedDeliveryManager: GuaranteedDeliveryManager) {
        self.persistenceStorage = persistenceStorage
        self.utilitiesFetcher = utilitiesFetcher
        self.notificationStatusProvider = notificationStatusProvider
        self.databaseRepository = databaseRepository
        self.guaranteedDeliveryManager = guaranteedDeliveryManager
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: nil) { [weak self] (_) in
            Log("UIApplication.didBecomeActiveNotification")
                .category(.general).level(.info).make()
            self?.checkNotificationStatus()
        }
    }
    
}
