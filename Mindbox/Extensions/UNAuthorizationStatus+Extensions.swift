//
//  UNAuthorizationStatus+Extensions.swift
//  Mindbox
//
//  Created by vailence on 21.03.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
import UserNotifications

extension UNAuthorizationStatus {
    var description: String {
        switch self {
        case .notDetermined:
            return "notDetermined"
        case .denied:
            return "denied"
        case .authorized:
            return "authorized"
        case .provisional:
            return "provisional"
        case .ephemeral:
            return "ephemeral"
        @unknown default:
            return "unknown"
        }
    }
}
