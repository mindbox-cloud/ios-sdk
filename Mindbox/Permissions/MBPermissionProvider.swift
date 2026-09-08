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

private enum DetailsKey {
    static let access = "access"
    static let limited = "limited"
}

/// iOS implementation of PermissionProvider
final class MBPermissionProvider: PermissionProvider {

    private let notificationStatus: UNAuthorizationStatusProviding

    init(notificationStatus: UNAuthorizationStatusProviding) {
        self.notificationStatus = notificationStatus
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
        var status: PHAuthorizationStatus
        if #available(iOS 14, *) {
            status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        } else {
            status = PHPhotoLibrary.authorizationStatus()
        }
        return mapPHAuthorizationStatus(status)
    }

    func getLocationPermissionStatus() -> PermissionStatus {
        let status: CLAuthorizationStatus
        if #available(iOS 14, *) {
            status = CLLocationManager().authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }
        return mapCLAuthorizationStatus(status)
    }

    func getGrantedPermissions(_ completion: @escaping ([String: PermissionStatus]) -> Void) {
        var granted: [String: PermissionStatus] = [:]

        let permissions: [(String, PermissionStatus)] = [
            (PermissionKey.camera, getCameraPermissionStatus()),
            (PermissionKey.microphone, getMicrophonePermissionStatus()),
            (PermissionKey.photoLibrary, getPhotoLibraryPermissionStatus()),
            (PermissionKey.location, getLocationPermissionStatus())
        ]

        for (key, permission) in permissions where permission.status == .granted {
            granted[key] = permission
        }

        notificationStatus.getStatus { isGranted in
            if isGranted {
                granted[PermissionKey.notifications] = PermissionStatus(status: .granted)
            }
            DispatchQueue.main.async { completion(granted) }
        }
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
            return PermissionStatus(status: .granted, details: [DetailsKey.access: DetailsKey.limited])
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
