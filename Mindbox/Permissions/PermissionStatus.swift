//
//  PermissionStatus.swift
//  Mindbox
//
//  Created by Sergei Semko on 2/9/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

/// Unified permission status model for all permission types
/// This model is designed to be cross-platform compatible with Android SDK
struct PermissionStatus: Codable {
    let status: PermissionStatusValue
    let details: [String: String]?

    init(status: PermissionStatusValue, details: [String: String]? = nil) {
        self.status = status
        self.details = details
    }

    /// Converts PermissionStatus to a dictionary for JSON serialization
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["status": status.rawValue]
        if let details = details {
            dict["details"] = details
        }
        return dict
    }
}

/// Unified permission status values for cross-platform compatibility
/// - granted: Permission is granted
/// - denied: Permission is denied by user
/// - notDetermined: Permission has not been requested yet
/// - restricted: Permission is restricted by system (iOS: parental controls, MDM; Android: may map to denied)
/// - limited: Limited access granted (iOS: photos limited access; Android: not applicable)
enum PermissionStatusValue: String, Codable {
    case granted
    case denied
    case notDetermined
    case restricted
    case limited
}
