//
//  LocationPermissionHandler.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 13.03.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import CoreLocation
import MindboxLogger

final class LocationPermissionHandler: NSObject, PermissionHandler {

    let permissionType: PermissionType = .location
    let requiredInfoPlistKeys: [String] = ["NSLocationWhenInUseUsageDescription"]

    private var completion: ((PermissionRequestResult) -> Void)?
    private var locationManager: CLLocationManager?

    func request(completion: @escaping (PermissionRequestResult) -> Void) {
        let status: CLAuthorizationStatus
        let manager = CLLocationManager()

        if #available(iOS 14.0, *) {
            status = manager.authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }

        Logger.common(
            message: "[WebView] Location permission status: \(status.rawValue)",
            level: .debug,
            category: .webViewInAppMessages
        )

        switch status {
        case .notDetermined:
            self.completion = completion
            self.locationManager = manager
            manager.delegate = self
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            completion(.denied)
        case .authorizedWhenInUse, .authorizedAlways:
            completion(.granted)
        @unknown default:
            completion(.error("Unknown location authorization status"))
        }
    }
}

extension LocationPermissionHandler: CLLocationManagerDelegate {

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard let completion else { return }

        let status: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            status = manager.authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }

        guard status != .notDetermined else { return }

        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            completion(.granted)
        case .denied, .restricted:
            completion(.denied)
        default:
            completion(.error("Unknown location authorization status"))
        }

        self.completion = nil
        self.locationManager = nil
    }
}
