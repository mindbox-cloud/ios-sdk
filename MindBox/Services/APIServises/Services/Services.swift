//
//  MindBox.swift
//  MindBox
//
//  Created by Mikhail Barilov on 12.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

protocol IMindBoxAPIService: class {
//    func avgPrice(symbol: String, completion: @escaping(Swift.Result<AveragePriceResponseModel, ErrorModel>) -> Void)
}

class MindBoxAPIServicesProvider: IMindBoxAPIService {

    var serviceManager: APIService

    init(serviceManager: APIService) {
        self.serviceManager = serviceManager
    }

    ///MobileApplicationInstalled
    func mobileApplicationInstalled(endpoint: String, deviceUUID: String, completion: @escaping(Swift.Result<BaseResponce, ErrorModel>) -> Void) {
        let req = MobileApplicationInstalledRequest(endpoint: "", deviceUUID: "", apnsToken: nil)
        serviceManager.sendRequest(request: req) { (result) in
            completion(result)
        }
    }
}
