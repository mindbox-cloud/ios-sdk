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
    /// Get camera permission status
    func getCameraPermissionStatus() -> PermissionStatus

    /// Get microphone permission status
    func getMicrophonePermissionStatus() -> PermissionStatus

    /// Get photo library permission status
    func getPhotoLibraryPermissionStatus() -> PermissionStatus

    /// Get location permission status
    func getLocationPermissionStatus() -> PermissionStatus

    /// Get all granted permissions as a dictionary
    /// Only includes permissions with .granted status. The notifications status is asked of the
    /// system rather than read from a stored flag, so the answer arrives later; the completion
    /// runs on the main queue.
    func getGrantedPermissions(_ completion: @escaping ([String: PermissionStatus]) -> Void)
}
