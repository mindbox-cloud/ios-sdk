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
    enum State {
        case none
        case initing
        case wasInstalled
        case ready
    }

    // MARK: - Elements

    @Injected var logger: ILogger
    @Injected var configurationStorage: IConfigurationStorage
    @Injected var persistenceStorage: IPersistenceStorage
    @Injected var apiServices: IMindBoxAPIService

    // MARK: - Property

    private var state: State = .none

    // MARK: - Init

    init() {

        if persistenceStorage.wasInstaled {
            state = .wasInstalled
        }
    }

    // MARK: - CoreController

    public func initialization(configuration: MBConfiguration) {
        configurationStorage.save(configuration: configuration)
        switch state {
        case .none:
            state = .initing
            startInstallationCase(uuid: configuration.deviceUUID, installationId: configuration.installationId)
        default:
            updateToken()
        }
    }

    // MARK: - Private

    private func startInstallationCase(uuid: String?, installationId: String?) {

        if let uuid = uuid {
            self.installation(uuid: uuid, installationId: installationId)
        } else {
            Utilities.fetch.getIDFA { (idfa) in
                print("idfa get success \(idfa)")
                self.installation(uuid: idfa.uuidString, installationId: installationId)
            } onFail: {
                if #available(iOS 14, *) {
                    print("idfa get fail \(ATTrackingManager.trackingAuthorizationStatus.rawValue)")
                } else {
                    print("idfa get fail")
                }
                Utilities.fetch.getIDFV(
                    tryCount: 5) { (idfv) in
                    self.installation(uuid: idfv.uuidString, installationId: installationId)
                    print(" Utilities.fetch.getIDFV \(idfv.uuidString)")
                } onFail: {
                    print("Utilities.fetch.getIDFV fail")
                }
            }
        }
    }

    private func updateToken() {
        let endpoint = configurationStorage.endpoint
        let apnsToken = persistenceStorage.apnsToken

        guard let deviceUUID = persistenceStorage.deviceUUID else {
            // FIX:
            return
        }

        apiServices.mobileApplicationInfoUpdated(endpoint: endpoint, deviceUUID: deviceUUID, apnsToken: apnsToken) { (result) in
            switch result {
            case .success:
                MindBox.shared.delegate?.apnsTokenDidUpdated()
            case .failure:
                break
            }
        }
    }

    private func installation(uuid: String, installationId: String?) {
        let endpoint = configurationStorage.endpoint

        let apnsToken = persistenceStorage.deviceUUID

        apiServices.mobileApplicationInstalled(endpoint: endpoint, deviceUUID: uuid, installationId: installationId, apnsToken: apnsToken, completion: {[weak self] result in
                switch result {
                case .success(let resp):
               	 	self?.state = .wasInstalled
                    self?.persistenceStorage.deviceUUID = uuid
                    self?.persistenceStorage.installationId = installationId

                    print(" apiServices.mobileApplicationInstalled status-code \(resp.data?.httpStatusCode ?? -1), status \(resp.data?.status)")

                    MindBox.shared.delegate?.mindBoxDidInstalled()
                    break
                    
                case .failure(let error):
                    self?.state = .none
                    MindBox.shared.delegate?.mindBoxInstalledFailed(error: MindBox.Errors.other(errorDescription: " apiServices.mobileApplicationInstalled network fail", failureReason: error.localizedDescription, recoverySuggestion: nil))
                    break
                }
            }
        )
    }

}
