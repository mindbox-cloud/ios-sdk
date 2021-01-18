//
//  MobileApplicationInstalledRequest.swift
//  MindBox
//
//  Created by Mikhail Barilov on 18.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

class MobileApplicationInstalledRequest: RequestModel {
    let operationPath = "/v3/operations/async"
    init(
        endpoint: String,
        deviceUUID: String,
        apnsToken: String?
    ) {
        let headers = APIServiceConstant.defaultHeaders
        let isTokenAvailable = apnsToken?.isEmpty == false
        super.init(path: operationPath,
                   method: .post,
                   parameters: [
                    "endpointId":endpoint,
                    "operation": "MobileApplicationInstalled",
                    "deviceUUID": deviceUUID
            ],
                   headers: headers,
                   body: [
                    "Token": apnsToken,
                    "IsTokenAvailable": isTokenAvailable
            ]
        )
    }
}
