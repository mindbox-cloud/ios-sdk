//
//  MobileApplicationInfoUpdated.swift
//  MindBox
//
//  Created by Maksim Kazachkov on 11.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

struct MobileApplicationInfoUpdated: Codable {
    
    let token: String
    
    var isTokenAvailable: Bool
    
    let isNotificationsEnabled: Bool
    
    init(token: String, isNotificationsEnabled: Bool) {
        self.token = token
        self.isTokenAvailable = !token.isEmpty
        self.isNotificationsEnabled = isNotificationsEnabled
    }

}
