//
//  Event.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 03.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

struct Event {
    
    enum Operation: String {
        case installed = "MobilePush.ApplicationInstalled"
        case infoUpdated = "MobilePush.ApplicationInfoUpdated"
        case pushDelivered = ""
        case trackClick = "MobilePush.TrackClick"
        case trackVisit = "MobilePush.TrackVisit"
        case customEvent = "MobilePush.CustomEvent"
    }
    
    let transactionId: String
    
    var dateTimeOffset: Int64 {
        let enqueueDate = Date(timeIntervalSince1970: enqueueTimeStamp)
        let ms = (Date().timeIntervalSince(enqueueDate) * 1000).rounded()
        return Int64(ms)
    }
    
    // Время добавляения персистентно в очередь событий
    let enqueueTimeStamp: Double
    
    let type: Operation
    
    // Data according to Operation
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
                .category(.database).level(.error).make()
            return nil
        }
        guard let type = event.type, let operation = Event.Operation(rawValue: type) else {
            Log("Event with type: nil")
                .category(.database).level(.error).make()
            return nil
        }
        guard let body = event.body else {
            Log("Event with body: nil")
                .category(.database).level(.error).make()
            return nil
        }
        self.transactionId = transactionId
        self.enqueueTimeStamp = event.timestamp
        self.type = operation
        self.body = body
    }
    
}
