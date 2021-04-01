//
//  Constants.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 29.03.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

enum Constants {
    
    enum Background {
        
        static let removeDeprecatedEventsInterval = TimeInterval(7 * 24 * 60 * 60)
        
        static let refreshTaskInterval = TimeInterval(2 * 60)
    }
    
    enum Database {
        
        static let mombName = "MBDatabase"
        
    }
    
    enum Notification {
        
        static let mindBoxIdentifireKey = "uniqueKey"
        
    }
        
}
