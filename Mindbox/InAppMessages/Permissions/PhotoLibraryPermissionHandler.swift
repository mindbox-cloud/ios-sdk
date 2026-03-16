//
//  PhotoLibraryPermissionHandler.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 16.03.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Photos
import MindboxLogger

final class PhotoLibraryPermissionHandler: PermissionHandler {

    let permissionType: PermissionType = .photoLibrary
    let requiredInfoPlistKeys: [String] = ["NSPhotoLibraryUsageDescription"]

    func request(completion: @escaping (PermissionRequestResult) -> Void) {
        let status: PHAuthorizationStatus
        if #available(iOS 14, *) {
            status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        } else {
            status = PHPhotoLibrary.authorizationStatus()
        }

        Logger.common(
            message: "[WebView] Photo library permission status: \(status.rawValue)",
            level: .debug,
            category: .webViewInAppMessages
        )

        switch status {
        case .notDetermined:
            requestAccess(completion: completion)
        case .denied, .restricted:
            completion(.denied)
        case .authorized, .limited:
            completion(.granted)
        @unknown default:
            completion(.error("Unknown photo library authorization status"))
        }
    }

    private func requestAccess(completion: @escaping (PermissionRequestResult) -> Void) {
        if #available(iOS 14, *) {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                switch newStatus {
                case .authorized, .limited:
                    completion(.granted)
                default:
                    completion(.denied)
                }
            }
        } else {
            PHPhotoLibrary.requestAuthorization { newStatus in
                switch newStatus {
                case .authorized:
                    completion(.granted)
                default:
                    completion(.denied)
                }
            }
        }
    }
}
