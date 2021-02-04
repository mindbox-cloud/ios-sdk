//
//  Event.swift
//  MindBox
//
//  Created by Maksim Kazachkov on 03.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

struct Event {
    
    enum `Type`: String {
        case installed = "MobileApplicationInstalled"
        case infoUpdated = "MobileApplocationInfoUpdated"
    }
    
    let transactionId: String
    
    var dateTimeOffset: Double {
        Date().timeIntervalSince1970 - enqueueTimeStamp
    }
    
    // Время добавляения персистентно в очередь событий
    let enqueueTimeStamp: Double
    
    let type: Type
    
    let body: String
    
}
