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
    @Injected var mobileApplicationRepository: MobileApplicationRepository
    @Injected var utilitiesFetcher: UtilitiesFetcher

    // MARK: - Property
    
    var isInstalled: Bool = false

    // MARK: - Init
    
    init() {
        self.isInstalled = self.persistenceStorage.isInstalled
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
        mobileApplicationRepository.infoUpdated(
            apnsToken: apnsToken,
            isNotificationsEnabled: false
        ) { (result) in
            switch result {
            case .success:
                MindBox.shared.delegate?.apnsTokenDidUpdated()
                Log("apnsTokenDidUpdated \(apnsToken ?? "")")
                    .inChanel(.system).withType(.verbose).make()
            case .failure(let error):
                Log("apnsTokenDidUpdated failed with error: \(error.localizedDescription )")
                    .inChanel(.system).withType(.verbose).make()
                MindBox.shared.delegate?.mindBoxInstalledFailed(error: error.asMBError )
            }
        }
    }

    private func installation(uuid: String, installationId: String?) {
        let apnsToken = persistenceStorage.apnsToken
        mobileApplicationRepository.installed(
            installationId: installationId,
            apnsToken: apnsToken,
            isNotificationsEnabled: false
        ) { [weak self] (result) in
            switch result {
            case .success(let response):
                self?.persistenceStorage.deviceUUID = uuid
                self?.persistenceStorage.installationId = installationId
                self?.isInstalled = true
                Log("apiServices.mobileApplicationInstalled status-code \(response.data?.httpStatusCode ?? -1), status \(response.data?.status ?? .unknow)")
                    .inChanel(.system).withType(.verbose).make()
                MindBox.shared.delegate?.mindBoxDidInstalled()
            case .failure(let error):
                MindBox.shared.delegate?.mindBoxInstalledFailed(error: error.asMBError )
            }
        }
    }

}
