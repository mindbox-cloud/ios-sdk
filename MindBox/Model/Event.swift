//
//  Event.swift
//  MindBox
//
//  Created by Maksim Kazachkov on 03.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

struct Event {
    
    enum Operation: String {
        case installed = "MobileApplicationInstalled"
        case infoUpdated = "MobileApplocationInfoUpdated"
    }
    
    let transactionId: String
    
    var dateTimeOffset: Double {
        Date().timeIntervalSince1970 - enqueueTimeStamp
    }
    
    // Время добавляения персистентно в очередь событий
    let enqueueTimeStamp: Double
    
    let type: Operation
    
    let body: String
    
    init(type: Operation, body: String) {
        self.transactionId = UUID().uuidString
        self.enqueueTimeStamp = Date().timeIntervalSince1970
        self.type = type
        self.body = body
    }
    
    init?(_ event: CDEvent) {
        guard let transactionId = event.transactionId else {
            Log("Event with transactionId: nil")
                .inChanel(.database).withType(.error).make()
            return nil
        }
        guard let type = event.type, let operation = Event.Operation(rawValue: type) else {
            Log("Event with type: nil")
                .inChanel(.database).withType(.error).make()
            return nil
        }
        guard let body = event.body else {
            Log("Event with body: nil")
                .inChanel(.database).withType(.error).make()
            return nil
        }
        self.transactionId = transactionId
        self.enqueueTimeStamp = event.timestamp
        self.type = operation
        self.body = body
    }
    
}
