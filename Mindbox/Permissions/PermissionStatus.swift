//
//  PermissionStatus.swift
//  Mindbox
//
//  Created by Sergei Semko on 2/9/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

struct PermissionStatus: Codable {
    let status: PermissionStatusValue
    let details: [String: String]?

    init(status: PermissionStatusValue, details: [String: String]? = nil) {
        self.status = status
        self.details = details
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["status": status.rawValue]
        if let details = details {
            dict["details"] = details
        }
        return dict
    }
}

/// The `permissions.<name>.status` value web pages receive in the `ready` response and in
/// `initDataUpdated`. Only granted permissions are sent, so pages see only `granted`.
/// Limited photo library access is sent as `granted` with `details.access` set to `limited`.
/// Android sends the same.
enum PermissionStatusValue: String, Codable {
    case granted
    case denied
    case notDetermined
    case restricted
    case limited
}
