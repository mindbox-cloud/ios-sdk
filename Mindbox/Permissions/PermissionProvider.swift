//
//  PermissionProvider.swift
//  Mindbox
//
//  Created by Sergei Semko on 2/9/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

protocol PermissionProvider {
    func getCameraPermissionStatus() -> PermissionStatus

    func getMicrophonePermissionStatus() -> PermissionStatus

    func getPhotoLibraryPermissionStatus() -> PermissionStatus

    func getLocationPermissionStatus() -> PermissionStatus

    // Completes on main: the system reports the notifications status off main, and callers read UIKit in the completion.
    func getGrantedPermissions(_ completion: @escaping ([String: PermissionStatus]) -> Void)
}
