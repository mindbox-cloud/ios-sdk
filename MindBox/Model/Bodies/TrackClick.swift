//
//  TrackMobilePushClick.swift
//  MindBox
//
//  Created by Maksim Kazachkov on 24.03.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

struct TrackClick: Codable {
    
    let messageUniqueKey: String
    
    let buttonUniqueKey: String?
    
    init(messageUniqueKey: String, buttonUniqueKey: String?) {
        self.messageUniqueKey = messageUniqueKey
        self.buttonUniqueKey = buttonUniqueKey
    }
    
}
