//
//  SystemInfoProvider.swift
//  Mindbox
//
//  Created by Sergei Semko on 2/9/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import UIKit

protocol SystemInfoProvider {
    func getTheme() -> String

    func getPlatform() -> String

    func getLocale() -> String

    func getAppVersion() -> String?

    func getSafeAreaInsets(from view: UIView?) -> UIEdgeInsets

    func getGrantedPermissions(_ completion: @escaping ([String: PermissionStatus]) -> Void)

    func getBasicSystemInfo() -> [String: Any]
}
