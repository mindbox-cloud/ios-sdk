//
//  MBMobileApplicationRepository.swift
//  MindBox
//
//  Created by Maksim Kazachkov on 02.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

class MBMobileApplicationRepository: MobileApplicationRepository {
    
    @Injected var fetcher: NetworkFetcher
    
    @Injected var configurationStorage: ConfigurationStorage
        
    func installed(
        installationId: String?,
        apnsToken: String?,
        isNotificationsEnabled: Bool,
        completion: @escaping Completion<BaseResponse>
    ) {
        guard let configuration = configurationStorage.configuration else {
            let error = ErrorModel(
                errorKey: ErrorKey.configuration.rawValue,
                rawError: MindBox.Errors.invalidConfiguration(reason: "Configuration is not set")
            )
            completion(.failure(error))
            return
        }
        guard let deviceUUID = configuration.deviceUUID else {
            let error = ErrorModel(
                errorKey: ErrorKey.configuration.rawValue,
                rawError: MindBox.Errors.invalidConfiguration(reason: "DeviceUUID is not set")
            )
            completion(.failure(error))
            return
        }
        let wrapper = MobileApplicationInstalledWrapper(
            endpointId: configuration.endpoint,
            deviceUUID: deviceUUID,
            body: MobileApplicationInstalledWrapper.Body(
                token: apnsToken ?? "",
                isTokenAvailable: apnsToken?.isEmpty == false,
                isNotificationsEnabled: isNotificationsEnabled,
                installationId: installationId ?? ""
            )
        )
        fetcher.requestObject(
            route: MobileApplicationRoute.installed(wrapper),
            completion: completion
        )
    }
    
    func infoUpdated(
        apnsToken: String?,
        isNotificationsEnabled: Bool,
        completion: @escaping Completion<BaseResponse>) {
        guard let configuration = configurationStorage.configuration else {
            let error = ErrorModel(
                errorKey: ErrorKey.configuration.rawValue,
                rawError: MindBox.Errors.invalidConfiguration(reason: "Configuration is not set")
            )
            completion(.failure(error))
            return
        }
        guard let deviceUUID = configuration.deviceUUID else {
            let error = ErrorModel(
                errorKey: ErrorKey.configuration.rawValue,
                rawError: MindBox.Errors.invalidConfiguration(reason: "DeviceUUID is not set")
            )
            completion(.failure(error))
            return
        }
        let wrapper = MobileApplicationInfoUpdatedWrapper(
            endpointId: configuration.endpoint,
            deviceUUID: deviceUUID,
            body: MobileApplicationInfoUpdatedWrapper.Body(
                token: apnsToken ?? "",
                isTokenAvailable: apnsToken?.isEmpty == false,
                isNotificationsEnabled: isNotificationsEnabled
            )
        )
        fetcher.requestObject(
            route: MobileApplicationRoute.infoUpdated(wrapper),
            completion: completion
        )
    }
    
}
