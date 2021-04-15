//
//  TrackVisit.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 15.04.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

struct TrackVisit: Codable {
    
    let ianaTimeZone: String
    
    init() {
        ianaTimeZone = TimeZone.current.identifier
    }
    
}
