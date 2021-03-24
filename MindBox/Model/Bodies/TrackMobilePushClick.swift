//
//  TrackMobilePushClick.swift
//  MindBox
//
//  Created by Maksim Kazachkov on 24.03.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

struct TrackMobilePushClick: Codable {
    
    let unicKey: String
    
    let buttonUnicKey: String?
    
    init(unicKey: String, buttonUnicKey: String?) {
        self.unicKey = unicKey
        self.buttonUnicKey = buttonUnicKey
    }
    
}
