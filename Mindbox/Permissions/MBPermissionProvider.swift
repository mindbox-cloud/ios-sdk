//
//  MBPermissionProvider.swift
//  Mindbox
//
//  Created by Sergei Semko on 2/9/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import AVFoundation
import Photos
import CoreLocation

private enum PermissionKey {
    static let notifications = "notifications"
    static let camera = "camera"
    static let microphone = "microphone"
    static let photoLibrary = "photoLibrary"
    static let location = "location"
}

/// iOS implementation of PermissionProvider
final class MBPermissionProvider: PermissionProvider {

    private let persistenceStorage: PersistenceStorage

    init(persistenceStorage: PersistenceStorage) {
        self.persistenceStorage = persistenceStorage
    }

    func getNotificationPermissionStatus() -> PermissionStatus {
        guard let isEnabled = persistenceStorage.isNotificationsEnabled else {
            return PermissionStatus(status: .notDetermined)
        }
        return PermissionStatus(status: isEnabled ? .granted : .denied)
    }

    func getCameraPermissionStatus() -> PermissionStatus {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        return mapAVAuthorizationStatus(status)
    }

    func getMicrophonePermissionStatus() -> PermissionStatus {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        return mapAVAuthorizationStatus(status)
    }

    func getPhotoLibraryPermissionStatus() -> PermissionStatus {
        let status = PHPhotoLibrary.authorizationStatus()
        return mapPHAuthorizationStatus(status)
    }

    func getLocationPermissionStatus() -> PermissionStatus {
        let status = CLLocationManager.authorizationStatus()
        return mapCLAuthorizationStatus(status)
    }

    func getGrantedPermissions() -> [String: PermissionStatus] {
        var granted: [String: PermissionStatus] = [:]

        let permissions: [(String, PermissionStatus)] = [
            (PermissionKey.notifications, getNotificationPermissionStatus()),
            (PermissionKey.camera, getCameraPermissionStatus()),
            (PermissionKey.microphone, getMicrophonePermissionStatus()),
            (PermissionKey.photoLibrary, getPhotoLibraryPermissionStatus()),
            (PermissionKey.location, getLocationPermissionStatus())
        ]

        for (key, permission) in permissions where permission.status == .granted {
            granted[key] = permission
        }

        return granted
    }

    // MARK: - Mapping helpers

    private func mapAVAuthorizationStatus(_ status: AVAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorized:
            return PermissionStatus(status: .granted)
        case .denied:
            return PermissionStatus(status: .denied)
        case .notDetermined:
            return PermissionStatus(status: .notDetermined)
        case .restricted:
            return PermissionStatus(status: .restricted)
        @unknown default:
            return PermissionStatus(status: .notDetermined)
        }
    }

    private func mapPHAuthorizationStatus(_ status: PHAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorized:
            return PermissionStatus(status: .granted)
        case .denied:
            return PermissionStatus(status: .denied)
        case .notDetermined:
            return PermissionStatus(status: .notDetermined)
        case .restricted:
            return PermissionStatus(status: .restricted)
        case .limited:
            return PermissionStatus(status: .limited)
        @unknown default:
            return PermissionStatus(status: .notDetermined)
        }
    }

    private func mapCLAuthorizationStatus(_ status: CLAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            return PermissionStatus(status: .granted)
        case .denied:
            return PermissionStatus(status: .denied)
        case .notDetermined:
            return PermissionStatus(status: .notDetermined)
        case .restricted:
            return PermissionStatus(status: .restricted)
        @unknown default:
            return PermissionStatus(status: .notDetermined)
        }
    }
}
