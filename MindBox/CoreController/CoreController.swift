//
//  CoreController.swift
//  MindBox
//
//  Created by Mikhail Barilov on 13.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import UIKit

class CoreController {
    
    @Injected var persistenceStorage: PersistenceStorage
    @Injected var utilitiesFetcher: UtilitiesFetcher
    @Injected var notificationStatusProvider: UNAuthorizationStatusProviding
    @Injected var databaseRepository: MBDatabaseRepository
    @Injected var guaranteedDeliveryManager: GuaranteedDeliveryManager
    
    func initialization(configuration: MBConfiguration) {
        persistenceStorage.configuration = configuration
        if !persistenceStorage.isInstalled {
            primaryInitialization(with: configuration)
        } else {
            repeatedInitialization()
        }
        guaranteedDeliveryManager.canScheduleOperations = true
    }
    
    func apnsTokenDidUpdate(token: String) {
        let isNotificationsEnabled = notificationStatusProvider.isNotificationsEnabled()
        if persistenceStorage.isInstalled {
            infoUpdated(
                apnsToken: token,
                isNotificationsEnabled: isNotificationsEnabled
            )
        }
        persistenceStorage.apnsToken = token
        persistenceStorage.isNotificationsEnabled = isNotificationsEnabled
    }
    
    func checkNotificationStatus() {
        let isNotificationsEnabled = notificationStatusProvider.isNotificationsEnabled()
        guard let isPersistentNotificationsEnabled = persistenceStorage.isNotificationsEnabled else {
            infoUpdated(
                apnsToken: persistenceStorage.apnsToken,
                isNotificationsEnabled: notificationStatusProvider.isNotificationsEnabled()
            )
            persistenceStorage.isNotificationsEnabled = isNotificationsEnabled
            return
        }
        guard isPersistentNotificationsEnabled != isNotificationsEnabled else {
            return
        }
        persistenceStorage.isNotificationsEnabled = isNotificationsEnabled
        infoUpdated(
            apnsToken: persistenceStorage.apnsToken,
            isNotificationsEnabled: notificationStatusProvider.isNotificationsEnabled()
        )
    }
    
    // MARK: - Private
    private func primaryInitialization(with configutaion: MBConfiguration) {
        let deviceUUID = configutaion.deviceUUID ?? utilitiesFetcher.getDeviceUUID()
        installed(
            deviceUUID: deviceUUID,
            installationId: configutaion.installationId,
            subscribe: configutaion.subscribeCustomerIfCreated
        )
    }
    
    private func repeatedInitialization() {
        guard let deviceUUID = persistenceStorage.deviceUUID else {
            Log("Unable to find deviceUUID in persistenceStorage")
                .inChanel(.system).withType(.error).make()
            return
        }
        persistenceStorage.configuration?.deviceUUID = deviceUUID
    }
    
    private func installed(deviceUUID: String, installationId: String?, subscribe: Bool) {
        persistenceStorage.deviceUUID = deviceUUID
        persistenceStorage.installationId = installationId
        let apnsToken = persistenceStorage.apnsToken
        let isNotificationsEnabled = notificationStatusProvider.isNotificationsEnabled()
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
            try databaseRepository.create(event: event)
            persistenceStorage.isNotificationsEnabled = isNotificationsEnabled
            persistenceStorage.installationDate = Date()
            Log("MobileApplicationInstalled")
                .inChanel(.system).withType(.verbose).make()
        } catch {
            Log("MobileApplicationInstalled failed with error: \(error.localizedDescription)")
                .inChanel(.system).withType(.error).make()
        }
        
    }
    
    private func infoUpdated(apnsToken: String?, isNotificationsEnabled: Bool) {
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
                .inChanel(.system).withType(.verbose).make()
        } catch {
            Log("MobileApplicationInfoUpdated failed with error: \(error.localizedDescription)")
                .inChanel(.system).withType(.error).make()
        }
    }
    
}
