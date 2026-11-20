//
//  PushDeliveryConfirmationStore.swift
//  MindboxNotifications
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import CryptoKit

struct PushDeliveryConfirmationStore: Sendable {

    static let directoryName = "MindboxPushDeliveryConfirmations"
    static let formatVersion = 1

    let directory: URL

    init(directory: URL) {
        self.directory = directory
    }

    init?(appGroupIdentifier: String) {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            return nil
        }
        self.init(directory: container.appendingPathComponent(Self.directoryName, isDirectory: true))
    }

    init?(hostBundle: Bundle = PushDeliveryConfirmationHeaders.hostApplicationBundle()) {
        guard let bundleIdentifier = hostBundle.bundleIdentifier else {
            return nil
        }
        self.init(appGroupIdentifier: "group.cloud.Mindbox.\(bundleIdentifier)")
    }

    func save(_ confirmation: PushDeliveryConfirmation) throws {
        let record = Record(
            version: Self.formatVersion,
            url: confirmation.url.absoluteString,
            receivedAt: Int64((confirmation.receivedAt.timeIntervalSince1970 * 1000).rounded())
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(record).write(to: fileURL(for: confirmation), options: .atomic)
    }

    func remove(_ confirmation: PushDeliveryConfirmation) {
        try? FileManager.default.removeItem(at: fileURL(for: confirmation))
    }

    func fileURL(for confirmation: PushDeliveryConfirmation) -> URL {
        let digest = SHA256.hash(data: Data(confirmation.url.absoluteString.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(name).appendingPathExtension("json")
    }

    struct Record: Codable, Equatable {
        let version: Int
        let url: String
        let receivedAt: Int64
    }
}
