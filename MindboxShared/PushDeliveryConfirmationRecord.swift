//
//  PushDeliveryConfirmationRecord.swift
//  MindboxShared
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

@_spi(Internal)
public struct PushDeliveryConfirmationRecord: Codable, Equatable, Sendable {

    public static let formatVersion = 1
    public static let directoryName = "MindboxPushDeliveryConfirmations"
    public static let pendingExtension = "pending"
    public static let releasedExtension = "json"
    public static let successMarkerName = "last-success"
    public static let abandonedPendingAge: TimeInterval = 40

    public let version: Int
    public let url: String
    public let receivedAt: Int64
    public let lastStatusCode: Int?
    public let lastAttemptAt: Int64?

    public init(
        version: Int = PushDeliveryConfirmationRecord.formatVersion,
        url: String,
        receivedAt: Int64,
        lastStatusCode: Int? = nil,
        lastAttemptAt: Int64? = nil
    ) {
        self.version = version
        self.url = url
        self.receivedAt = receivedAt
        self.lastStatusCode = lastStatusCode
        self.lastAttemptAt = lastAttemptAt
    }
}
