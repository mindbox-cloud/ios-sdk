//
//  DeliveredNotification+Payload.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 15.03.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

extension DeliveredNotificationManager {
    
    struct Payload: Codable, CustomDebugStringConvertible {
        
        let uniqueKey: String

        var debugDescription: String {
            "uniqueKey: \(uniqueKey)"
        }
        
    }

}
