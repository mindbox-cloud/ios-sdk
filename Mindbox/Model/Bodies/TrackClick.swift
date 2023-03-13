//
//  TrackMobilePushClick.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 24.03.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation

struct TrackClick: Codable {
    
    let messageUniqueKey: String
    
    let buttonUniqueKey: String?
    
    init(messageUniqueKey: String, buttonUniqueKey: String? = nil) {
        self.messageUniqueKey = messageUniqueKey
        self.buttonUniqueKey = buttonUniqueKey
    }
    
}
