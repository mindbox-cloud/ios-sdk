//
//  CameraPermissionHandler.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 16.03.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import AVFoundation
import MindboxLogger

final class CameraPermissionHandler: PermissionHandler {

    let permissionType: PermissionType = .camera
    let requiredInfoPlistKeys: [String] = ["NSCameraUsageDescription"]

    func request(completion: @escaping (PermissionRequestResult) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        Logger.common(
            message: "[WebView] Camera permission status: \(status.rawValue)",
            level: .debug,
            category: .webViewInAppMessages
        )

        switch status {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                completion(granted ? .granted : .denied)
            }
        case .denied, .restricted:
            completion(.denied)
        case .authorized:
            completion(.granted)
        @unknown default:
            completion(.error("Unknown camera authorization status"))
        }
    }
}
