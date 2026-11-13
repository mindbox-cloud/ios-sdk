//
//  Event.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 03.02.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

struct Event: EventProtocol {

    enum Operation: String {
        // MARK: - Queue key is also the operation name

        case installed = "MobilePush.ApplicationInstalled"
        case installedWithoutCustomer = "MobilePush.ApplicationInstalledWithoutCustomer"
        case infoUpdated = "MobilePush.ApplicationInfoUpdated"
        case keepAlive = "MobilePush.ApplicationKeepalive"
        case trackClick = "MobilePush.TrackClick"
        case inAppViewEvent = "Inapp.Show"
        case inAppClickEvent = "Inapp.Click"
        case inAppTargetingEvent = "Inapp.Targeting"
        case inAppShowFailureEvent = "Inapp.ShowFailure"
        case sdkLogs = "MobileSdk.Logs"

        // MARK: - Queue key only: sent under another name or endpoint

        case trackingIdsUpdated = "TrackingIdsUpdated"
        case customEvent = "MobilePush.CustomEvent"
        case syncEvent = "MobilePush.SyncEvent"
        case trackVisit = "MobilePush.TrackVisit"

        enum Request {
            case sdkOperation(String)
            case customAsyncOperation
            case customSyncOperation
            case trackVisit
        }

        var request: Request {
            switch self {
            case .installed,
                 .installedWithoutCustomer,
                 .infoUpdated,
                 .keepAlive,
                 .trackClick,
                 .inAppViewEvent,
                 .inAppClickEvent,
                 .inAppTargetingEvent,
                 .inAppShowFailureEvent,
                 .sdkLogs:
                .sdkOperation(rawValue)
            case .trackingIdsUpdated:
                .sdkOperation(Operation.infoUpdated.rawValue)
            case .customEvent:
                .customAsyncOperation
            case .syncEvent:
                .customSyncOperation
            case .trackVisit:
                .trackVisit
            }
        }
    }

    let transactionId: String

    var dateTimeOffset: Int64 {
        guard isRetry else {
            return 0
        }
        let enqueueDate = Date(timeIntervalSince1970: enqueueTimeStamp)
        let ms = (Date().timeIntervalSince(enqueueDate) * 1000).rounded()
        return max(0, Int64(ms))
    }

    let enqueueTimeStamp: Double

    let serialNumber: String?

    let type: Operation
    var isRetry: Bool { !retryTimestamp.isZero }
    
    let retryTimestamp: Double
    
    let body: String

    init(type: Operation, body: String) {
        self.transactionId = UUID().uuidString
        self.enqueueTimeStamp = Date().timeIntervalSince1970
        self.type = type
        self.body = body
        self.serialNumber = nil
        self.retryTimestamp = 0
    }

    init?(_ event: CDEvent) {
        guard let transactionId = event.transactionId else {
            Logger.common(message: "Event with transactionId: nil", level: .error, category: .database)
            return nil
        }
        guard let type = event.type, let operation = Event.Operation(rawValue: type) else {
            Logger.common(message: "Event with type: nil", level: .error, category: .database)
            return nil
        }
        guard let body = event.body else {
            Logger.common(message: "Event with body: nil", level: .error, category: .database)
            return nil
        }
        self.transactionId = transactionId
        self.enqueueTimeStamp = event.timestamp
        self.type = operation
        self.body = body
        self.serialNumber = event.objectID.uriRepresentation().lastPathComponent
        self.retryTimestamp = event.retryTimestamp
    }
}

// MARK: For test purposes

protocol EventProtocol {
    var transactionId: String { get }
    var dateTimeOffset: Int64 { get }
    var enqueueTimeStamp: Double { get }
    var serialNumber: String? { get }
    var type: Event.Operation { get }
    var isRetry: Bool { get }
    var retryTimestamp: Double { get }
    var body: String { get }

    init(type: Event.Operation, body: String)
    init?(_ event: CDEvent)
}
