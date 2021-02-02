//
//  MBMobileApplicationRepository.swift
//  MindBox
//
//  Created by Maksim Kazachkov on 02.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

class MBMobileApplicationRepository: MobileApplicationRepository {
    
    private let fetcher: NetworkFetcher
    
    init(fetcher: NetworkFetcher) {
        self.fetcher = fetcher
    }
    
    func installed(
        endpoint: String,
        deviceUUID: String,
        installationId: String?,
        apnsToken: String?,
        isNotificationsEnabled: Bool,
        completion: @escaping Completion<BaseResponse>
    ) {
        let wrapper = MobileApplicationInstalledWrapper(
            query: MobileApplicationInstalledWrapper.Query(
                endpointId: endpoint,
                deviceUUID: deviceUUID
            ),
            body: MobileApplicationInstalledWrapper.Body(
                token: apnsToken ?? "",
                isTokenAvailable: apnsToken?.isEmpty == false,
                installationId: installationId ?? "",
                isNotificationsEnabled: isNotificationsEnabled
            )
        )
        fetcher.request(
            route: MobileApplicationRoute.installed(wrapper),
            completion: completion
        )
    }
    
    func infoUpdated(
        endpoint: String,
        deviceUUID: String,
        apnsToken: String?,
        isNotificationsEnabled: Bool,
        completion: @escaping Completion<BaseResponse>) {
        let wrapper = MobileApplicationInfoUpdatedWrapper(
            query: MobileApplicationInfoUpdatedWrapper.Query(
                endpointId: endpoint,
                deviceUUID: deviceUUID
            ),
            body: MobileApplicationInfoUpdatedWrapper.Body(
                token: apnsToken ?? "",
                isTokenAvailable: apnsToken?.isEmpty == false,
                isNotificationsEnabled: isNotificationsEnabled
            )
        )
        fetcher.request(
            route: MobileApplicationRoute.infoUpdated(wrapper),
            completion: completion
        )
    }
    
}
