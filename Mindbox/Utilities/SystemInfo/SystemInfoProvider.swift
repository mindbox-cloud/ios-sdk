//
//  SystemInfoProvider.swift
//  Mindbox
//
//  Created by Sergei Semko on 2/9/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import UIKit

/// Protocol for providing system information
/// Implementations should provide theme, locale, platform, version, insets, and permissions
protocol SystemInfoProvider {
    /// Get current interface style (light/dark)
    func getTheme() -> String

    /// Get current platform (always "ios" for iOS)
    func getPlatform() -> String

    /// Get current locale/language
    func getLocale() -> String

    /// Get app version
    func getAppVersion() -> String?

    /// Get safe area insets from a specific view
    func getSafeAreaInsets(from view: UIView?) -> UIEdgeInsets

    /// Get granted permissions only
    func getGrantedPermissions() -> [String: PermissionStatus]

    /// Get all basic system info as dictionary (theme, platform, locale, version)
    /// Note: Does not include insets or permissions by default
    func getBasicSystemInfo() -> [String: Any]
}
