//
//  PushDeliveryConfirmationStore.swift
//  MindboxNotifications
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import CryptoKit
#if SWIFT_PACKAGE
@_spi(Internal)
import MindboxShared
#endif

struct PushDeliveryConfirmationStore: Sendable {

    enum State {
        case pending
        case released
    }

    let directory: URL

    init(directory: URL) {
        self.directory = directory
    }

    init?(appGroupIdentifier: String) {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            return nil
        }
        self.init(directory: container.appendingPathComponent(PushDeliveryConfirmationRecord.directoryName, isDirectory: true))
    }

    init?(hostBundle: Bundle = PushDeliveryConfirmationHeaders.hostApplicationBundle()) {
        guard let bundleIdentifier = hostBundle.bundleIdentifier else {
            return nil
        }
        self.init(appGroupIdentifier: "group.cloud.Mindbox.\(bundleIdentifier)")
    }

    func save(_ confirmation: PushDeliveryConfirmation) throws {
        try write(record(of: confirmation), to: fileURL(for: confirmation, state: .pending))
    }

    func release(_ confirmation: PushDeliveryConfirmation, lastStatusCode: Int?, lastAttemptAt: Date) throws {
        let record = record(of: confirmation, lastStatusCode: lastStatusCode, lastAttemptAt: Self.milliseconds(lastAttemptAt))
        try write(record, to: fileURL(for: confirmation, state: .released))
        try? FileManager.default.removeItem(at: fileURL(for: confirmation, state: .pending))
    }

    func remove(_ confirmation: PushDeliveryConfirmation) {
        try? FileManager.default.removeItem(at: fileURL(for: confirmation, state: .pending))
        try? FileManager.default.removeItem(at: fileURL(for: confirmation, state: .released))
    }

    func markSuccess(at date: Date) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let marker = directory.appendingPathComponent(PushDeliveryConfirmationRecord.successMarkerName)
        try Data(String(Self.milliseconds(date)).utf8).write(to: marker, options: [.atomic, .noFileProtection])
    }

    func fileURL(for confirmation: PushDeliveryConfirmation, state: State) -> URL {
        let digest = SHA256.hash(data: Data(confirmation.url.absoluteString.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        let pathExtension = state == .pending ? PushDeliveryConfirmationRecord.pendingExtension : PushDeliveryConfirmationRecord.releasedExtension
        return directory.appendingPathComponent(name).appendingPathExtension(pathExtension)
    }

    private func write(_ record: PushDeliveryConfirmationRecord, to url: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(record).write(to: url, options: [.atomic, .noFileProtection])
    }

    private static func milliseconds(_ date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1000).rounded())
    }

    private func record(
        of confirmation: PushDeliveryConfirmation,
        lastStatusCode: Int? = nil,
        lastAttemptAt: Int64? = nil
    ) -> PushDeliveryConfirmationRecord {
        PushDeliveryConfirmationRecord(
            url: confirmation.url.absoluteString,
            receivedAt: Self.milliseconds(confirmation.receivedAt),
            lastStatusCode: lastStatusCode,
            lastAttemptAt: lastAttemptAt
        )
    }
}
