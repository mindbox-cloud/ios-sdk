//
//  DeviceModelHelper.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 02.02.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation
import UIKit

struct DeviceModelHelper {

    static let os = UIDevice.current.systemName
    static let iOSVersion = UIDevice.current.systemVersion

    @MainActor static var keyboardLanguages: [String] {
        UITextInputMode.activeInputModes.compactMap(\.primaryLanguage)
    }

    static let model: String = {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }()
}
