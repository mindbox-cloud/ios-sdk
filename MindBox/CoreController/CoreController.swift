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
    
    // MARK: - Elements
    
    @Injected var configurationStorage: ConfigurationStorage
    @Injected var persistenceStorage: PersistenceStorage
    @Injected var utilitiesFetcher: UtilitiesFetcher
    @Injected var notificationStatusProvider: UNAuthorizationStatusProviding
    @Injected var databaseRepository: MBDatabaseRepository
    @Injected var guaranteedDeliveryManager: GuaranteedDeliveryManager
    
    // MARK: - Property
    
    var isInstalled: Bool = false
    
    // MARK: - Init
    
    init() {
        self.isInstalled = self.persistenceStorage.isInstalled
        guaranteedDeliveryManager.onCompletedEvent = { [weak self] (event, error) in
            self?.proceed(result: (event, error))
        }
    }
    
    // MARK: - CoreController
    
    public func initialization(configuration: MBConfiguration) {
        configurationStorage.setConfiguration(configuration)
        if isInstalled {
            if configurationStorage.configuration?.deviceUUID == nil, let deviceUUID = persistenceStorage.deviceUUID {
                configurationStorage.set(uuid: deviceUUID)
            }
            updateToken()
        } else {
            startInstallationCase(
                uuid: configuration.deviceUUID,
                installationId: configuration.installationId
            )
        }
    }
    public func apnsTokenDidUpdate(token: String) {
        persistenceStorage.apnsToken = token
        if isInstalled {
            updateToken()
        }
    }
    
    // MARK: - Private
    
    private func startInstallationCase(uuid: String?, installationId: String?) {
        if let uuid = uuid {
            installation(uuid: uuid, installationId: installationId)
            Log("Configuration uuid:\(uuid)")
                .inChanel(.system).withType(.verbose).make()
        } else {
            utilitiesFetcher.getUDID { [weak self] (uuid) in
                self?.configurationStorage.set(uuid: uuid.uuidString)
                self?.installation(uuid: uuid.uuidString, installationId: installationId)
            }
        }
    }
    
    private func updateToken() {
        let apnsToken = persistenceStorage.apnsToken
        notificationStatusProvider.isAuthorized { [weak self] isNotificationsEnabled in
            let infoUpdated = MobileApplicationInfoUpdated(
                token: apnsToken ?? "",
                isNotificationsEnabled: isNotificationsEnabled
            )
            let event = Event(
                transactionId: UUID().uuidString,
                enqueueTimeStamp: Date().timeIntervalSince1970,
                type: .infoUpdated,
                body: BodyEncoder(encodable: infoUpdated).body
            )
            try? self?.databaseRepository.create(event: event)
        }
    }
    
    private func installation(uuid: String, installationId: String?) {
        let apnsToken = persistenceStorage.apnsToken
        notificationStatusProvider.isAuthorized { [weak self] isNotificationsEnabled in
            let installed = MobileApplicationInstalled(
                token: apnsToken ?? "",
                isNotificationsEnabled: isNotificationsEnabled,
                installationId: installationId ?? ""
            )
            let event = Event(
                transactionId: UUID().uuidString,
                enqueueTimeStamp: Date().timeIntervalSince1970,
                type: .installed,
                body: BodyEncoder(encodable: installed).body
            )
            try? self?.databaseRepository.create(event: event)
        }
    }
    
    private func proceed(result: (event: Event, error: ErrorModel?)) {
        switch result.event.type {
        case .installed:
            if let error = result.error {
                MindBox.shared.delegate?.mindBoxInstalledFailed(error: error.asMBError)
            } else {
                isInstalled = true
                if let decoder = BodyDecoder<MobileApplicationInstalled>(decodable: result.event.body) {
                    persistenceStorage.deviceUUID = configurationStorage.configuration?.deviceUUID
                    persistenceStorage.installationId = decoder.body.installationId
                }
                Log("MobileApplicationInstalled")
                    .inChanel(.system).withType(.verbose).make()
                MindBox.shared.delegate?.mindBoxDidInstalled()
            }
        case .infoUpdated:
            if let error = result.error {
                MindBox.shared.delegate?.mindBoxInstalledFailed(error: error.asMBError)
            } else {
                Log("apnsTokenDidUpdate")
                    .inChanel(.system).withType(.verbose).make()
                MindBox.shared.delegate?.apnsTokenDidUpdated()
            }
        }
    }
    
}
