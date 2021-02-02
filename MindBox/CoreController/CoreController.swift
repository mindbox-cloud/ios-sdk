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

    @Injected var logger: ILogger
    @Injected var configurationStorage: ConfigurationStorage
    @Injected var persistenceStorage: PersistenceStorage
    @Injected var mobileApplicationRepository: MobileApplicationRepository
    @Injected var utilitiesFetcher: UtilitiesFetcher

    // MARK: - Property
    
    var isInstalled: Bool {
        persistenceStorage.isInstalled
    }

    // MARK: - Init
    
    init() {
        
    }

    // MARK: - CoreController
    
    public func initialization(configuration: MBConfiguration) {
        configurationStorage.save(configuration: configuration)
        if isInstalled {
            updateToken()
        } else {
            startInstallationCase(uuid: configuration.deviceUUID, installationId: configuration.installationId)
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
        } else {
            utilitiesFetcher.getUDID { [weak self] (uuid) in
                self?.installation(uuid: uuid.uuidString, installationId: installationId)
                Log("Utilities.fetch.getIDFV fail")
                    .inChanel(.system).withType(.verbose).make()
            }
        }
    }

    private func updateToken() {
        let endpoint = configurationStorage.endpoint
        let apnsToken = persistenceStorage.apnsToken

        guard let deviceUUID = persistenceStorage.deviceUUID else {
            // TODO: - Throw error ?
            return
        }
        
        mobileApplicationRepository.infoUpdated(
            endpoint: endpoint,
            deviceUUID: deviceUUID,
            apnsToken: apnsToken,
            isNotificationsEnabled: false
        ) { (result) in
            switch result {
            case .success:
                MindBox.shared.delegate?.apnsTokenDidUpdated()
                Log("apnsTokenDidUpdated \(apnsToken ?? "")")
                    .inChanel(.system).withType(.verbose).make()
            case .failure(let error):
                Log("apnsTokenDidUpdated with \(error.localizedDescription )")
                    .inChanel(.system).withType(.verbose).make()
                MindBox.shared.delegate?.mindBoxInstalledFailed(error: error.asMBError )
            }
        }
    }

    private func installation(uuid: String, installationId: String?) {
        let endpoint = configurationStorage.endpoint
        let apnsToken = persistenceStorage.apnsToken

        mobileApplicationRepository.installed(
            endpoint: endpoint,
            deviceUUID: uuid,
            installationId: installationId,
            apnsToken: apnsToken,
            isNotificationsEnabled: false
        ) { [weak self] (result) in
            switch result {
            case .success(let response):
                self?.persistenceStorage.deviceUUID = uuid
                self?.persistenceStorage.installationId = installationId

                Log("apiServices.mobileApplicationInstalled status-code \(response.data?.httpStatusCode ?? -1), status \(response.data?.status ?? .unknow)")
                    .inChanel(.system).withType(.verbose).make()
                MindBox.shared.delegate?.mindBoxDidInstalled()
                break

            case .failure(let error):
                MindBox.shared.delegate?.mindBoxInstalledFailed(error: error.asMBError )
                break
            }
        }
    }

}
