//
//  MobileApplicationInfoUpdatedDataWrapper.swift
//  MindBox
//
//  Created by Maksim Kazachkov on 02.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

struct MobileApplicationInfoUpdatedWrapper {
    
    let operation = "MobileApplicationInfoUpdated"

    let endpointId: String
    
    let deviceUUID: String
    
    let body: Body
    
    struct Body: Codable {
        
        let token: String
        let isTokenAvailable: Bool
        let isNotificationsEnabled: Bool

    }
    
}
