//
//  MindBox.swift
//  MindBox
//
//  Created by Mikhail Barilov on 12.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

protocol IMindBoxAPIServices: class {
//    func avgPrice(symbol: String, completion: @escaping(Swift.Result<AveragePriceResponseModel, ErrorModel>) -> Void)
}

class MindBoxAPIServicesProvider: IMindBoxAPIServices {

    var serviceManager: APIServiceManager

    init(serviceManager: APIServiceManager) {
        self.serviceManager = serviceManager
    }

    ///MobileApplicationInstalled
    func mobileApplicationInstalled(endpoint: String, deviceUUID: String, completion: @escaping(Swift.Result<BaseResponce, ErrorModel>) -> Void) {
		let req = MobileApplicationInstalledRequest(endpoint: "", deviceUUID: "")
        serviceManager.sendRequest(request: req) { (result) in
            completion(result)
        }
    }
}
