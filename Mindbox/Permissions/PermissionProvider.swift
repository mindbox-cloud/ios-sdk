//
//  PermissionProvider.swift
//  Mindbox
//
//  Created by Sergei Semko on 2/9/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

/// Protocol for providing permission status information
/// Implementations should provide status for various system permissions
protocol PermissionProvider {
    /// Get notification permission status
    func getNotificationPermissionStatus() -> PermissionStatus

    /// Get camera permission status
    func getCameraPermissionStatus() -> PermissionStatus

    /// Get microphone permission status
    func getMicrophonePermissionStatus() -> PermissionStatus

    /// Get photo library permission status
    func getPhotoLibraryPermissionStatus() -> PermissionStatus

    /// Get location permission status
    func getLocationPermissionStatus() -> PermissionStatus

    /// Get all granted permissions as a dictionary
    /// Only includes permissions with .granted status
    func getGrantedPermissions() -> [String: PermissionStatus]
}
