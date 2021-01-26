//
//  Constant.swift
//  URLSessionAPIServices
//
//  Created by Yusuf Demirci on 13.04.2020.
//  Copyright © 2020 Yusuf Demirci. All rights reserved.
//

import Foundation
import UIKit

class APIServiceConstant {

    static var defaultHeaders: [String:String] {
        get {
            let sdkVersion: String = Utilities.fetch.sdkVersion ?? "unknow"
            let appVersion: String = Utilities.fetch.appVerson ?? "unknow"
            let hostApplicationName: String = Utilities.fetch.hostApplicationName ?? "unknow"

            let model: String = {
                var systemInfo = utsname()
                uname(&systemInfo)
                let machineMirror = Mirror(reflecting: systemInfo.machine)
                let identifier = machineMirror.children.reduce("") { identifier, element in
                    guard let value = element.value as? Int8, value != 0 else { return identifier }
                    return identifier + String(UnicodeScalar(UInt8(value)))
                }
                return identifier
            }()

            let os = UIDevice.current.systemName
            let iOSVersion = UIDevice.current.systemVersion

            let userAgent: String = "\(hostApplicationName)\(appVersion), \(os)\(iOSVersion), Apple, \(model)"
            let ret: [String:String] = [
                "Mindbox-Integration": "iOS-SDK",
                "Mindbox-Integration-Version": sdkVersion,
                "User-Agent": userAgent,
                "Content-Type": "application/json; charset=utf-8"
            ]
            return ret
        }
    }
}
