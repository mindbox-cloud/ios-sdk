//
//  CoreController.swift
//  MindBox
//
//  Created by Mikhail Barilov on 13.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import UIKit
import AdSupport
import AppTrackingTransparency

class CoreController {
    
    @Injected var configurationStorage: ConfigurationStorage
    @Injected var persistenceStorage: PersistenceStorage
    @Injected var utilitiesFetcher: UtilitiesFetcher
    @Injected var notificationStatusProvider: UNAuthorizationStatusProviding
    @Injected var databaseRepository: MBDatabaseRepository
    @Injected var guaranteedDeliveryManager: GuaranteedDeliveryManager
    
    init() {
        if persistenceStorage.isInstalled {
            checkNotificationStatus()
        }
    }
    
    func initialization(configuration: MBConfiguration) {
        configurationStorage.setConfiguration(configuration)
        if !persistenceStorage.isInstalled {
            primaryInitialization(with: configuration)
        } else {
            repeatedInitialization()
        }
        guaranteedDeliveryManager.canScheduleOperations = true
    }
    
    func apnsTokenDidUpdate(token: String) {
        if let persistenceAPNSToken = persistenceStorage.apnsToken {
            guard persistenceAPNSToken != token else {
                return
            }
            // Before send infoUpdated need to check that sdk is installed
            if persistenceStorage.isInstalled {
                infoUpdated(with: token)
            }
            persistenceStorage.apnsToken = token
        } else {
            // Before send infoUpdated need to check that sdk is installed
            if persistenceStorage.isInstalled {
                infoUpdated(with: token)
            }
            persistenceStorage.apnsToken = token
        }
    }
    
    func checkNotificationStatus() {
        notificationStatusProvider.isAuthorized { [weak self] isNotificationsEnabled in
            guard let self = self else {
                return
            }
            guard let isPersistentNotificationsEnabled = self.persistenceStorage.isNotificationsEnabled else {
                self.infoUpdated(with: isNotificationsEnabled)
                self.persistenceStorage.isNotificationsEnabled = isNotificationsEnabled
                return
            }
            guard isPersistentNotificationsEnabled != isNotificationsEnabled else {
                return
            }
            self.infoUpdated(with: isNotificationsEnabled)
            self.persistenceStorage.isNotificationsEnabled = isNotificationsEnabled
        }
    }
    
    // MARK: - Private
    private func primaryInitialization(with configutaion: MBConfiguration) {
        persistenceStorage.configuration = configutaion
        if let deviceUUID = configutaion.deviceUUID {
            installed(deviceUUID: deviceUUID, installationId: configutaion.installationId)
            Log("Configuration deviceUUID:\(deviceUUID)")
                .inChanel(.system).withType(.verbose).make()
        } else {
            utilitiesFetcher.getDeviceUUID { [weak self] (deviceUUID) in
                self?.configurationStorage.set(deviceUUID: deviceUUID.uuidString)
                self?.installed(deviceUUID: deviceUUID.uuidString, installationId: configutaion.installationId)
            }
        }
    }
    
    private func repeatedInitialization() {
        guard let deviceUUID = persistenceStorage.deviceUUID else {
            Log("Unable to find deviceUUID in persistenceStorage")
                .inChanel(.system).withType(.error).make()
            return
        }
        configurationStorage.set(deviceUUID: deviceUUID)
        persistenceStorage.configuration = configurationStorage.configuration
    }
    
    private func installed(deviceUUID: String, installationId: String?) {
        persistenceStorage.deviceUUID = deviceUUID
        persistenceStorage.installationId = installationId
        let apnsToken = persistenceStorage.apnsToken
        let subscribe = configurationStorage.configuration?.subscribeCustomerIfCreated ?? false
        notificationStatusProvider.isAuthorized { [weak self] (isNotificationsEnabled) in
            guard let self = self else {
                return
            }
            let installed = MobileApplicationInstalled(
                token: apnsToken,
                isNotificationsEnabled: isNotificationsEnabled,
                installationId: installationId,
                subscribe: subscribe
            )
            let body = BodyEncoder(encodable: installed).body
            let event = Event(
                type: .installed,
                body: body
            )
            do {
                try self.databaseRepository.create(event: event)
                self.persistenceStorage.isNotificationsEnabled = isNotificationsEnabled
                self.persistenceStorage.installationDate = Date()
                Log("MobileApplicationInstalled")
                    .inChanel(.system).withType(.verbose).make()
                MindBox.shared.delegate?.mindBoxDidInstalled()
            } catch {
                Log("MobileApplicationInstalled failed with error: \(error.localizedDescription)")
                    .inChanel(.system).withType(.error).make()
            }
        }
        
    }
    
    private func infoUpdated(with apnsToken: String) {
        let apnsToken = persistenceStorage.apnsToken
        let isNotificationsEnabled = persistenceStorage.isNotificationsEnabled ?? false
        let infoUpdated = MobileApplicationInfoUpdated(
            token: apnsToken,
            isNotificationsEnabled: isNotificationsEnabled
        )
        let event = Event(
            type: .infoUpdated,
            body: BodyEncoder(encodable: infoUpdated).body
        )
        try? databaseRepository.create(event: event)
    }
    
    private func infoUpdated(with isNotificationsEnabled: Bool) {
        let apnsToken = persistenceStorage.apnsToken
        let infoUpdated = MobileApplicationInfoUpdated(
            token: apnsToken,
            isNotificationsEnabled: isNotificationsEnabled
        )
        let event = Event(
            type: .infoUpdated,
            body: BodyEncoder(encodable: infoUpdated).body
        )
        try? databaseRepository.create(event: event)
    }
    
}
