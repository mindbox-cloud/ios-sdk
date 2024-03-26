//
//  MockEvent.swift
//  MindboxTests
//
//  Created by Sergei Semko on 3/26/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
@testable import Mindbox

struct MockEvent: EventProtocol {
    let transactionId: String
    
    var dateTimeOffset: Int64 {
        guard isRetry else {
            return 0
        }
        let enqueueDate = Date(timeIntervalSince1970: enqueueTimeStamp)
        let ms = (Date().timeIntervalSince(enqueueDate) * 1000).rounded()
        return Int64(ms)
    }
    
    let enqueueTimeStamp: Double
    
    let serialNumber: String?
    
    let type: Event.Operation
    
    let isRetry: Bool
    
    let body: String
    
    init(type: Event.Operation, body: String) {
        self.transactionId = UUID().uuidString
        self.enqueueTimeStamp = Date().timeIntervalSince1970
        self.type = type
        self.body = body
        self.serialNumber = nil
        self.isRetry = false
    }
    
    init?(_ event: CDEvent) {
        guard let transactionId = event.transactionId else {
            return nil
        }
        guard let type = event.type, let operation = Event.Operation(rawValue: type) else {
            return nil
        }
        guard let body = event.body else {

            return nil
        }
        self.transactionId = transactionId
        self.enqueueTimeStamp = event.timestamp
        self.type = operation
        self.body = body
        self.serialNumber = event.objectID.uriRepresentation().lastPathComponent
        self.isRetry = !event.retryTimestamp.isZero
    }
}

extension MockEvent {
    init(type: Event.Operation, body: String, isRetry: Bool = false) {
        self.transactionId = UUID().uuidString
        self.enqueueTimeStamp = Date().timeIntervalSince1970
        self.type = type
        self.body = body
        self.serialNumber = nil
        self.isRetry = isRetry
    }
}
