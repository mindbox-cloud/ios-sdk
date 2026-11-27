//
//  PushDeliveryConfirmationInbox.swift
//  Mindbox
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
#if SWIFT_PACKAGE
@_spi(Internal)
import MindboxShared
#endif

struct PushDeliveryConfirmationInbox: Sendable {

    struct Item: Equatable, Sendable {
        let fileURL: URL
        let record: PushDeliveryConfirmationRecord
    }

    enum DropReason: Hashable, Sendable {
        case expired
        case overLimit
        case unreadable
    }

    static let maxRecords = 5000
    static let lifeLimitMonths = 6

    private let directory: URL
    private let maxRecords: Int

    init(directory: URL, maxRecords: Int = PushDeliveryConfirmationInbox.maxRecords) {
        self.directory = directory
        self.maxRecords = maxRecords
    }

    init?(appGroupIdentifier: String) {
        guard !appGroupIdentifier.isEmpty,
              let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            return nil
        }
        self.init(directory: container.appendingPathComponent(PushDeliveryConfirmationRecord.directoryName, isDirectory: true))
    }

    var hasRecords: Bool {
        !recordFiles().isEmpty
    }

    func items(now: Date) -> (items: [Item], dropped: [DropReason: Int]) {
        var dropped: [DropReason: Int] = [:]
        var candidates: [Item] = []
        let expirationDate = Calendar.current.date(byAdding: .month, value: -Self.lifeLimitMonths, to: now)
        let expirationMilliseconds = expirationDate.map(Self.milliseconds)

        for file in recordFiles() {
            guard let data = try? Data(contentsOf: file) else {
                continue
            }
            guard let record = decodeRecord(from: data) else {
                discard(file, reason: .unreadable, dropped: &dropped)
                continue
            }
            if let expirationMilliseconds, record.receivedAt < expirationMilliseconds {
                discard(file, reason: .expired, dropped: &dropped)
                continue
            }
            if file.pathExtension == PushDeliveryConfirmationRecord.pendingExtension,
               now.timeIntervalSince1970 - TimeInterval(record.receivedAt) / 1000 < PushDeliveryConfirmationRecord.abandonedPendingAge {
                continue
            }
            candidates.append(Item(fileURL: file, record: record))
        }

        candidates.sort { $0.record.receivedAt < $1.record.receivedAt }
        let excess = candidates.count - maxRecords
        if excess > 0 {
            candidates.prefix(excess).forEach { discard($0.fileURL, reason: .overLimit, dropped: &dropped) }
            candidates.removeFirst(excess)
        }
        return (candidates, dropped)
    }

    func remove(_ item: Item) {
        try? FileManager.default.removeItem(at: item.fileURL)
    }

    func lastSuccess() -> Int64? {
        let marker = directory.appendingPathComponent(PushDeliveryConfirmationRecord.successMarkerName)
        guard let data = try? Data(contentsOf: marker),
              let text = String(data: data, encoding: .utf8) else {
            return nil
        }
        return Int64(text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func recordFiles() -> [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return files.filter {
            $0.pathExtension == PushDeliveryConfirmationRecord.releasedExtension
                || $0.pathExtension == PushDeliveryConfirmationRecord.pendingExtension
        }
    }

    private func decodeRecord(from data: Data) -> PushDeliveryConfirmationRecord? {
        guard let record = try? JSONDecoder().decode(PushDeliveryConfirmationRecord.self, from: data),
              PushDeliveryConfirmation(deliveredUrl: record.url, receivedAt: Date(timeIntervalSince1970: TimeInterval(record.receivedAt) / 1000)) != nil else {
            return nil
        }
        return record
    }

    private func discard(_ file: URL, reason: DropReason, dropped: inout [DropReason: Int]) {
        try? FileManager.default.removeItem(at: file)
        dropped[reason, default: 0] += 1
    }

    private static func milliseconds(_ date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1000).rounded())
    }
}
