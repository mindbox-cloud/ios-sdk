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
            startInstallationCase(uuid: configuration.deviceUUID, installationId: configuration.installationId)
        default:
            updateToken()
        }
    }
    public func apnsTokenDidUpdate(token: String) {
        persistenceStorage.apnsToken = token

        switch state {
        case .none:
            print()
            break
        case .initing:
            print()
            break
        case .ready:
            print()
            break
        case .wasInstalled:
            updateToken()
            print()
            break
        }
    }

    // MARK: - Private

    private func startInstallationCase(uuid: String?, installationId: String?) {

        if let uuid = uuid {
            self.installation(uuid: uuid, installationId: installationId)
        } else {
            Utilities.fetch.getIDFA { (idfa) in
                Log("idfa get success \(idfa)")
                    .inChanel(.system).withType(.verbose).make()


                self.installation(uuid: idfa.uuidString, installationId: installationId)
            } onFail: {
//                if #available(iOS 14, *) {
//                    Log("idfa get fail \(ATTrackingManager.trackingAuthorizationStatus.rawValue)")
//                        .inChanel(.system).withType(.verbose).make()
//                } else {
//                    Log("idfa get fail")
//                        .inChanel(.system).withType(.verbose).make()
//                }
                Utilities.fetch.getIDFV(
                    tryCount: 5) { (idfv) in
                    self.installation(uuid: idfv.uuidString, installationId: installationId)
                    Log("Utilities.fetch.getIDFV \(idfv.uuidString)")
                        .inChanel(.system).withType(.verbose).make()

                } onFail: {
                    self.installation(uuid: UUID().uuidString, installationId: installationId)
                    
                    Log("Utilities.fetch.getIDFV fail")
                        .inChanel(.system).withType(.verbose).make()
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
                Log("apnsTokenDidUpdated \(apnsToken ?? "")")
                    .inChanel(.system).withType(.verbose).make()
            case .failure(let error):
                Log("apnsTokenDidUpdated with \(error.localizedDescription )")
                    .inChanel(.system).withType(.verbose).make()
                MindBox.shared.delegate?.mindBoxInstalledFailed(error: error.asMBError )
                break
            }
        }
    }

    private func installation(uuid: String, installationId: String?) {
        let endpoint = configurationStorage.endpoint

        let apnsToken = persistenceStorage.apnsToken

        state = .initing

        apiServices.mobileApplicationInstalled(endpoint: endpoint, deviceUUID: uuid, installationId: installationId, apnsToken: apnsToken, completion: {[weak self] result in
            switch result {
            case .success(let resp):
                self?.state = .wasInstalled
                self?.persistenceStorage.deviceUUID = uuid
                self?.persistenceStorage.installationId = installationId

                Log("apiServices.mobileApplicationInstalled status-code \(resp.data?.httpStatusCode ?? -1), status \(resp.data?.status ?? .unknow)")
                    .inChanel(.system).withType(.verbose).make()
                MindBox.shared.delegate?.mindBoxDidInstalled()
                break

            case .failure(let error):
                self?.state = .none
                MindBox.shared.delegate?.mindBoxInstalledFailed(error: error.asMBError )
                MindBox.shared.delegate?.mindBoxInstalledFailed(error: MindBox.Errors.other(errorDescription: " apiServices.mobileApplicationInstalled network fail", failureReason: error.localizedDescription, recoverySuggestion: nil))
                break
            }
        }
        )
    }

}
