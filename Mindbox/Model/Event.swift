//
//  Event.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 03.02.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

protocol EventProtocol {
    var transactionId: String { get }
    var dateTimeOffset: Int64 { get }
    var enqueueTimeStamp: Double { get }
    var serialNumber: String? { get }
    var type: Event.Operation { get }
    var isRetry: Bool { get }
    var body: String { get }

    init(type: Event.Operation, body: String)
    init?(_ event: CDEvent)
}

struct Event: EventProtocol {

    enum Operation: String {
        case installed = "MobilePush.ApplicationInstalled"
        case installedWithoutCustomer = "MobilePush.ApplicationInstalledWithoutCustomer"
        case infoUpdated = "MobilePush.ApplicationInfoUpdated"
        case trackClick = "MobilePush.TrackClick"
        case trackVisit = "MobilePush.TrackVisit"
        case customEvent = "MobilePush.CustomEvent"
        case syncEvent = "MobilePush.SyncEvent"

        case inAppViewEvent = "Inapp.Show"
        case inAppClickEvent = "Inapp.Click"
        case inAppTargetingEvent = "Inapp.Targeting"

        case sdkLogs = "MobileSdk.Logs"
    }

    let transactionId: String

    var dateTimeOffset: Int64 {
        guard isRetry else {
            return 0
        }
        let enqueueDate = Date(timeIntervalSince1970: enqueueTimeStamp)
        let ms = (Date().timeIntervalSince(enqueueDate) * 1000).rounded()
        return Int64(ms)
    }

    // Время добавляения персистентно в очередь событий
    let enqueueTimeStamp: Double

    let serialNumber: String?

    let type: Operation
    // True if first attempt to send was failed
    let isRetry: Bool
    // Data according to Operation
    let body: String

    init(type: Operation, body: String) {
        self.transactionId = UUID().uuidString
        self.enqueueTimeStamp = Date().timeIntervalSince1970
        self.type = type
        self.body = body
        self.serialNumber = nil
        self.isRetry = false
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
        self.isRetry = !event.retryTimestamp.isZero
    }
}
