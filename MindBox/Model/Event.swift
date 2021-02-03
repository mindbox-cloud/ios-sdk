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
    
    let dateTimeOffset: Double
    
    let enqueueTimeStamp: Double
    
    let eventType: Type
    
    let body: String
    
}
