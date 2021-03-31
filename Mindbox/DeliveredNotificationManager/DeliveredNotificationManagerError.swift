//
//  DeliveredNotificationManagerError.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 20.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

enum DeliveredNotificationManagerError: LocalizedError {
    
    case unableToFetchUserInfo

    public var errorDescription: String? {
        switch self {
        case .unableToFetchUserInfo:
            return "Unable to fetch user info object from notification."
        }
    }
}
