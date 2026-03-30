//
//  MBSystemInfoProvider.swift
//  Mindbox
//
//  Created by Sergei Semko on 2/9/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import UIKit

private enum InfoKey {
    static let locale = "locale"
    static let version = "version"

    static let theme = "theme"
    
    enum Theme {
        static let dark = "dark"
        static let light = "light"
        static let unspecified = "unspecified"
    }

    static let platform = "platform"
    
    enum Platform {
        static let ios = "ios"
    }
}

final class MBSystemInfoProvider: SystemInfoProvider {

    private let permissionProvider: PermissionProvider
    private let utilitiesFetcher: UtilitiesFetcher

    init(permissionProvider: PermissionProvider, utilitiesFetcher: UtilitiesFetcher) {
        self.permissionProvider = permissionProvider
        self.utilitiesFetcher = utilitiesFetcher
    }

    func getTheme() -> String {
        if #available(iOS 13.0, *) {
            switch UITraitCollection.current.userInterfaceStyle {
            case .dark:
                return InfoKey.Theme.dark
            case .light:
                return InfoKey.Theme.light
            case .unspecified:
                return InfoKey.Theme.unspecified
            @unknown default:
                return InfoKey.Theme.unspecified
            }
        } else {
            return InfoKey.Theme.light
        }
    }

    func getPlatform() -> String {
        return InfoKey.Platform.ios
    }

    func getLocale() -> String {
        return Locale.current.identifier
    }

    func getAppVersion() -> String? {
        return utilitiesFetcher.appVerson
    }

    func getSafeAreaInsets(from view: UIView?) -> UIEdgeInsets {
        if let view = view {
            return view.safeAreaInsets
        }

        // Fallback to key window if view is not provided
        if #available(iOS 13.0, *) {
            let window = UIApplication.shared.windows.first { $0.isKeyWindow }
            return window?.safeAreaInsets ?? .zero
        } else {
            let window = UIApplication.shared.keyWindow
            return window?.safeAreaInsets ?? .zero
        }
    }

    func getGrantedPermissions() -> [String: PermissionStatus] {
        return permissionProvider.getGrantedPermissions()
    }

    func getBasicSystemInfo() -> [String: Any] {
        var info: [String: Any] = [
            InfoKey.theme: getTheme(),
            InfoKey.platform: getPlatform(),
            InfoKey.locale: getLocale()
        ]

        if let version = getAppVersion() {
            info[InfoKey.version] = version
        }

        return info
    }
}
