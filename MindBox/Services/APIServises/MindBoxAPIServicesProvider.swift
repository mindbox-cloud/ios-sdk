//
//  MindBox.swift
//  MindBox
//
//  Created by Mikhail Barilov on 12.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

protocol IMindBoxAPIService: class {
    func mobileApplicationInstalled(
        endpoint: String,
        deviceUUID: String,
        installationId: String,
        completion: @escaping(Swift.Result<BaseResponce, ErrorModel>) -> Void)
}

class MindBoxAPIServicesProvider: IMindBoxAPIService {

    var serviceManager: APIService

    init(serviceManager: APIService) {
        self.serviceManager = serviceManager
    }

    /// MobileApplicationInstalled
    func mobileApplicationInstalled(
        endpoint: String,
        deviceUUID: String,
        installationId: String,
        completion: @escaping(Swift.Result<BaseResponce, ErrorModel>) -> Void)
    {
        let req = MobileApplicationInstalledRequest(endpoint: "", deviceUUID: "", installationId: nil, apnsToken: nil)
        serviceManager.sendRequest(request: req) { (result) in
            completion(result)
        }
    }

    /// MobileApplicationInfoUpdated
    func mobileApplicationInfoUpdated(
        endpoint: String,
        deviceUUID: String,
        completion: @escaping(Swift.Result<BaseResponce, ErrorModel>) -> Void)
    {
        let req = MobileApplicationInfoUpdatedRequest(endpoint: "", deviceUUID: "", apnsToken: nil)
        serviceManager.sendRequest(request: req) { (result) in
            completion(result)
        }
    }
}
