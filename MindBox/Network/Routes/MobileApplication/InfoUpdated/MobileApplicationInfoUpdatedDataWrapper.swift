//
//  MobileApplicationInfoUpdatedDataWrapper.swift
//  MindBox
//
//  Created by Maksim Kazachkov on 02.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

struct MobileApplicationInfoUpdatedDataWrapper {
    
    let query: Query
    let body: Body
    
    struct Body: Codable {
        
        let token: String
        let isTokenAvailable: Bool
        let isNotificationsEnabled: Bool

    }
    
    struct Query {
        let endpointId: String
        let operation = "MobileApplicationInfoUpdated"
        let deviceUUID: String
    }

    
}
