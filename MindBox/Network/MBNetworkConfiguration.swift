//
//  MBNetworkConfguration.swift
//  MindBox
//
//  Created by Maksim Kazachkov on 02.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import UIKit

struct MBNetworkConfiguration: NetworkConfiguration {
    
    var baseURL: URL
    
    var cachePolicy: URLRequest.CachePolicy
    
    var timeoutInterval: TimeInterval
    
    var additionalHeaders: HTTPHeaders?
    
    init(
        sdkVersion: String,
        appVersion: String,
        hostApplicationName: String
    ) {
        let os = UIDevice.current.systemName
        let iOSVersion = UIDevice.current.systemVersion

        let userAgent: String = "\(hostApplicationName)\(appVersion), \(os)\(iOSVersion), Apple, \(DeviceModelHelper.model)"
        self.baseURL = URL(string: "")!
        self.cachePolicy = .useProtocolCachePolicy
        self.timeoutInterval = 30
        self.additionalHeaders = [
            "Mindbox-Integration": "iOS-SDK",
            "Mindbox-Integration-Version": sdkVersion,
            "User-Agent": userAgent,
            "Content-Type": "application/json; charset=utf-8"
        ]
    }
    
}
