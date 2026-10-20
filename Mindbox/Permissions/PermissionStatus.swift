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

enum PermissionStatusValue: String, Codable {
    case granted
    case denied
    case notDetermined
    case restricted
    case limited
}
