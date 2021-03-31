//
//  GuaranteedDeliveryManager+State.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 11.03.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

extension GuaranteedDeliveryManager {
    
    enum State: String, CustomStringConvertible {
        
        case idle, delivering, waitingForRetry
         
        var isDelivering: Bool {
            self == .delivering
        }
        
        var isIdle: Bool {
            self == .idle
        }
        
        var isWaitingForRetry: Bool {
            self == .waitingForRetry
        }
        
        var description: String {
            rawValue
        }
        
    }
    
}
