//
//  MicrophonePermissionHandler.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 16.03.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import AVFoundation
import MindboxLogger

final class MicrophonePermissionHandler: PermissionHandler {

    let permissionType: PermissionType = .microphone
    let requiredInfoPlistKeys: [String] = ["NSMicrophoneUsageDescription"]

    func request(completion: @escaping (PermissionRequestResult) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)

        Logger.common(
            message: "[WebView] Microphone permission status: \(status.rawValue)",
            level: .debug,
            category: .webViewInAppMessages
        )

        switch status {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                completion(granted ? .granted : .denied)
            }
        case .denied, .restricted:
            completion(.denied)
        case .authorized:
            completion(.granted)
        @unknown default:
            completion(.error("Unknown microphone authorization status"))
        }
    }
}
