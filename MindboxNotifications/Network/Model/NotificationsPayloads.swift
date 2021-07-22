//
//  DeliveredNotificationPayload.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 31.03.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

enum NotificationsPayloads {
    
    struct Delivery: Codable, CustomDebugStringConvertible {
        
        let uniqueKey: String

        var debugDescription: String {
            "uniqueKey: \(uniqueKey)"
        }
       
    }
    
    struct Click: Codable {
        
        struct Buttons: Codable {
            
            let text: String
            let uniqueKey: String
            
        }
        
        let uniqueKey: String
        
        let buttons: [Buttons]?

        var debugDescription: String {
            "uniqueKey: \(uniqueKey)"
        }
        
    }
    
}

